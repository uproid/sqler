import 'package:sqler/sqler.dart';
import 'package:test/test.dart';

void main() {
  group('Test Params', () {
    test('test param creation', () {
      var param1 = QParam('test');
      expect(param1.toSQL(), "{test}");
    });

    test('test param with number', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field')])
            ..from(QField('table'))
            ..where(WhereOne(QField('field'), QO.EQ, QParam('123')));

      expect(
        query.toSQL(),
        "SELECT `field` FROM `table` WHERE ( `field` = {123} )",
      );

      query.addParam('123', QVar(123));
      expect(
        query.toSQL(),
        "SELECT `field` FROM `table` WHERE ( `field` = 123 )",
      );

      query.addParam('123', QVar('test'));
      expect(
        query.toSQL(),
        "SELECT `field` FROM `table` WHERE ( `field` = 'test' )",
      );
    });
  });
}
