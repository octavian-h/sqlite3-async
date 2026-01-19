library;

import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:sqlite3/sqlite3.dart';

export 'package:sqlite3/sqlite3.dart' show AllowedArgumentCount, sqlite3, SqliteExtension;

/// An opened sqlite3 database with async methods.
class AsyncDatabase {
  static final Logger _log = Logger((AsyncDatabase).toString());

  final Isolate _worker;
  final SendPort _workerPort;

  AsyncDatabase._(this._worker, this._workerPort);

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
    var worker = await Isolate.spawn(_executeCommand,
        _AsyncDatabaseCommand("_init", receivePort.sendPort, body: token));

    _AsyncDatabaseCommand response = await receivePort.first;
    var workerPort = response.sendPort;
    var asyncDatabase = AsyncDatabase._(worker, workerPort);
    await asyncDatabase._sendCommand("open",
        body: _OpenDatabaseParams(filename, vfs, mode, uri, mutex));
    return asyncDatabase;
  }

  /// Returns the application defined version of this database.
  Future<int> getUserVersion() async {
    return await _sendCommand("getUserVersion");
  }

  /// Set the application defined version of this database.
  Future<void> setUserVersion(int value) async {
    await _sendCommand("setUserVersion", body: value);
  }

  /// Returns the row id of the last inserted row.
  Future<int> getLastInsertRowId() async {
    return await _sendCommand("getLastInsertRowId");
  }

  /// Executes the [sql] statement with the provided [parameters] and ignores
  /// the result.
  Future<void> execute(String sql,
      [List<Object?> parameters = const []]) async {
    await _sendCommand("execute", body: _StatementParams(sql, parameters));
  }

  /// Prepares the [sql] select statement and runs it with the provided
  /// [parameters].
  Future<ResultSet> select(String sql,
      [List<Object?> parameters = const []]) async {
    return await _sendCommand("select",
        body: _StatementParams(sql, parameters));
  }

  // Register a custom function we can invoke from sql
  Future<void> createFunction({
    required String functionName,
    required ScalarFunction function,
    AllowedArgumentCount argumentCount = const AllowedArgumentCount.any(),
    bool deterministic = false,
    bool directOnly = true,
  }) async {
    return await _sendCommand("createFunction",
        body: _CreateFunctionParams(
          functionName: functionName,
          function: function,
          argumentCount: argumentCount,
          deterministic: deterministic,
          directOnly: directOnly,
        ));
  }

  // Register a custom collation
  Future<void> createCollation({
    required String name,
    required CollatingFunction function,
  }) async {
    return await _sendCommand("createCollation",
        body: _CreateCollationParams(
          name: name,
          function: function,
        ));
  }

  /// Closes this database and releases associated resources.
  Future<void> dispose() async {
    await _sendCommand("dispose");
    _worker.kill();
  }

  static void _executeCommand(_AsyncDatabaseCommand initCmd) async {
    var ourReceivePort = ReceivePort();
    assert(initCmd.type == "_init");
    BackgroundIsolateBinaryMessenger.ensureInitialized(initCmd.body);
    initCmd.sendPort
        .send(_AsyncDatabaseCommand(initCmd.type, ourReceivePort.sendPort));

    Database? db;
    await for (_AsyncDatabaseCommand cmd in ourReceivePort) {
      try {
        switch (cmd.type) {
          case "open":
            db = _openSync(cmd, ourReceivePort);
            break;
          case "getUserVersion":
            _getUserVersionSync(db!, cmd, ourReceivePort);
            break;
          case "setUserVersion":
            _setUserVersionSync(db!, cmd, ourReceivePort);
            break;
          case "getLastInsertRowId":
            _getLastInsertRowIdSync(db!, cmd, ourReceivePort);
            break;
          case "execute":
            _executeSync(db!, cmd, ourReceivePort);
            break;
          case "select":
            _selectSync(db!, cmd, ourReceivePort);
            break;
          case "createFunction":
            _createFunctionSync(db!, cmd, ourReceivePort);
            break;
          case "createCollation":
            _createCollationSync(db!, cmd, ourReceivePort);
            break;
          case "dispose":
            _disposeSync(db!, cmd, ourReceivePort);
            break;
          default:
            throw Exception("Unknown command type. type=${cmd.type}");
        }
      } catch (e, s) {
        _log.severe("Could not execute Sqlite command", e, s);
        cmd.sendPort.send(_AsyncDatabaseCommand(
            cmd.type, ourReceivePort.sendPort,
            body: e, isError: true));
      }
    }
  }

  static void _disposeSync(
      Database db, _AsyncDatabaseCommand cmd, ReceivePort ourReceivePort) {
    db.dispose();
    cmd.sendPort.send(_AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort));
    ourReceivePort.close();
  }

  static void _selectSync(
      Database db, _AsyncDatabaseCommand cmd, ReceivePort ourReceivePort) {
    _StatementParams params = cmd.body;
    var response = db.select(params.sql, params.parameters);
    cmd.sendPort.send(_AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort,
        body: response));
  }

  static void _executeSync(
      Database db, _AsyncDatabaseCommand cmd, ReceivePort ourReceivePort) {
    _StatementParams params = cmd.body;
    db.execute(params.sql, params.parameters);
    cmd.sendPort.send(_AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort));
  }

  static void _getLastInsertRowIdSync(
      Database db, _AsyncDatabaseCommand cmd, ReceivePort ourReceivePort) {
    var rowId = db.lastInsertRowId;
    cmd.sendPort.send(
        _AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort, body: rowId));
  }

  static void _setUserVersionSync(
      Database db, _AsyncDatabaseCommand cmd, ReceivePort ourReceivePort) {
    db.userVersion = cmd.body;
    cmd.sendPort.send(_AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort));
  }

  static void _getUserVersionSync(
      Database db, _AsyncDatabaseCommand cmd, ReceivePort ourReceivePort) {
    var version = db.userVersion;
    cmd.sendPort.send(_AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort,
        body: version));
  }

  static void _createFunctionSync(
      Database db, _AsyncDatabaseCommand cmd, ReceivePort ourReceivePort) {
    _CreateFunctionParams params = cmd.body;
    db.createFunction(
      functionName: params.functionName,
      function: params.function,
      argumentCount: params.argumentCount,
      deterministic: params.deterministic,
      directOnly: params.directOnly,
    );
    cmd.sendPort.send(_AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort));
  }

  static void _createCollationSync(
      Database db, _AsyncDatabaseCommand cmd, ReceivePort ourReceivePort) {
    _CreateCollationParams params = cmd.body;
    db.createCollation(
      name: params.name,
      function: params.function,
    );
    cmd.sendPort.send(_AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort));
  }

  static Database _openSync(_AsyncDatabaseCommand cmd, ReceivePort ourReceivePort) {
    _OpenDatabaseParams params = cmd.body;
    Database db = sqlite3.open(params.filename,
        vfs: params.vfs,
        mode: params.mode,
        uri: params.uri,
        mutex: params.mutex);
    cmd.sendPort.send(_AsyncDatabaseCommand(cmd.type, ourReceivePort.sendPort));
    return db;
  }

  Future<dynamic> _sendCommand(String type, {dynamic body}) async {
    var receivePort = ReceivePort();
    var command = _AsyncDatabaseCommand(type, receivePort.sendPort, body: body);
    _workerPort.send(command);
    _AsyncDatabaseCommand response = await receivePort.first;
    if (response.isError) {
      throw response.body;
    }
    return response.body;
  }
}

@immutable
class _AsyncDatabaseCommand {
  final String type;
  final SendPort sendPort;
  final dynamic body;
  final bool isError;

  const _AsyncDatabaseCommand(this.type, this.sendPort,
      {this.body, this.isError = false});
}

@immutable
class _OpenDatabaseParams {
  final String filename;
  final String? vfs;
  final OpenMode mode;
  final bool uri;
  final bool? mutex;

  const _OpenDatabaseParams(
      this.filename, this.vfs, this.mode, this.uri, this.mutex);
}

@immutable
class _StatementParams {
  final String sql;
  final List<Object?> parameters;

  const _StatementParams(this.sql, this.parameters);
}

@immutable
class _CreateFunctionParams {
  final String functionName;
  final ScalarFunction function;
  final AllowedArgumentCount argumentCount;
  final bool deterministic;
  final bool directOnly;

  const _CreateFunctionParams({
    required this.functionName,
    required this.function,
    this.argumentCount = const AllowedArgumentCount.any(),
    this.deterministic = false,
    this.directOnly = true,
  });
}

@immutable
class _CreateCollationParams {
  final String name;
  final CollatingFunction function;

  const _CreateCollationParams({
    required this.name,
    required this.function,
  });
}
