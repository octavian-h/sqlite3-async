## 1.1.0

* Update dependencies (sqlite3 to 3.5.2 and other transitive packages)
* Add `AsyncDatabase.transaction()` helper to run a callback within a `BEGIN`/`COMMIT`/`ROLLBACK` block
* `close()`/`dispose()` are now idempotent and calling any method after close throws a `StateError`
* Errors thrown in the worker isolate now preserve their original stack trace and are surfaced as `AsyncDatabaseException`
* Add a `Finalizer` to automatically terminate the worker isolate if an `AsyncDatabase` is garbage collected without being closed
* Internal isolate command protocol refactored to use a dispatch map instead of a switch statement
* Split library internals into individual files under `lib/src/`

## 1.0.9

* Update dependencies

## 1.0.8

* Update dependencies
* Remove sqlite3_flutter_libs 

## 1.0.7

* Update dependencies
* [@vorlovsky](https://github.com/vorlovsky): added createCollation async method

## 1.0.6

* Update dependencies
* [@vorlovsky](https://github.com/vorlovsky): added createFunction async method

## 1.0.5

* Update dependencies

## 1.0.4

* Update dependencies

## 1.0.3

* Update dependencies and add logging framework

## 1.0.2

* Improve example

## 1.0.1

* Add example folder

## 1.0.0

* Initial release
