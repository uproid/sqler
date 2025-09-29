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
