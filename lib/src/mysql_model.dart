import 'package:sqler/sqler.dart';

/// Represents a MySQL table definition with fields, foreign keys, and table options.
///
/// This class implements the [SQL] interface and provides functionality to generate
/// CREATE TABLE statements for MySQL databases.
///
/// Example:
/// ```dart
/// final table = MTable(
///   name: 'users',
///   fields: [
///     MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
///     MFieldVarchar(name: 'name', length: 100),
///     MFieldVarchar(name: 'email', length: 255),
///   ],
/// );
/// print(table.toSQL()); // Generates CREATE TABLE statement
/// ```
class MTable implements SQL {
  /// The name of the table
  String name;

  /// List of fields/columns in the table
  List<MField> fields;

  /// List of foreign key constraints for the table
  List<ForeignKey> foreignKeys;

  /// Character set for the table (default: utf8mb4)
  String charset = 'utf8mb4';

  /// Collation for the table (default: utf8mb4_unicode_ci)
  String collation = 'utf8mb4_unicode_ci';

  /// Storage engine for the table (default: InnoDB)
  String engine = 'InnoDB';

  /// Creates a new MySQL table definition.
  ///
  /// [name] is the table name (required)
  /// [fields] is the list of table fields/columns (required)
  /// [foreignKeys] is the list of foreign key constraints (optional, defaults to empty list)
  /// [charset] is the character set for the table (optional, defaults to 'utf8mb4')
  /// [collation] is the collation for the table (optional, defaults to 'utf8mb4_unicode_ci')
  MTable({
    required this.name,
    required this.fields,
    this.foreignKeys = const [],
    this.charset = 'utf8mb4',
    this.collation = 'utf8mb4_unicode_ci',
  });

  /// Generates a list of [QSelectField] objects for SELECT queries with aliases.
  ///
  /// [from] is the source table/alias prefix for field names
  /// [as] is the target alias prefix for the result fields
  ///
  /// Returns a list of [QSelectField] objects that can be used in SELECT statements.
  ///
  /// Example:
  /// ```dart
  /// final fields = table.getFieldsAs('u', 'user');
  /// // Generates: u.id AS user.id, u.name AS user.name, etc.
  /// ```
  List<QSelectField> getFieldsAs(String from, String as) {
    return fields.map((field) {
      return QSelectCustom(
        QMath(from.isEmpty ? field.name : "$from.${field.name}"),
        as: as.isEmpty ? field.name : '$as.${field.name}',
      );
    }).toList();
  }

  /// Generates the SQL CREATE TABLE statement for this table.
  ///
  /// Returns a complete MySQL CREATE TABLE statement including all fields,
  /// engine, charset, and collation specifications.
  @override
  String toSQL() {
    String sql = 'CREATE TABLE `$name` (';
    sql += fields.map((field) => field.toSQL()).join(', ');
    sql += ') ENGINE=$engine DEFAULT CHARSET=$charset COLLATE=$collation;';
    return sql;
  }

  /// Validates the provided data against the table's fields.
  /// Returns a map of field names to lists of validation error messages.
  /// @data are input data to validate against the table's fields.
  /// @returns a map of field names to lists of validation error messages.
  Future<Map<String, List<String>>> formValidate(
    Map<String, Object?> data,
  ) async {
    Map<String, List<String>> results = {};

    var exteraData = <String, Object?>{};
    for (final field in this.fields) {
      var value = data[field.name];
      results[field.name] = await field.validate(value);
      exteraData[field.name] = data[field.name];
    }

    return results;
  }
}

typedef ValidatorEvent<T> = Future<String> Function(T value);

/// Abstract base class for all MySQL field types.
///
/// This class provides the common structure and behavior for all database field types,
/// including properties for constraints, defaults, and comments.
///
/// All concrete field implementations should extend this class and provide
/// their specific field type through the [FieldTypes] enum.
abstract class MField implements SQL {
  /// The name of the field/column
  String name;

  /// The MySQL data type for this field
  FieldTypes type;

  /// Whether this field is a primary key
  bool isPrimaryKey;

  /// Whether this field has auto-increment enabled
  bool isAutoIncrement;

  /// Whether this field allows NULL values
  bool isNullable;

  /// Default value for the field (empty string means no default)
  String defaultValue;

  /// Optional comment for the field
  String? comment;

