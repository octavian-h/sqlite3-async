import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:sqlite3/common.dart';
import 'package:sqlite3_async/sqlite3_async.dart';

class StorageUtils {
  static AsyncDatabase? _itemsDb;

  static Future<void> init() async {
    var databaseDir = await path_provider.getApplicationSupportDirectory();
    if (!await databaseDir.exists()) {
      await databaseDir.create(recursive: true);
    }
    var dbPath = path.join(databaseDir.path, "items.db");
    _itemsDb = await AsyncDatabase.open(dbPath, mode: OpenMode.readWriteCreate);
    await _itemsDb!.execute("DROP TABLE IF EXISTS items");
    await _itemsDb!.execute("CREATE TABLE items("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "name TEXT NOT NULL)");
  }

  static Future<void> addItem(String name) {
    return _itemsDb!.execute("INSERT INTO items (name) VALUES (?)", [name]);
  }

  static Future<List<String>> readItems() async {
    return (await _itemsDb!.select("SELECT * FROM items"))
        .map((e) => e["name"].toString())
        .toList();
  }
}
