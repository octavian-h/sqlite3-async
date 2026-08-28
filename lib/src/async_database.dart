import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:sqlite3/sqlite3.dart';

import 'async_database_command.dart';
import 'async_database_command_type.dart';
import 'async_database_exception.dart';
import 'create_collation_params.dart';
import 'create_function_params.dart';
import 'open_database_params.dart';
import 'remote_error_payload.dart';
import 'statement_params.dart';

/// An opened sqlite3 database with async methods.
class AsyncDatabase {
  static final Logger _log = Logger((AsyncDatabase).toString());
  static final Finalizer<Isolate> _isolateFinalizer = Finalizer<Isolate>(
    (worker) => worker.kill(priority: Isolate.immediate),
  );

  final Isolate _worker;
  final SendPort _workerPort;
  bool _isClosed = false;

  AsyncDatabase._(this._worker, this._workerPort) {
    _isolateFinalizer.attach(this, _worker, detach: this);
  }

  /// Opens a database file.
  ///
  /// The [vfs] option can be used to set the appropriate virtual file system
  /// implementation. When null, the default file system will be used.
  ///
  /// If [uri] is enabled (defaults to `false`), the [filename] will be
  /// interpreted as an uri as according to https://www.sqlite.org/uri.html.
  ///
  /// If the [mutex] parameter is set to true, the `SQLITE_OPEN_FULLMUTEX` flag
  /// will be set. If it's set to false, `SQLITE_OPEN_NOMUTEX` will be enabled.
  /// By default, neither parameter will be set.
  static Future<AsyncDatabase> open(
    String filename, {
    String? vfs,
    OpenMode mode = OpenMode.readWriteCreate,
    bool uri = false,
    bool? mutex,
  }) async {
    PrintAppender.setupLogging(level: Level.INFO);

    var receivePort = ReceivePort();
    var token = RootIsolateToken.instance;
    var worker = await Isolate.spawn(
      _executeCommand,
      AsyncDatabaseCommand('_init', receivePort.sendPort, body: token),
    );

    AsyncDatabaseCommand response = await receivePort.first;
    var workerPort = response.sendPort;
    var asyncDatabase = AsyncDatabase._(worker, workerPort);
    await asyncDatabase._sendCommand(
      AsyncDatabaseCommandType.open,
      body: OpenDatabaseParams(filename, vfs, mode, uri, mutex),
    );
    return asyncDatabase;
  }

  /// Returns the application defined version of this database.
  Future<int> getUserVersion() async {
    return await _sendCommand(AsyncDatabaseCommandType.getUserVersion);
  }

  /// Set the application defined version of this database.
  Future<void> setUserVersion(int value) async {
    await _sendCommand(AsyncDatabaseCommandType.setUserVersion, body: value);
  }

  /// Returns the row id of the last inserted row.
  Future<int> getLastInsertRowId() async {
    return await _sendCommand(AsyncDatabaseCommandType.getLastInsertRowId);
  }

  /// Executes the [sql] statement with the provided [parameters] and ignores
  /// the result.
  Future<void> execute(
    String sql, [
    List<Object?> parameters = const [],
  ]) async {
    await _sendCommand(
      AsyncDatabaseCommandType.execute,
      body: StatementParams(sql, parameters),
    );
  }

  /// Prepares the [sql] select statement and runs it with the provided
  /// [parameters].
  Future<ResultSet> select(
    String sql, [
    List<Object?> parameters = const [],
  ]) async {
    return await _sendCommand(
      AsyncDatabaseCommandType.select,
      body: StatementParams(sql, parameters),
    );
  }

  /// Runs [action] inside a database transaction.
  ///
  /// The transaction is committed if [action] completes successfully, or
  /// rolled back if it throws. The result of [action] is returned on
  /// success.
  Future<T> transaction<T>(Future<T> Function() action) async {
    await execute('BEGIN');
    try {
      final result = await action();
      await execute('COMMIT');
      return result;
    } catch (_) {
      await execute('ROLLBACK');
      rethrow;
    }
  }

  /// Register a custom function we can invoke from sql
  Future<void> createFunction({
    required String functionName,
    required ScalarFunction function,
    AllowedArgumentCount argumentCount = const AllowedArgumentCount.any(),
    bool deterministic = false,
    bool directOnly = true,
  }) async {
    return await _sendCommand(
      AsyncDatabaseCommandType.createFunction,
      body: CreateFunctionParams(
        functionName: functionName,
        function: function,
        argumentCount: argumentCount,
        deterministic: deterministic,
        directOnly: directOnly,
      ),
    );
  }

  /// Register a custom collation
  Future<void> createCollation({
    required String name,
    required CollatingFunction function,
  }) async {
    return await _sendCommand(
      AsyncDatabaseCommandType.createCollation,
      body: CreateCollationParams(name: name, function: function),
    );
  }

  /// Closes this database and releases associated resources.
  @Deprecated('Call close() instead')
  Future<void> dispose() async {
    await close();
  }

  /// Closes this database and releases associated resources.
  Future<void> close() async {
    if (_isClosed) return;
    await _sendCommand(AsyncDatabaseCommandType.close);
    _worker.kill(priority: Isolate.immediate);
    _isClosed = true;
    _isolateFinalizer.detach(this);
  }

