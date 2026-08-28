import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

/// Parameters used to register a custom collation in the worker isolate.
@immutable
class CreateCollationParams {
  final String name;
  final CollatingFunction function;

  const CreateCollationParams({required this.name, required this.function});
}