  /// Additional options for the field (e.g., length, precision)
  String _options = '';

  List<ValidatorEvent> validators;

  /// Creates a new MySQL field definition.
  ///
  /// [name] is the field name (required)
  /// [type] is the MySQL data type (required)
  /// [isPrimaryKey] indicates if this is a primary key field (default: false)
  /// [isAutoIncrement] enables auto-increment for the field (default: false)
  /// [isNullable] allows NULL values for the field (default: false)
  /// [defaultValue] sets a default value for the field (default: empty string)
  /// [comment] adds a comment to the field definition (optional)
  MField({
    required this.name,
    required this.type,
    this.isPrimaryKey = false,
    this.isAutoIncrement = false,
    this.isNullable = false,
    this.defaultValue = '',
    this.comment,
    this.validators = const [],
  });

  /// Validates the provided value against the field's constraints.
  /// Returns a list of validation error messages.
  /// @param value is the value to validate
  /// @returns a list of validation error messages, empty if valid
  Future<List<String>> validate(dynamic value) async {
    var results = <String>[];

    for (var validator in validators) {
      var result = await validator(value);
      if (result.isNotEmpty) {
        results.add(result);
      }
    }

    return results;
  }

  /// Generates the SQL field definition for this field.
  ///
  /// Returns a complete MySQL field definition including data type,
  /// constraints, default values, and comments.
  ///
  /// Example output: "`field_name` INT NOT NULL AUTO_INCREMENT PRIMARY KEY"
  @override
  String toSQL() {
    String sql = '${QField(name).toSQL()} ${type.toSQL()}$_options';
    if (isPrimaryKey) {
      sql += ' PRIMARY KEY';
    }
    if (isAutoIncrement) {
      sql += ' AUTO_INCREMENT';
    }
    if (!isNullable) {
      sql += ' NOT NULL';
    }
    if (defaultValue.isNotEmpty) {
      final reservedWords = [
        'CURRENT_TIMESTAMP',
        'NULL',
        'TRUE',
        'FALSE',
        'NOW',
      ];
      if (reservedWords.contains(defaultValue.toUpperCase())) {
        sql += ' DEFAULT $defaultValue';
      } else {
        sql += ' DEFAULT "$defaultValue"';
      }
    }
    if (comment != null) {
      sql += ' COMMENT "$comment"';
    }
    return sql;
  }
}

