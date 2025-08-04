import 'package:sqler/sqler.dart';

class MTable implements SQL {
  String name;
  List<MField> fields;
  List<ForeignKey> foreignKeys;
  String charset = 'utf8mb4';
  String collation = 'utf8mb4_unicode_ci';
  String engine = 'InnoDB';

  MTable({
    required this.name,
    required this.fields,
    this.foreignKeys = const [],
    this.charset = 'utf8mb4',
    this.collation = 'utf8mb4_unicode_ci',
  });

  List<QSelectField> getFieldsAs(String from, String as) {
    return fields.map((field) {
      return QSelectCustom(
        QMath(from.isEmpty ? field.name : "$from.${field.name}"),
        as: as.isEmpty ? field.name : '$as.${field.name}',
      );
    }).toList();
  }

  @override
  String toSQL() {
    String sql = 'CREATE TABLE `$name` (';
    sql += fields.map((field) => field.toSQL()).join(', ');
    sql += ') ENGINE=$engine DEFAULT CHARSET=$charset COLLATE=$collation;';
    return sql;
  }
}

abstract class MField implements SQL {
  String name;
  FieldTypes type;
  bool isPrimaryKey;
  bool isAutoIncrement;
  bool isNullable;
  String defaultValue;
  String? comment;
  String _options = '';

