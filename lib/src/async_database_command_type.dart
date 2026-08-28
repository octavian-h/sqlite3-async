/// Command type constants used in the isolate message protocol between
/// [AsyncDatabase] and its worker isolate.
abstract final class AsyncDatabaseCommandType {
  static const open = 'open';
  static const getUserVersion = 'getUserVersion';
  static const setUserVersion = 'setUserVersion';
  static const getLastInsertRowId = 'getLastInsertRowId';
  static const execute = 'execute';
  static const select = 'select';
  static const createFunction = 'createFunction';
  static const createCollation = 'createCollation';
  static const close = 'close';
}