/// MySQL INT field type.
///
/// Represents a standard 32-bit signed integer field in MySQL.
/// Range: -2,147,483,648 to 2,147,483,647
class MFieldInt extends MField {
  MFieldInt({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.INT);
}

/// MySQL BIGINT field type.
///
/// Represents a 64-bit signed integer field in MySQL.
/// Range: -9,223,372,036,854,775,808 to 9,223,372,036,854,775,807
class MBigInt extends MField {
  MBigInt({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.BIGINT);
}

/// MySQL MEDIUMINT field type.
///
/// Represents a 24-bit signed integer field in MySQL.
/// Range: -8,388,608 to 8,388,607
class MMediumInt extends MField {
  MMediumInt({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.MEDIUMINT);
}

/// MySQL SMALLINT field type.
///
/// Represents a 16-bit signed integer field in MySQL.
/// Range: -32,768 to 32,767
class MSmallInt extends MField {
  MSmallInt({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.SMALLINT);
}

/// MySQL TINYINT field type.
///
/// Represents an 8-bit signed integer field in MySQL.
/// Range: -128 to 127 (or 0 to 255 if unsigned)
///
/// Commonly used for boolean values or small integers.
class MTinyInt extends MField {
  /// Creates a TINYINT field.
  ///
  /// [length] specifies the display width (optional, typically 1-4)
  MTinyInt({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    int? length,
    super.validators = const [],
  }) : super(type: FieldTypes.TINYINT) {
    _options = length != null ? '(${length.toString()})' : '';
  }
}

/// MySQL CHAR field type.
///
/// Represents a fixed-length character string field in MySQL.
/// Always uses exactly the specified number of characters, padding with spaces if necessary.
///
/// Use CHAR for strings that are always the same length (e.g., country codes, status flags).
class MFieldChar extends MField {
  /// Creates a CHAR field.
  ///
  /// [length] specifies the exact character length (default: 255, max: 255)
  MFieldChar({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
    int length = 255,
  }) : super(type: FieldTypes.CHAR) {
    _options = '(${length.toString()})';
  }
}

/// MySQL VARCHAR field type.
///
/// Represents a variable-length character string field in MySQL.
/// Only uses the space needed for the actual string content.
///
/// Use VARCHAR for strings with varying lengths (e.g., names, emails, descriptions).
class MFieldVarchar extends MFieldChar {
  /// Creates a VARCHAR field.
  ///
  /// [length] specifies the maximum character length (default: 255, max: 65535)
  MFieldVarchar({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
    int length = 255,
  }) {
    super.type = FieldTypes.VARCHAR;
    _options = '(${length.toString()})';
  }
}

/// MySQL FLOAT field type.
///
/// Represents a single-precision floating-point number field in MySQL.
/// Suitable for approximate numeric values with decimal places.
class MFieldFloat extends MField {
  /// Creates a FLOAT field.
  ///
  /// [m] specifies the total number of digits (precision)
  /// [d] specifies the number of digits after the decimal point (scale, optional)
  MFieldFloat({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
    required int m,
    int? d,
  }) : super(type: FieldTypes.FLOAT) {
    _options = '($m${d != null ? ', $d' : ''})';
  }
}

/// MySQL DECIMAL field type.
///
/// Represents an exact fixed-point number field in MySQL.
/// Use for precise decimal calculations (e.g., monetary values, scientific data).
class MFieldDecimal extends MField {
  /// Creates a DECIMAL field.
  ///
  /// [m] specifies the total number of digits (precision, default: 10)
  /// [d] specifies the number of digits after the decimal point (scale, default: 2)
  MFieldDecimal({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
    int m = 10,
    int d = 2,
  }) : super(type: FieldTypes.DECIMAL) {
    _options = '($m,$d)';
  }
}

/// MySQL BOOLEAN field type.
///
/// Represents a boolean field in MySQL (implemented as TINYINT(1)).
/// Stores TRUE/FALSE values (1/0 internally).
class MFieldBoolean extends MField {
  MFieldBoolean({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.BOOLEAN);
}

/// MySQL TEXT field type.
///
/// Represents a variable-length text field in MySQL.
/// Can store up to 65,535 characters. Use for medium-length text content.
class MFieldText extends MField {
  MFieldText({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.TEXT);
}

/// MySQL TINYTEXT field type.
///
/// Represents a small variable-length text field in MySQL.
/// Can store up to 255 characters. Use for short text content.
class MFieldTinyText extends MField {
  MFieldTinyText({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.TINYTEXT);
}

/// MySQL MEDIUMTEXT field type.
///
/// Represents a medium variable-length text field in MySQL.
/// Can store up to 16,777,215 characters. Use for large text content.
class MFieldMediumText extends MField {
  MFieldMediumText({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.MEDIUMTEXT);
}

/// MySQL LONGTEXT field type.
///
/// Represents a very large variable-length text field in MySQL.
/// Can store up to 4,294,967,295 characters. Use for very large text content.
class MFieldLongText extends MField {
  MFieldLongText({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.LONGTEXT);
}

/// MySQL DATE field type.
///
/// Represents a date field in MySQL (YYYY-MM-DD format).
/// Range: '1000-01-01' to '9999-12-31'
class MFieldDate extends MField {
  MFieldDate({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.DATE);
}

/// MySQL DATETIME field type.
///
/// Represents a date and time field in MySQL (YYYY-MM-DD HH:MM:SS format).
/// Range: '1000-01-01 00:00:00' to '9999-12-31 23:59:59'
class MFieldDateTime extends MField {
  MFieldDateTime({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.DATETIME);
}

/// MySQL TIMESTAMP field type.
///
/// Represents a timestamp field in MySQL with automatic updates.
/// Range: '1970-01-01 00:00:01' UTC to '2038-01-19 03:14:07' UTC
/// Often used for created_at and updated_at fields.
class MFieldTimestamp extends MField {
  MFieldTimestamp({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.TIMESTAMP);
}

/// MySQL BIT field type.
///
/// Represents a bit field in MySQL for storing bit values.
/// Can store 1 to 64 bits of data.
class MFieldBit extends MField {
  /// Creates a BIT field.
  ///
  /// [length] specifies the number of bits (default: 8, range: 1-64)
  MFieldBit({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
    int length = 8,
  }) : super(type: FieldTypes.BIT) {
    _options = '($length)';
  }
}

/// MySQL TIME field type.
///
/// Represents a time field in MySQL (HH:MM:SS format).
/// Range: '-838:59:59' to '838:59:59'
class MFieldTime extends MField {
  MFieldTime({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.TIME);
}

/// MySQL YEAR field type.
///
/// Represents a year field in MySQL.
/// Can store 4-digit years (1901 to 2155) or 2-digit years (70-99 for 1970-1999, 00-69 for 2000-2069).
class MFieldYear extends MField {
  /// Creates a YEAR field.
  ///
  /// [length] specifies the display format (default: 4, can be 2 or 4)
  MFieldYear({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
    int length = 4,
  }) : super(type: FieldTypes.YEAR) {
    _options = '($length)';
  }
}

/// MySQL BINARY field type.
///
/// Represents a fixed-length binary string field in MySQL.
/// Similar to CHAR but stores binary byte strings instead of character strings.
class MFieldBinary extends MField {
  /// Creates a BINARY field.
  ///
  /// [length] specifies the exact byte length (default: 255, max: 255)
  MFieldBinary({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
    int length = 255,
  }) : super(type: FieldTypes.BINARY) {
    _options = '($length)';
  }
}

/// MySQL VARBINARY field type.
///
/// Represents a variable-length binary string field in MySQL.
/// Similar to VARCHAR but stores binary byte strings instead of character strings.
class MFieldVarBinary extends MField {
  /// Creates a VARBINARY field.
  ///
  /// [length] specifies the maximum byte length (default: 255, max: 65535)
  MFieldVarBinary({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
    int length = 255,
  }) : super(type: FieldTypes.VARBINARY) {
    _options = '($length)';
  }
}

/// MySQL BLOB field type.
///
/// Represents a binary large object field in MySQL.
/// Can store up to 65,535 bytes of binary data.
class MFieldBlob extends MField {
  MFieldBlob({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.BLOB);
}

/// MySQL MEDIUMBLOB field type.
///
/// Represents a medium binary large object field in MySQL.
/// Can store up to 16,777,215 bytes of binary data.
class MFieldMediumBlob extends MField {
  MFieldMediumBlob({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.MEDIUMBLOB);
}

/// MySQL LONGBLOB field type.
///
/// Represents a very large binary object field in MySQL.
/// Can store up to 4,294,967,295 bytes of binary data.
class MFieldLongBlob extends MField {
  MFieldLongBlob({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.LONGBLOB);
}

/// MySQL TINYBLOB field type.
///
/// Represents a small binary large object field in MySQL.
/// Can store up to 255 bytes of binary data.
class MFieldTinyBlob extends MField {
  MFieldTinyBlob({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.TINYBLOB);
}

/// MySQL ENUM field type.
///
/// Represents an enumeration field in MySQL.
/// Can store one value from a predefined list of string values.
class MFieldEnum extends MField {
  /// Creates an ENUM field.
  ///
  /// [values] is a list of allowed string values for the enumeration
  MFieldEnum({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
    required List<String> values,
  }) : super(type: FieldTypes.ENUM) {
    _options = '(${values.map((v) => "'$v'").join(', ')})';
  }
}

/// MySQL SET field type.
///
/// Represents a set field in MySQL.
/// Can store zero or more values from a predefined list of string values.
class MFieldSet extends MField {
  /// Creates a SET field.
  ///
  /// [values] is a list of allowed string values for the set
  MFieldSet({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
    required List<String> values,
  }) : super(type: FieldTypes.SET) {
    _options = '(${values.map((v) => "'$v'").join(', ')})';
  }
}

/// MySQL JSON field type.
///
/// Represents a JSON document field in MySQL (MySQL 5.7+).
/// Provides native JSON storage and manipulation capabilities.
class MFieldJson extends MField {
  MFieldJson({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
  }) : super(type: FieldTypes.JSON);
}

/// MySQL POINT field type.
///
/// Represents a geometric point field in MySQL.
/// Stores X,Y coordinates in a spatial coordinate system.
class MFieldPoint extends MField {
  /// Creates a POINT field.
  ///
  /// [srid] specifies the Spatial Reference System Identifier (optional)
  MFieldPoint({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
    int? srid,
  }) : super(type: FieldTypes.POINT) {
    if (srid != null) {
      _options = 'SRID $srid';
    }
  }
}

/// MySQL POLYGON field type.
///
/// Represents a geometric polygon field in MySQL.
/// Stores polygon shapes defined by multiple coordinate points.
class MFieldPolygon extends MField {
  /// Creates a POLYGON field.
  ///
  /// [srid] specifies the Spatial Reference System Identifier (optional)
  MFieldPolygon({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    super.validators = const [],
    int? srid,
  }) : super(type: FieldTypes.POLYGON) {
    if (srid != null) {
      _options = 'SRID $srid';
    }
  }
}

/// Enumeration of all supported MySQL field types.
///
/// This enum provides a comprehensive list of MySQL data types that can be used
/// when defining table fields. Each enum value corresponds to a specific MySQL data type.
enum FieldTypes implements SQL {
  /// Integer types
  INT('INT'),
  BIGINT('BIGINT'),
  MEDIUMINT('MEDIUMINT'),
  SMALLINT('SMALLINT'),
  TINYINT('TINYINT'),