  MField({
    required this.name,
    required this.type,
    this.isPrimaryKey = false,
    this.isAutoIncrement = false,
    this.isNullable = false,
    this.defaultValue = '',
    this.comment,
  });

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

class MFieldInt extends MField {
  MFieldInt({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.INT);
}

class MBigInt extends MField {
  MBigInt({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.BIGINT);
}

class MMediumInt extends MField {
  MMediumInt({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.MEDIUMINT);
}

class MSmallInt extends MField {
  MSmallInt({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.SMALLINT);
}

class MTinyInt extends MField {
  MTinyInt({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    int? length,
  }) : super(type: FieldTypes.TINYINT) {
    _options = length != null ? '(${length.toString()})' : '';
  }
}

class MFieldChar extends MField {
  MFieldChar({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    int length = 255,
  }) : super(type: FieldTypes.CHAR) {
    _options = '(${length.toString()})';
  }
}

class MFieldVarchar extends MFieldChar {
  MFieldVarchar({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    int length = 255,
  }) {
    super.type = FieldTypes.VARCHAR;
    _options = '(${length.toString()})';
  }
}

class MFieldFloat extends MField {
  MFieldFloat({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    required int m,
    int? d,
  }) : super(type: FieldTypes.FLOAT) {
    _options = '($m${d != null ? ', $d' : ''})';
  }
}

class MFieldDecimal extends MField {
  MFieldDecimal({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    int m = 10,
    int d = 2,
  }) : super(type: FieldTypes.DECIMAL) {
    _options = '($m,$d)';
  }
}

class MFieldBoolean extends MField {
  MFieldBoolean({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.BOOLEAN);
}

class MFieldText extends MField {
  MFieldText({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.TEXT);
}

class MFieldTinyText extends MField {
  MFieldTinyText({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.TINYTEXT);
}

class MFieldMediumText extends MField {
  MFieldMediumText({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.MEDIUMTEXT);
}

class MFieldLongText extends MField {
  MFieldLongText({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.LONGTEXT);
}

class MFieldDate extends MField {
  MFieldDate({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.DATE);
}

class MFieldDateTime extends MField {
  MFieldDateTime({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.DATETIME);
}

class MFieldTimestamp extends MField {
  MFieldTimestamp({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.TIMESTAMP);
}

class MFieldBit extends MField {
  MFieldBit({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    int length = 8,
  }) : super(type: FieldTypes.BIT) {
    _options = '($length)';
  }
}

class MFieldTime extends MField {
  MFieldTime({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.TIME);
}

class MFieldYear extends MField {
  MFieldYear({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    int length = 4,
  }) : super(type: FieldTypes.YEAR) {
    _options = '($length)';
  }
}

class MFieldBinary extends MField {
  MFieldBinary({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    int length = 255,
  }) : super(type: FieldTypes.BINARY) {
    _options = '($length)';
  }
}

class MFieldVarBinary extends MField {
  MFieldVarBinary({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    int length = 255,
  }) : super(type: FieldTypes.VARBINARY) {
    _options = '($length)';
  }
}

class MFieldBlob extends MField {
  MFieldBlob({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.BLOB);
}

class MFieldMediumBlob extends MField {
  MFieldMediumBlob({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.MEDIUMBLOB);
}

class MFieldLongBlob extends MField {
  MFieldLongBlob({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.LONGBLOB);
}

class MFieldTinyBlob extends MField {
  MFieldTinyBlob({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.TINYBLOB);
}

class MFieldEnum extends MField {
  MFieldEnum({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    required List<String> values,
  }) : super(type: FieldTypes.ENUM) {
    _options = '(${values.map((v) => "'$v'").join(', ')})';
  }
}

class MFieldSet extends MField {
  MFieldSet({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    required List<String> values,
  }) : super(type: FieldTypes.SET) {
    _options = '(${values.map((v) => "'$v'").join(', ')})';
  }
}

class MFieldJson extends MField {
  MFieldJson({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
  }) : super(type: FieldTypes.JSON);
}

class MFieldPoint extends MField {
  MFieldPoint({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    int? srid,
  }) : super(type: FieldTypes.POINT) {
    if (srid != null) {
      _options = 'SRID $srid';
    }
  }
}

class MFieldPolygon extends MField {
  MFieldPolygon({
    required super.name,
    super.isPrimaryKey = false,
    super.isAutoIncrement = false,
    super.isNullable = false,
    super.defaultValue = '',
    super.comment,
    int? srid,
  }) : super(type: FieldTypes.POLYGON) {
    if (srid != null) {
      _options = 'SRID $srid';
    }
  }
}

enum FieldTypes implements SQL {
  INT('INT'),
  BIGINT('BIGINT'),
  MEDIUMINT('MEDIUMINT'),
  SMALLINT('SMALLINT'),
  TINYINT('TINYINT'),
  CHAR('CHAR'),
  VARCHAR('VARCHAR'),
  FLOAT('FLOAT'),
  DECIMAL('DECIMAL'),
  BOOLEAN('BOOLEAN'),
  TEXT('TEXT'),
  TINYTEXT('TINYTEXT'),
  MEDIUMTEXT('MEDIUMTEXT'),
  LONGTEXT('LONGTEXT'),
  DATE('DATE'),
  DATETIME('DATETIME'),
  TIMESTAMP('TIMESTAMP'),
  BIT('BIT'),
  TIME('TIME'),
  YEAR('YEAR'),
  BINARY('BINARY'),
  VARBINARY('VARBINARY'),
  BLOB('BLOB'),
  MEDIUMBLOB('MEDIUMBLOB'),
  LONGBLOB('LONGBLOB'),
  TINYBLOB('TINYBLOB'),
  ENUM('ENUM'),
  SET('SET'),
  JSON('JSON'),
  POINT('POINT'),
  POLYGON('POLYGON');

  final String sqlType;

  const FieldTypes(this.sqlType);

  @override
  String toSQL() => sqlType;
}

class ForeignKey implements SQL {
  String name;
  String refTable;
  String refColumn;
  String onDelete;
  String onUpdate;

  ForeignKey({
    required this.name,
    required this.refTable,
    this.refColumn = 'id',
    this.onDelete = 'NO ACTION',
    this.onUpdate = 'NO ACTION',
  });

  @override
  String toSQL() {
    return 'FOREIGN KEY (`$name`) REFERENCES `$refTable`(`$refColumn`) ON DELETE $onDelete ON UPDATE $onUpdate';
  }
}
