import 'package:sqler/sqler.dart';
import 'package:test/test.dart';

void main() {
  group('Full SQL Query Test', () {
    test('test simple SQL query generation', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table.name'))
            ..where(WhereOne(QField('field1'), QO.EQ, QVar('value')));

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM table.`name` WHERE ( `field1` = 'value' )",
      );
    });

    test('test SQL with conditions AND', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table.name'))
            ..where(
              AndWhere([
                WhereOne(QField('field1'), QO.EQ, QVar('value1')),
                WhereOne(QField('field2'), QO.GT, QVar(10)),
              ]),
            );

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM table.`name` WHERE ( ( `field1` = 'value1' ) ) AND ( ( `field2` > 10 ) )",
      );
    });

    test('test SQL with conditions OR', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table.name'))
            ..where(
              OrWhere([
                WhereOne(QField('field1'), QO.EQ, QVar('value1')),
                WhereOne(QField('field2'), QO.GT, QVar(10)),
              ]),
            );

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM table.`name` WHERE ( ( `field1` = 'value1' ) ) OR ( ( `field2` > 10 ) )",
      );
    });

    test('test SQL with conditions AND OR', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table.name'))
            ..where(
              AndWhere([
                WhereOne(QField('field1'), QO.EQ, QVar('value1')),
                OrWhere([
                  WhereOne(QField('field2'), QO.GT, QVar(10)),
                  WhereOne(QField('field3'), QO.LT, QVar(5)),
                ]),
              ]),
            );

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM table.`name` "
        "WHERE ( ( `field1` = 'value1' ) ) "
        "AND "
        "( ( ( `field2` > 10 ) ) OR ( ( `field3` < 5 ) ) )",
      );
    });

    test('test SQL Conditions (A AND B) or (B AND C)', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table.name'))
            ..where(
              OrWhere([
                AndWhere([
                  WhereOne(QField('field1'), QO.EQ, QVar('value1')),
                  WhereOne(QField('field2'), QO.GT, QVar(10)),
                ]),
                AndWhere([
                  WhereOne(QField('field2'), QO.LT, QVar(5)),
                  WhereOne(QField('field3'), QO.EQ, QVar('value3')),
                ]),
              ]),
            );

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM table.`name` "
        "WHERE ( ( ( `field1` = 'value1' ) ) AND ( ( `field2` > 10 ) ) ) "
        "OR ( ( ( `field2` < 5 ) ) AND ( ( `field3` = 'value3' ) ) )",
      );
    });

    test('test SQL with JOIN', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table1'))
            ..join(
              Join(
                'table2',
                On([
                  Condition(
                    QField('table1.field1'),
                    QO.EQ,
                    QField('table2.field1'),
                  ),
                ]),
              ),
            )
            ..where(WhereOne(QField('table1.field2'), QO.GT, QVar(100)));

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM `table1` "
        "JOIN `table2` ON ( ( table1.`field1` = table2.`field1` ) ) "
        "WHERE ( table1.`field2` > 100 )",
      );
    });

    test('test SQL with LEFT JOIN', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table1'))
            ..join(
              LeftJoin(
                'table2',
                On([
                  Condition(
                    QField('table1.field1'),
                    QO.EQ,
                    QField('table2.field1'),
                  ),
                ]),
              ),
            )
            ..where(WhereOne(QField('table1.field2'), QO.GT, QVar(100)));

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM `table1` "
        "LEFT JOIN `table2` ON ( ( table1.`field1` = table2.`field1` ) ) "
        "WHERE ( table1.`field2` > 100 )",
      );
    });

    test('test SQL with RIGHT JOIN', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table1'))
            ..join(
              RightJoin(
                'table2',
                On([
                  Condition(
                    QField('table1.field1'),
                    QO.EQ,
                    QField('table2.field1'),
                  ),
                ]),
              ),
            )
            ..where(WhereOne(QField('table1.field2'), QO.GT, QVar(100)));

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM `table1` "
        "RIGHT JOIN `table2` ON ( ( table1.`field1` = table2.`field1` ) ) "
        "WHERE ( table1.`field2` > 100 )",
      );
    });

    test('test SQL with ORDER BY', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table.name'))
            ..orderBy(QOrder('field1', desc: true))
            ..orderBy(QOrder('field2'));

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM table.`name` "
        "ORDER BY `field1` DESC, `field2` ASC",
      );
    });

    test('test SQL with LIMIT', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table.name'))
            ..limit(10);

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM table.`name` LIMIT 10",
      );
    });

    test('test SQL with LIMIT and OFFSET', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table.name'))
            ..limit(10, 5);

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM table.`name` LIMIT 10 OFFSET 5",
      );
    });

    test('test SQL with GROUP BY', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table.name'))
            ..limit(10, 5)
            ..groupBy(['field1', 'field2']);

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM table.`name` GROUP BY `field1`, `field2` LIMIT 10 OFFSET 5",
      );
    });

    test('test SQL with INSERT', () {
      Sqler query =
          Sqler()..insert(QField('table.name'), [
            {'field1': QVar('value1'), 'field2': QVar(100)},
            {'field1': QVar('value2'), 'field2': QVar(200)},
          ]);

      expect(
        query.toSQL(),
        "INSERT INTO table.`name` (`field1`, `field2`) VALUES ('value1', 100), ('value2', 200)",
      );
    });

    test('test SQL with UPDATE', () {
      Sqler query =
          Sqler()
            ..update(QField('table.name'))
            ..updateSet('field1', QVar('new_value1'))
            ..updateSet('field2', QVar(200));

      expect(
        query.toSQL(),
        "UPDATE table.`name` SET `field1` = 'new_value1', `field2` = 200",
      );
    });

    test('test SQL with DELETE', () {
      Sqler query =
          Sqler()
            ..delete()
            ..from(QField('table.name'))
            ..where(WhereOne(QField('field1'), QO.EQ, QVar('value1')));

      expect(
        query.toSQL(),
        "DELETE FROM table.`name` WHERE ( `field1` = 'value1' )",
      );
    });

    test('test SQL with complex query', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table1'))
            ..join(
              Join(
                'table2',
                On([
                  Condition(
                    QField('table1.field1'),
                    QO.EQ,
                    QField('table2.field1'),
                  ),
                ]),
              ),
            )
            ..where(
              AndWhere([
                WhereOne(QField('table1.field2'), QO.GT, QVar(100)),
                OrWhere([
                  WhereOne(QField('table2.field3'), QO.LT, QVar(50)),
                  WhereOne(QField('table2.field4'), QO.EQ, QVar('value')),
                ]),
              ]),
            )
            ..orderBy(QOrder('field1', desc: true))
            ..limit(10);

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM `table1` "
        "JOIN `table2` ON ( ( table1.`field1` = table2.`field1` ) ) "
        "WHERE ( ( table1.`field2` > 100 ) ) "
        "AND ( ( ( table2.`field3` < 50 ) ) OR ( ( table2.`field4` = 'value' ) ) ) "
        "ORDER BY `field1` DESC LIMIT 10",
      );
    });

    test('a full complex of all SQL features', () {
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('table1'))
            ..join(
              Join(
                'table2',
                On([
                  Condition(
                    QField('table1.field1'),
                    QO.EQ,
                    QField('table2.field1'),
                  ),
                ]),
              ),
            )
            ..where(
              AndWhere([
                WhereOne(QField('table1.field2'), QO.GT, QVar(100)),
                OrWhere([
                  WhereOne(QField('table2.field3'), QO.LT, QVar(50)),
                  WhereOne(QField('table2.field4'), QO.EQ, QVar('value')),
                ]),
              ]),
            )
            ..orderBy(QOrder('field1', desc: true))
            ..limit(10)
            ..groupBy(['field1', 'field2']);

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM `table1` "
        "JOIN `table2` ON ( ( table1.`field1` = table2.`field1` ) ) "
        "WHERE ( ( table1.`field2` > 100 ) ) "
        "AND ( ( ( table2.`field3` < 50 ) ) OR ( ( table2.`field4` = 'value' ) ) ) "
        "GROUP BY `field1`, `field2` "
        "ORDER BY `field1` DESC "
        "LIMIT 10",
      );
    });

    test('test CASE WHEN', () {
      Sqler query =
          Sqler()
            ..selects([
              QSelect('field1'),
              QSelect('field2'),
              Case(
                conditions: [
                  CaseCondition(
                    then: QVar('High'),
                    when: Condition(QField('field2'), QO.GT, QVar(100)),
                  ),
                ],
                elseValue: QVar('Low'),
                as: QField('field2_status'),
              ),
            ])
            ..from(QField('table1'))
            ..where(WhereOne(QField('field1'), QO.EQ, QVar('value1')))
            ..groupBy(['field1', 'field2'])
            ..orderBy(QOrder('field1', desc: true))
            ..limit(10);

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2`, "
        "CASE WHEN ( `field2` > 100 ) THEN 'High' ELSE 'Low' END AS `field2_status` "
        "FROM `table1` "
        "WHERE ( `field1` = 'value1' ) "
        "GROUP BY `field1`, `field2` "
        "ORDER BY `field1` DESC "
        "LIMIT 10",
      );
    });

    test('test SQL with subquery', () {
      Sqler subQuery =
          Sqler()
            ..selects([QSelect('field1')])
            ..from(QField('sub_table'))
            ..where(WhereOne(QField('field2'), QO.EQ, QVar('sub_value')));

      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QField('main_table'))
            ..where(WhereOne(QField('field3'), QO.IN, SubQuery(subQuery)));

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM `main_table` "
        "WHERE ( `field3` IN (SELECT `field1` FROM `sub_table` WHERE ( `field2` = 'sub_value' )) )",
      );
    });

    test('test SQL with UNION', () {
      Sqler query1 =
          Sqler()
            ..selects([QSelect('field1')])
            ..from(QField('table1'))
            ..where(WhereOne(QField('field2'), QO.EQ, QVar('value1')));

      Sqler query2 =
          Sqler()
            ..selects([QSelect('field1')])
            ..from(QField('table2'))
            ..where(WhereOne(QField('field3'), QO.EQ, QVar('value2')));

      Union unionQuery = Union([query1, query2])
        ..addOrderBy(QOrder('field1', desc: true));

      expect(
        unionQuery.toSQL(),
        "SELECT `field1` FROM `table1` WHERE ( `field2` = 'value1' ) "
        "UNION "
        "SELECT `field1` FROM `table2` WHERE ( `field3` = 'value2' )"
        " ORDER BY `field1` DESC",
      );
    });

    test('test SQL with UNION ALL', () {
      Sqler query1 =
          Sqler()
            ..selects([QSelect('field1')])
            ..from(QField('table1'))
            ..where(WhereOne(QField('field2'), QO.EQ, QVar('value1')));

      Sqler query2 =
          Sqler()
            ..selects([QSelect('field1')])
            ..from(QField('table2'))
            ..where(WhereOne(QField('field3'), QO.EQ, QVar('value2')));

      Union unionQuery = Union([query1, query2], uniunAll: true)
        ..addOrderBy(QOrder('field1', desc: false));
      expect(
        unionQuery.toSQL(),
        "SELECT `field1` FROM `table1` WHERE ( `field2` = 'value1' ) "
        "UNION ALL "
        "SELECT `field1` FROM `table2` WHERE ( `field3` = 'value2' )"
        " ORDER BY `field1` ASC",
      );
    });

    test('test SQL from subquery', () {
      Sqler subQuery =
          Sqler()
            ..selects([QSelect('field1')])
            ..from(QField('sub_table'))
            ..where(WhereOne(QField('field2'), QO.EQ, QVar('sub_value')));
      Sqler query =
          Sqler()
            ..selects([QSelect('field1'), QSelect('field2')])
            ..from(QFromQuery(subQuery, as: 'sub_query'))
            ..where(WhereOne(QField('field3'), QO.EQ, QVar('value3')));

      expect(
        query.toSQL(),
        "SELECT `field1`, `field2` FROM "
        "(SELECT `field1` FROM `sub_table` WHERE ( `field2` = 'sub_value' )) AS `sub_query` "
        "WHERE ( `field3` = 'value3' )",
      );
    });
  });
}
