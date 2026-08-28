import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';

/// Parameters used to register a custom scalar function in the worker
/// isolate.
@immutable
class CreateFunctionParams {
  final String functionName;
  final ScalarFunction function;
  final AllowedArgumentCount argumentCount;
  final bool deterministic;
  final bool directOnly;

  const CreateFunctionParams({
    required this.functionName,
    required this.function,
    this.argumentCount = const AllowedArgumentCount.any(),
    this.deterministic = false,
    this.directOnly = true,
  });
}
