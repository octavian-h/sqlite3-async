/// Provides a subset of async operations on top of the `sqlite3` package.
///
/// The [AsyncDatabase] class opens and drives a `Database` on a dedicated
/// background isolate, so blocking SQLite calls (opening a database,
/// executing statements, running queries, registering functions and
/// collations) never run on the caller's isolate. All public members of
/// this library are exposed through this file; everything under `src/`
/// is a private implementation detail of the isolate communication
/// protocol.
library;

export 'package:sqlite3/sqlite3.dart'
    show AllowedArgumentCount, sqlite3, SqliteExtension;

export 'src/async_database.dart';
export 'src/async_database_exception.dart';
