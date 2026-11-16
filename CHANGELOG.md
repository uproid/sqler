## Unreleased
- **SECURITY**: Fixed several SQL injection vectors (see `test/sqler_injection_test.dart`)
  - MySQL: backslash is now escaped and quotes are doubled (`''`) in `QVar` strings (previously `\'` could close the literal early)
  - `QVarLike` now uses the SQL dialect (it was always using MySQL escaping), escapes `\`, `%` and `_`, and adds `ESCAPE '\'` on SQLite
  - Identifiers (`QField`, `QSelect`, `QOrder`, aliases, joins, insert/update column names, DDL names) are quoted safely by doubling the quote character; every part of `a.b.c` is quoted
  - `QVar` throws `ArgumentError` for unsupported types (e.g. `Map`, arbitrary objects, NaN) instead of using `toString()`
  - `{param}` placeholders are no longer expanded inside string literals or inside already substituted values
  - `MField` default value, comment, enum/set values and `ForeignKey` names are escaped
- **FIXED (logic bug with security impact)**: an `OrWhere` combined with other top-level `where()` conditions was not parenthesised, so `tenant_id = 1 AND a = 1 OR b = 2` let the `OR` branch escape every other filter. It now renders `tenant_id = 1 AND ( a = 1 OR b = 2 )`
- **BREAKING (output only)**: `QField('table.name')` now renders `` `table`.`name` `` (was ``table.`name` ``), and `'` in MySQL strings renders as `''` instead of `\'`
- Raw classes (`QSelectString`, `QMath`, `SQL.custom`, `ConditionString`) are still unescaped by design - never pass user input to them


## 1.2.1
- Fixed [#24](https://github.com/uproid/sqler/issues/24) issue of unscaped string in QVar for sqlite
- Fixed reports of dart analyze.
- Update dependencies

## 1.2.0
- #### `Sqler().toSQL<Sqlite>()`
- **BREAKING CHANGE**: Renamed `mysql_query.dart` to `sql_query.dart` and `mysql_model.dart` to `sql_model.dart` for better generic SQL support
- **NEW**: Added SQLite support alongside existing MySQL functionality
- **NEW**: Introduced generic SQL types (`Mysql` and `Sqlite`) for database-specific SQL generation
- **NEW**: All `toSQL()` methods now accept a generic type parameter to generate database-specific SQL
- **NEW**: Added SQLite-specific field types (`INTEGER`, `REAL`) in `FieldTypes` enum
- **NEW**: Proper quotation handling - backticks for MySQL, double quotes for SQLite
- **NEW**: SQLite-compatible auto-increment syntax (`AUTOINCREMENT` vs `AUTO_INCREMENT`)
- **NEW**: Added `sqlite3` dependency for SQLite testing support
- **IMPROVED**: Updated all test cases to validate both MySQL and SQLite SQL generation
- **IMPROVED**: Enhanced `MFieldInt` to automatically use correct integer type based on target database
- **IMPROVED**: Modified all SQL component classes to extend `SQL` instead of implementing it
- **IMPROVED**: Better abstraction for cross-database compatibility while maintaining existing API

## 1.1.4

- Added `add()` and `clear()` methods to the `Where` class.
- Added `allSelectFields()` function to `MTable` to generate a list of all columns for selection.
- Added `whereAnd`, `whereOr`, and `whereOne` methods to the `Sqler` class.
- Added `OnOne` method to summarize `On` when there is only one.
- Added `Sqler` as a new value for `QVar` to allow using the `Sqler` class as a value in conditions.

## 1.1.3

- Fixed table name for JOIN's #23, #21

## 1.1.2

- Password QVar `QVar.password('test', hashType: HashType.sha1)` support sha1, md5(default), sha256, sha512, HMAC-SHA256
- `SqlExplain` class able to generate EXPLAIN details from other SQL. `SqlExplain(sqlerQuery).toSQL()`

## 1.1.0

- Added DISTINCT for QField #16
- Improve the Aggregate Functions #1
- Added Validator functionalty for input variables in MField and MTable

## 1.0.1

- Added `MTable` and `MField` classes for table and field abstraction.
- Implemented SQL generation for `CREATE TABLE` statements.
- Improved code structure for easier table definition and management.

## 1.0.0

- Initial version.
