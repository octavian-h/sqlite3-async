import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_async/sqlite3_async.dart';

void main() {
  const testDbPath = "test.db";

  setUp(() async {
    if (await File(testDbPath).exists()) {
      await File(testDbPath).delete();
    }
  });

  tearDown(() async {
    await File(testDbPath).delete();
  });

  test('configure db user version', () async {
    var db = await AsyncDatabase.open(testDbPath);
    var expectedUserVersion = 10;
    await db.setUserVersion(expectedUserVersion);
    var userVersion = await db.getUserVersion();

    expect(userVersion, expectedUserVersion);

    await db.close();
  });

  test('wrong SQL command', () async {
    var db = await AsyncDatabase.open(testDbPath);

    try {
      await db.execute("wrong command");
      fail("The exception wasn't thrown");
    } catch (e) {
      expect(e.toString(), startsWith("SqliteException(1): while executing"));
    }

    await db.close();
  });

  test('CRUD operations', () async {
    var db = await AsyncDatabase.open(testDbPath);
    await _createTable(db);
    await _insertItem("first", db);
    await _insertItem("second", db);
    var secondId = await db.getLastInsertRowId();
    var actualSecondId = await db.select("SELECT id FROM items WHERE name=?",
        ["second"]).then((value) => value.first["id"] as int);
    expect(actualSecondId, secondId);
    await db.close();

    var db2 = await AsyncDatabase.open(testDbPath, mode: OpenMode.readOnly);
    expect(await _countItems(db2), 2);
    await db2.close();
  });

  test('await with multiple inserts', () async {
    var db = await AsyncDatabase.open(testDbPath);
    await _createTable(db);
    List<Future<void>> futures = [];
    var triggeredInsertionsStart = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < 100; i++) {
      futures.add(_insertItem("a$i", db));
    }
    var triggeredInsertionsTime =
        DateTime.now().millisecondsSinceEpoch - triggeredInsertionsStart;
    for (var future in futures) {
      await future;
    }

    expect(await _countItems(db), 100);

    var fullInsertionsStart = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < 100; i++) {
      await _insertItem("b$i", db);
    }
    var fullInsertionsTime =
        DateTime.now().millisecondsSinceEpoch - fullInsertionsStart;

    expect(await _countItems(db), 200);
    expect(fullInsertionsTime, greaterThan(triggeredInsertionsTime));

    await db.close();
  });

  test('create custom function', () async {
    var db = await AsyncDatabase.open(testDbPath);
    await _createTable(db);

    await db.createFunction(
      functionName: 'get_int_from_row_name',
      argumentCount: const AllowedArgumentCount(1),
      function: (args) {
        final [name as String] = args;
        return int.parse(name.split('_')[1]);
      },
    );

    for (int i = 0; i < 100; i++) {
      await _insertItem("a_$i", db);
    }

    var rows = await db.select(
        "SELECT name, get_int_from_row_name(name) as name_int FROM items");

    expect(
        rows.every((element) => element['name'] == 'a_${element['name_int']}'),
        true);

    await db.close();
  });

  test('create collation', () async {
    var db = await AsyncDatabase.open(testDbPath);

    await db.createCollation(
      name: 'IGNORECASE',
      function: (a, b) {
        final al = (a ?? '').toLowerCase();
        final bl = (b ?? '').toLowerCase();
        return al.compareTo(bl);
      },
    );

    await db.execute("CREATE TABLE items("
        "id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "name TEXT COLLATE IGNORECASE NOT NULL)");

    await _insertItem("Charlie", db);
    await _insertItem("alice", db);
    await _insertItem("Bob", db);

    // Test 1: Collation affects ORDER BY
    var orderedRows = await db.select("SELECT name FROM items ORDER BY name");
    expect(
      orderedRows.map((r) => r['name']).toList(),
      ['alice', 'Bob', 'Charlie'],
    );

    // Test 2: Collation affects WHERE comparison
    var foundAlice =
        await db.select("SELECT name FROM items WHERE name = 'ALICE'");
    expect(foundAlice.length, 1);
    expect(foundAlice.first['name'], 'alice');

    // Test 3: Case-insensitive comparison works
    var foundBob = await db.select("SELECT name FROM items WHERE name = 'bob'");
    expect(foundBob.length, 1);
    expect(foundBob.first['name'], 'Bob');

    await db.close();
  });
}

Future<void> _insertItem(String itemName, AsyncDatabase db) {
  return db.execute("INSERT INTO items (name) VALUES (?)", [itemName]);
}

Future<void> _createTable(AsyncDatabase db) {
  return db.execute("CREATE TABLE items("
      "id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "name TEXT NOT NULL)");
}

Future<int> _countItems(AsyncDatabase db) async {
  return await db
      .select("SELECT count(id) AS c FROM items")
      .then((value) => value.first["c"] as int);
}
