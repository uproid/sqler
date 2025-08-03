import 'package:sqler/sqler.dart';
import 'package:test/test.dart';

void main() {
  group('Test Fields', () {
    test('test field creation', () {
      var field1 = QField('test');
      expect(field1.toSQL(), "`test`");
    });

    test('test field with special characters', () {
      var field1 = QField('test.field');
      expect(field1.toSQL(), "test.`field`");
    });

    test('test field with special characters', () {
      var field1 = QField('test.field', as: 'test_field');
      expect(field1.toSQL(), "test.`field` AS `test_field`");
    });

    test('test all *', () {
      var field1 = QSelectAll();
      expect(field1.toSQL(), "*");
    });

    test('test Count', () {
      var field1 = SQL.count(QField('test'));
      expect(field1.toSQL(), "COUNT(`test`)");

      var field2 = SQL.count(QField('test', as: 'test_count'));
      expect(field2.toSQL(), "COUNT(`test`) AS `test_count`");
    });
  });
}
