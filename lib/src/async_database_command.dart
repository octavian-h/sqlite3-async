import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// Internal message envelope exchanged between [AsyncDatabase] and its
/// worker isolate. Not part of the public API.
@immutable
class AsyncDatabaseCommand {
  final String type;
  final SendPort sendPort;
  final dynamic body;
  final bool isError;

  const AsyncDatabaseCommand(
    this.type,
    this.sendPort, {
    this.body,
    this.isError = false,
  });
}
