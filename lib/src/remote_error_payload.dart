import 'package:flutter/foundation.dart';

/// Serializable error payload sent from the worker isolate back to the
/// caller when a command fails, preserving the original message and
/// stack trace across the isolate boundary.
@immutable
class RemoteErrorPayload {
  final String message;
  final String stackTrace;

  const RemoteErrorPayload(this.message, this.stackTrace);
}