  /// A command handler receives the current [Database] (`null` until
  /// [AsyncDatabaseCommandType.open] has run), the incoming [cmd] and the
  /// worker's [ReceivePort], and returns the (possibly updated) [Database]
  /// to keep as state for subsequent commands.
  static final Map<
    String,
    Database? Function(Database? db, AsyncDatabaseCommand cmd, ReceivePort port)
  >
  _commandHandlers = {
    AsyncDatabaseCommandType.open: (db, cmd, port) => _openSync(cmd, port),
    AsyncDatabaseCommandType.getUserVersion: (db, cmd, port) {
      _getUserVersionSync(db!, cmd, port);
      return db;
    },
    AsyncDatabaseCommandType.setUserVersion: (db, cmd, port) {
      _setUserVersionSync(db!, cmd, port);
      return db;
    },
    AsyncDatabaseCommandType.getLastInsertRowId: (db, cmd, port) {
      _getLastInsertRowIdSync(db!, cmd, port);
      return db;
    },
    AsyncDatabaseCommandType.execute: (db, cmd, port) {
      _executeSync(db!, cmd, port);
      return db;
    },
    AsyncDatabaseCommandType.select: (db, cmd, port) {
      _selectSync(db!, cmd, port);
      return db;
    },
    AsyncDatabaseCommandType.createFunction: (db, cmd, port) {
      _createFunctionSync(db!, cmd, port);
      return db;
    },
    AsyncDatabaseCommandType.createCollation: (db, cmd, port) {
      _createCollationSync(db!, cmd, port);
      return db;
    },
    AsyncDatabaseCommandType.close: (db, cmd, port) {
      _closeSync(db!, cmd, port);
      return db;
    },
  };

  static void _executeCommand(AsyncDatabaseCommand initCmd) async {
    var ourReceivePort = ReceivePort();
    assert(initCmd.type == '_init');
    BackgroundIsolateBinaryMessenger.ensureInitialized(initCmd.body);
    initCmd.sendPort.send(
      AsyncDatabaseCommand(initCmd.type, ourReceivePort.sendPort),
    );

    Database? db;
    await for (AsyncDatabaseCommand cmd in ourReceivePort) {
      try {
        final handler = _commandHandlers[cmd.type];
        if (handler == null) {
          throw Exception('Unknown command type. type=${cmd.type}');
        }
        db = handler(db, cmd, ourReceivePort);
      } catch (e, s) {
        _log.severe('Could not execute Sqlite command', e, s);
        cmd.sendPort.send(
          AsyncDatabaseCommand(
            cmd.type,
            ourReceivePort.sendPort,
            body: RemoteErrorPayload(e.toString(), s.toString()),
            isError: true,
          ),
        );
      }
    }
  }

  static void _closeSync(
    Database db,
    AsyncDatabaseCommand cmd,
    ReceivePort ourReceivePort,
  ) {
    db.close();
    cmd.sendPort.send(AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort));
    ourReceivePort.close();
  }

  static void _selectSync(
    Database db,
    AsyncDatabaseCommand cmd,
    ReceivePort ourReceivePort,
  ) {
    StatementParams params = cmd.body;
    var response = db.select(params.sql, params.parameters);
    cmd.sendPort.send(
      AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort, body: response),
    );
  }

  static void _executeSync(
    Database db,
    AsyncDatabaseCommand cmd,
    ReceivePort ourReceivePort,
  ) {
    StatementParams params = cmd.body;
    db.execute(params.sql, params.parameters);
    cmd.sendPort.send(AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort));
  }

  static void _getLastInsertRowIdSync(
    Database db,
    AsyncDatabaseCommand cmd,
    ReceivePort ourReceivePort,
  ) {
    var rowId = db.lastInsertRowId;
    cmd.sendPort.send(
      AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort, body: rowId),
    );
  }

  static void _setUserVersionSync(
    Database db,
    AsyncDatabaseCommand cmd,
    ReceivePort ourReceivePort,
  ) {
    db.userVersion = cmd.body;
    cmd.sendPort.send(AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort));
  }

  static void _getUserVersionSync(
    Database db,
    AsyncDatabaseCommand cmd,
    ReceivePort ourReceivePort,
  ) {
    var version = db.userVersion;
    cmd.sendPort.send(
      AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort, body: version),
    );
  }

  static void _createFunctionSync(
    Database db,
    AsyncDatabaseCommand cmd,
    ReceivePort ourReceivePort,
  ) {
    CreateFunctionParams params = cmd.body;
    db.createFunction(
      functionName: params.functionName,
      function: params.function,
      argumentCount: params.argumentCount,
      deterministic: params.deterministic,
      directOnly: params.directOnly,
    );
    cmd.sendPort.send(AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort));
  }

  static void _createCollationSync(
    Database db,
    AsyncDatabaseCommand cmd,
    ReceivePort ourReceivePort,
  ) {
    CreateCollationParams params = cmd.body;
    db.createCollation(name: params.name, function: params.function);
    cmd.sendPort.send(AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort));
  }

  static Database _openSync(
    AsyncDatabaseCommand cmd,
    ReceivePort ourReceivePort,
  ) {
    OpenDatabaseParams params = cmd.body;
    Database db = sqlite3.open(
      params.filename,
      vfs: params.vfs,
      mode: params.mode,
      uri: params.uri,
      mutex: params.mutex,
    );
    cmd.sendPort.send(AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort));
    return db;
  }

  Future<dynamic> _sendCommand(String type, {dynamic body}) async {
    if (_isClosed) {
      throw StateError('AsyncDatabase is already closed.');
    }
    var receivePort = ReceivePort();
    var command = AsyncDatabaseCommand(type, receivePort.sendPort, body: body);
    _workerPort.send(command);
    AsyncDatabaseCommand response;
    try {
      response = await receivePort.first;
    } finally {
      receivePort.close();
    }
    if (response.isError) {
      final payload = response.body;
      if (payload is RemoteErrorPayload) {
        Error.throwWithStackTrace(
          AsyncDatabaseException(payload.message),
          StackTrace.fromString(payload.stackTrace),
        );
      }
      throw AsyncDatabaseException(payload.toString());
    }
    return response.body;
  }
}
