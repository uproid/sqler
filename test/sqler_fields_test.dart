import 'package:sqler/sqler.dart';
import 'package:test/test.dart';

void main() {
  group('Test Fields', () {
    test('test field creation', () {
      var field1 = QField('test');
      //MySQL
      expect(field1.toSQL<Mysql>(), "`test`");
      //Sqlite
      expect(field1.toSQL<Sqlite>(), '"test"');
    });

    test('test field with special characters', () {
      var field1 = QField('test.field');
      //MySQL
      expect(field1.toSQL<Mysql>(), "test.`field`");
      //Sqlite
      expect(field1.toSQL<Sqlite>(), 'test."field"');
    });

    test('test field with special characters', () {
      var field1 = QField('test.field', as: 'test_field');
      //MySQL
      expect(field1.toSQL<Mysql>(), "test.`field` AS `test_field`");
      //Sqlite
      expect(field1.toSQL<Sqlite>(), 'test."field" AS "test_field"');
    });

    test('test all *', () {
      var field1 = QSelectAll();
      expect(field1.toSQL<Mysql>(), "*");
      expect(field1.toSQL<Sqlite>(), "*");
    });

    test('test Count', () {
      var field1 = SQL.count<Mysql>(QField('test'));
      //MySQL
      expect(field1.toSQL<Mysql>(), "COUNT(`test`)");
      //Sqlite
      field1 = SQL.count<Sqlite>(QField('test'));
      expect(field1.toSQL<Sqlite>(), "COUNT(\"test\")");

      var field2 = SQL.count<Mysql>(QField('test', as: 'test_count'));
      expect(field2.toSQL<Mysql>(), "COUNT(`test`) AS `test_count`");
      //Sqlite
      field2 = SQL.count<Sqlite>(QField('test', as: 'test_count'));
      expect(field2.toSQL<Sqlite>(), 'COUNT("test") AS "test_count"');
    });
  });
}