  /// String types
  CHAR('CHAR'),
  VARCHAR('VARCHAR'),

  /// Floating-point types
  FLOAT('FLOAT'),
  DECIMAL('DECIMAL'),

  /// Boolean type
  BOOLEAN('BOOLEAN'),

  /// Text types
  TEXT('TEXT'),
  TINYTEXT('TINYTEXT'),
  MEDIUMTEXT('MEDIUMTEXT'),
  LONGTEXT('LONGTEXT'),

  /// Date and time types
  DATE('DATE'),
  DATETIME('DATETIME'),
  TIMESTAMP('TIMESTAMP'),
  TIME('TIME'),
  YEAR('YEAR'),

  /// Binary types
  BIT('BIT'),
  BINARY('BINARY'),
  VARBINARY('VARBINARY'),

  /// BLOB types
  BLOB('BLOB'),
  MEDIUMBLOB('MEDIUMBLOB'),
  LONGBLOB('LONGBLOB'),
  TINYBLOB('TINYBLOB'),

  /// Special types
  ENUM('ENUM'),
  SET('SET'),
  JSON('JSON'),

  /// Spatial types
  POINT('POINT'),
  POLYGON('POLYGON');

  /// The SQL type name for this field type
  final String sqlType;

  /// Creates a field type with the corresponding SQL type name
  const FieldTypes(this.sqlType);

