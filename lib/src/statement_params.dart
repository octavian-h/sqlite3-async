import 'package:flutter/foundation.dart';

/// Parameters for an `execute`/`select` SQL statement sent to the worker
/// isolate.
@immutable
class StatementParams {
  final String sql;
  final List<Object?> parameters;

  const StatementParams(this.sql, this.parameters);
}
