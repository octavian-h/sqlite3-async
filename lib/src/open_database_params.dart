import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

/// Parameters used to open a database in the worker isolate.
@immutable
class OpenDatabaseParams {
  final String filename;
  final String? vfs;
  final OpenMode mode;
  final bool uri;
  final bool? mutex;

  const OpenDatabaseParams(
    this.filename,
    this.vfs,
    this.mode,
    this.uri,
    this.mutex,
  );
}
