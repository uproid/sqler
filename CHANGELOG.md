## 1.1.2

- Password QVar `QVar.password('test', hashType: HashType.sha1)` support sha1, md5(default), sha256, sha512, HMAC-SHA256
- `SqlExplain` class able to generate EXPLAIN details from other SQL. `SqlExplain(sqlerQuery).toSQL()`

## 1.1.0

- Added DISTINCT for QField
- Improve the Aggregate Functions #1
- Added Validator functionalty for input variables in MField and MTable

## 1.0.1

- Added `MTable` and `MField` classes for table and field abstraction.
- Implemented SQL generation for `CREATE TABLE` statements.
- Improved code structure for easier table definition and management.

## 1.0.0

- Initial version.