  /// Returns the SQL representation of this field type
  @override
  String toSQL() => sqlType;
}

/// Represents a foreign key constraint in MySQL.
///
/// Foreign keys establish and enforce a link between data in two tables,
/// ensuring referential integrity in the database.
///
/// Example:
/// ```dart
/// final fk = ForeignKey(
///   name: 'user_id',
///   refTable: 'users',
///   refColumn: 'id',
///   onDelete: 'CASCADE',
///   onUpdate: 'RESTRICT',
/// );
/// ```
class ForeignKey implements SQL {
  /// The name of the foreign key field in the current table
  String name;

  /// The name of the referenced table
  String refTable;

  /// The name of the referenced column in the target table (default: 'id')
  String refColumn;

  /// Action to take when the referenced record is deleted (default: 'NO ACTION')
  String onDelete;

  /// Action to take when the referenced record is updated (default: 'NO ACTION')
  String onUpdate;

  /// Creates a foreign key constraint.
  ///
  /// [name] is the field name in the current table (required)
  /// [refTable] is the referenced table name (required)
  /// [refColumn] is the referenced column name (default: 'id')
  /// [onDelete] specifies the action on delete (default: 'NO ACTION')
  ///   Common values: 'CASCADE', 'SET NULL', 'RESTRICT', 'NO ACTION'
  /// [onUpdate] specifies the action on update (default: 'NO ACTION')
  ///   Common values: 'CASCADE', 'SET NULL', 'RESTRICT', 'NO ACTION'
  ForeignKey({
    required this.name,
    required this.refTable,
    this.refColumn = 'id',
    this.onDelete = 'NO ACTION',
    this.onUpdate = 'NO ACTION',
  });

  /// Generates the SQL foreign key constraint definition.
  ///
  /// Returns a complete MySQL foreign key constraint statement.
  @override
  String toSQL() {
    return 'FOREIGN KEY (`$name`) REFERENCES `$refTable`(`$refColumn`) ON DELETE $onDelete ON UPDATE $onUpdate';
  }
}
