# sqlite3_async

[![pub package](https://img.shields.io/pub/v/sqlite3_async.svg)](https://pub.dev/packages/sqlite3_async)

Provides a subset of async operations on top of [sqlite3](https://pub.dev/packages/sqlite3) plugin.

## Features

This package provides async operations for:

- opening a Sqlite database
- executing a SQL command
- configuring DB user version
- getting last inserted row id

## Getting started

To install this package run:

```bash
flutter pub add sqlite3_async
```

For Flutter applications you need to add the native SQLite library with:

```bash
flutter pub add sqlite3_flutter_libs
```

For other platforms, read [sqlite3 docs](https://pub.dev/packages/sqlite3#supported-platforms)

## Usage

```dart
import 'package:sqlite3_async/sqlite3_async.dart';

void main() async {
  var db = await AsyncDatabase.open("example.db");
  await db.execute("CREATE TABLE items("
      "id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "name TEXT NOT NULL)");
  await db.execute("INSERT INTO items (name) VALUES (?)", ["book"]);
  await db.execute("INSERT INTO items (name) VALUES (?)", ["toy"]);

  var resultSet = await db
      .select("SELECT count(id) AS c FROM items");
  print('Results: $resultSet');
  await db.dispose();
}
```

## Additional information

If you encounter any problems or you feel the library is missing a feature, please raise
a [ticket](https://github.com/octavian-h/sqlite3-async/issues) on
GitHub and I'll look into it. Pull request are also welcome.
