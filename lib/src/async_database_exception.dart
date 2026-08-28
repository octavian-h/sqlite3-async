class AsyncDatabaseException implements Exception {
  final String message;

  const AsyncDatabaseException(this.message);

  @override
  String toString() => message;
}
