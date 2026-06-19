import 'package:postgres/postgres.dart';
import 'package:sqler/sqler.dart';
import 'package:test/test.dart';
import 'result/postpresql_result.dart';

void main() async {
  final conn = await Connection.open(
    Endpoint(
      host: 'localhost',
      port: 5432,
      database: 'sqler',
      username: 'postgres',
      password: 'postgres',
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  Future<PostgresResult> execute(String sql) async {
    try {
      final result = await conn.execute(sql);
      return PostgresResult(result);
    } catch (e) {
      print('Error: $e\n----------\n$sql');
      return PostgresResult(null, errorMsg: e.toString());
    }
  }

  await execute('DROP TABLE IF EXISTS books');
  await execute('DROP TABLE IF EXISTS categories');

  var books = MTable(
    name: 'books',
    fields: [
      MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
      MFieldVarchar(name: 'name', length: 255),
      MFieldVarchar(name: 'author', length: 255),
      MFieldInt(name: 'publication_year'),
      MFieldDate(name: 'published_date'),
      MFieldText(name: 'content'),
      MFieldText(name: 'password', isNullable: false),
      MFieldInt(name: 'category_id', isNullable: true, defaultValue: 'NULL'),
    ],
  );

  var categoriesTable = MTable(
    name: 'categories',
    fields: [
      MFieldInt(
        name: 'id',
        isNullable: false,
        isAutoIncrement: true,
        isPrimaryKey: true,
      ),
      MFieldText(name: 'title', isNullable: false),
    ],
  );

  await execute(books.toSQL<Postgres>());

  group('Test on PostgreSQL connection', () {
    test('Insert a book', () async {
      var query = Sqler().insert(QField('books'), [
        {
          'name': QVar('Dart Programming'),
          'author': QVar('John Doe'),
          'publication_year': QVar(2023),
          'published_date': QVar(DateTime(2023, 1, 1)),
          'content': QVar('An introduction to Dart programming language.'),
          'password': QVar.password('test'),
        },
      ]);
      var result = await execute(query.toSQL<Postgres>());
      expect(result.affectedRows, 1);
      expect(result.errorMsg, isEmpty);
    });

    test('Select all books', () async {
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([QSelectAll()]);
      var result = await execute(query.toSQL<Postgres>());

      expect(result.rows.isNotEmpty, isTrue);
      expect(result.errorMsg, isEmpty);
      expect(result.assocFirst!['name'], 'Dart Programming');
      expect(
        result.assocFirst!['password'],
        '098f6bcd4621d373cade4e832627b4f6',
      );
    });

    test('Select a book by ID', () async {
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([QSelectAll()])
            ..whereOne(QField('id'), QO.EQ, QVar(1));
      var result = await execute(query.toSQL<Postgres>());

      expect(result.rows.isNotEmpty, isTrue);
      expect(result.errorMsg, isEmpty);
      expect(result.assocFirst!['name'], 'Dart Programming');
    });

    test('Insert Many', () async {
      var query = Sqler().insert(QField('books'), [
        {
          'name': QVar('Flutter Development'),
          'author': QVar('Jane Smith'),
          'publication_year': QVar(2022),
          'published_date': QVar(DateTime(2022, 5, 15)),
          'content': QVar('A guide to Flutter development.'),
          'password': QVar.password('flutter123', type: HashType.sha256),
        },
        {
          'name': QVar('Advanced Dart'),
          'author': QVar('Alice Johnson'),
          'publication_year': QVar(2022),
          'published_date': QVar(DateTime(2021, 3, 10)),
          'content': QVar('Deep dive into Dart programming.'),
          'password': QVar.password('advanceddart', type: HashType.sha256),
        },
        {
          'name': QVar('Web Development with Dart'),
          'author': QVar('Bob Brown'),
          'publication_year': QVar(2020),
          'published_date': QVar(DateTime(2020, 7, 20)),
          'content': QVar('Building web applications using Dart.'),
          'password': QVar.password('webdart', type: HashType.sha256),
        },
      ]);
      var result = await execute(query.toSQL<Postgres>());
      expect(result.affectedRows, 3);
      expect(result.errorMsg, isEmpty);
    });

    test('Test Aggregation Functions', () async {
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([
              SQL.sum<Postgres>(
                QField('publication_year', as: 'sum_publication_year'),
              ),
              SQL.avg<Postgres>(
                QField('publication_year', as: 'avg_publication_year'),
              ),
              SQL.count<Postgres>(
                QField('publication_year', as: 'count_books', distinct: true),
              ),
              SQL.min<Postgres>(
                QField('publication_year', as: 'min_publication_year'),
              ),
              SQL.max<Postgres>(
                QField('publication_year', as: 'max_publication_year'),
              ),
            ]);

      var result = await execute(query.toSQL<Postgres>());
      expect(result.rows.isNotEmpty, isTrue);
      expect(result.errorMsg, isEmpty);
      expect(result.assocFirst!['sum_publication_year'], isNotNull);
      expect(result.assocFirst!['avg_publication_year'], isNotNull);
      expect(result.assocFirst!['sum_publication_year'], '8087');
      expect(result.assocFirst!['count_books'], '3');
      expect(result.assocFirst!['min_publication_year'], '2020');
      expect(result.assocFirst!['max_publication_year'], '2023');
    });

    test('Test EXPLAIN', () async {
      var bookQuery =
          Sqler()
            ..from(books.qName)
            ..selects([QSelectAll()])
            ..whereOne(QField('id'), QO.EQ, QVar(1));
      var explainQuery = SqlExplain(bookQuery);
      var result = await execute(explainQuery.toSQL<Postgres>());

      expect(result.assoc, isList);
      expect(result.rows.isNotEmpty, isTrue);
      expect(result.errorMsg, isEmpty);
    });

    test('Test Join', () async {
      await execute(categoriesTable.toSQL<Postgres>());

      Sqler insertQuery = Sqler().insert(categoriesTable.qName, [
        {'title': QVar('Programming')},
        {'title': QVar('Web Development')},
        {'title': QVar('Mobile Development')},
      ]);

      await execute(insertQuery.toSQL<Postgres>());

      Sqler queryBooks1 =
          Sqler()
            ..from(books.qName)
            ..selects([
              ...books.getFieldsAs('books', 'b'),
              ...categoriesTable.getFieldsAs('cat', 'c'),
            ])
            ..join(
              categoriesTable.createLeftJoin(
                On([
                  Condition(
                    QField('books.category_id'),
                    QO.EQ,
                    QField('cat.id'),
                  ),
                ]),
                as: 'cat',
              ),
            )
            ..orderBy(QOrder('books.id'));

      Sqler queryBooks2 =
          Sqler()
            ..from(books.qName)
            ..selects([
              ...books.getFieldsAs('books', 'b'),
              ...categoriesTable.getFieldsAs('cat', 'c'),
            ])
            ..join(
              categoriesTable.createLeftJoin(
                On([
                  Condition(
                    QField('books.category_id'),
                    QO.EQ,
                    QField('cat.id'),
                  ),
                ]),
                as: 'cat',
              ),
            )
            ..orderBy(QOrder('books.id'));

      var result1 = await execute(queryBooks1.toSQL<Postgres>());
      var result2 = await execute(queryBooks2.toSQL<Postgres>());

      expect(queryBooks1.toSQL<Postgres>(), queryBooks2.toSQL<Postgres>());
      expect(result1.rows.isNotEmpty, isTrue);
      expect(result1.errorMsg, isEmpty);
      expect(result1.assoc.length, 4);
      expect(result1.assocFirst!['b_name'], 'Dart Programming');
      expect(result1.assocFirst!['b_category_id'], isNull);
      expect(result1.assoc.length, result2.assoc.length);
      expect(result1.assocLast, result2.assocLast);
      expect(result1.assocFirst, result2.assocFirst);
    });

    test('Test ConditionString', () async {
      var query =
          Sqler()
            ..selects([QSelectAll()])
            ..from(books.qName)
            ..whereAnd([
              ConditionString("name = {name}"),
              ConditionString("author = {author}"),
              ConditionString("publication_year = {publication_year}"),
              ConditionString("category_id IS {category_id}"),
            ]).addParams({
              'name': QVar('Dart Programming'),
              'author': QVar('John Doe'),
              'publication_year': QVar(2023),
              'category_id': QVar(null),
            });

      var result = await execute(query.toSQL<Postgres>());
      expect(result.rows.isNotEmpty, isTrue);
      expect(result.errorMsg, isEmpty);
    });

    test('Test Nested Conditions & Joins', () async {
      Sqler allBooksQuery =
          Sqler()
            ..selects([QSelect('id')])
            ..from(QField('books'));

      Sqler query = Sqler();
      query.selects([
          ...books.getFieldsAs('books', 'b'),
          ...categoriesTable.getFieldsAs('cat', 'c'),
          ...books.getFieldsAs('bv', 'v'),
        ])
        ..from(books.qName)
        ..join(
          categoriesTable.createLeftJoin(
            On([
              Condition(QField('books.category_id'), QO.EQ, QField('cat.id')),
            ]),
            as: 'cat',
          ),
        )
        ..join(
          books.createLeftJoin(
            OnOne(QField('bv.id'), QO.GT, QVar(0)),
            as: 'bv',
          ),
        )
        ..whereAnd([
          Condition(QField('books.publication_year'), QO.GTE, QVar(2023)),
          Condition(QField('books.author'), QO.EQ, QVar('John Doe')),
          Condition(QField('books.id'), QO.IN, QVar(allBooksQuery)),
        ])
        ..orderBy(QOrder('books.id', desc: true))
        ..orderBy(QOrder('books.publication_year', desc: false))
        ..limit(10);
      var result = await execute(query.toSQL<Postgres>());
      expect(result.rows.length, 4);
      expect(
        result.cols.length,
        books.fields.length * 2 + categoriesTable.fields.length,
      );
    });

    // ── Pagination ──────────────────────────────────────────────────────────

    test('Test LIMIT and OFFSET', () async {
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id'), QSelect('name')])
            ..orderBy(QOrder('id'))
            ..limit(2, 2);

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      expect(result.rows.length, 2);
      expect(result.assocFirst!['name'], 'Advanced Dart');
      expect(result.assocLast!['name'], 'Web Development with Dart');
      expect(query.toSQL<Postgres>(), contains('LIMIT 2 OFFSET 2'));
    });

    // ── WHERE variants ───────────────────────────────────────────────────────

    test('Test WHERE OR', () async {
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id'), QSelect('publication_year')])
            ..whereOr([
              Condition(QField('publication_year'), QO.EQ, QVar(2020)),
              Condition(QField('publication_year'), QO.EQ, QVar(2023)),
            ])
            ..orderBy(QOrder('id'));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      expect(result.rows.length, 2);
      expect(result.assocFirst!['publication_year'], '2023');
      expect(result.assocLast!['publication_year'], '2020');
    });

    test('Test Mixed AND / OR', () async {
      // WHERE (year=2020) OR (year=2023) AND (author LIKE '%Doe')
      // SQL precedence: (year=2020) OR ((year=2023) AND (author LIKE '%Doe'))
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([
              QSelect('id'),
              QSelect('author'),
              QSelect('publication_year'),
            ])
            ..whereOr([
              Condition(QField('publication_year'), QO.EQ, QVar(2020)),
              Condition(QField('publication_year'), QO.EQ, QVar(2023)),
            ])
            ..whereOne(
              QField('author'),
              QO.LIKE,
              QVarLike('Doe', left: true, right: false),
            )
            ..orderBy(QOrder('id'));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      expect(result.rows.length, 2);
      expect(result.assocFirst!['author'], 'John Doe');
      expect(result.assocLast!['author'], 'Bob Brown');
    });

    test('Test WHERE IN with list', () async {
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id'), QSelect('author')])
            ..whereOne(
              QField('author'),
              QO.IN,
              QVar(['John Doe', 'Jane Smith']),
            )
            ..orderBy(QOrder('id'));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      expect(result.rows.length, 2);
      expect(result.assocFirst!['author'], 'John Doe');
      expect(result.assocLast!['author'], 'Jane Smith');
    });

    test('Test WHERE NOT IN', () async {
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id'), QSelect('author')])
            ..whereOne(
              QField('author'),
              QO.NOT_IN,
              QVar(['John Doe', 'Jane Smith']),
            )
            ..orderBy(QOrder('id'));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      expect(result.rows.length, 2);
      expect(result.assocFirst!['author'], 'Alice Johnson');
      expect(result.assocLast!['author'], 'Bob Brown');
    });

    test('Test WHERE LIKE and NOT LIKE', () async {
      // Books containing 'Dart' in the name
      var likeQuery =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id'), QSelect('name')])
            ..whereOne(QField('name'), QO.LIKE, QVarLike('Dart'))
            ..orderBy(QOrder('id'));

      var likeResult = await execute(likeQuery.toSQL<Postgres>());
      expect(likeResult.errorMsg, isEmpty);
      expect(likeResult.rows.length, 3);

      // Books NOT containing 'Dart'
      var notLikeQuery =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id'), QSelect('name')])
            ..whereOne(QField('name'), QO.NOT_LIKE, QVarLike('Dart'))
            ..orderBy(QOrder('id'));

      var notLikeResult = await execute(notLikeQuery.toSQL<Postgres>());
      expect(notLikeResult.errorMsg, isEmpty);
      expect(notLikeResult.rows.length, 1);
      expect(notLikeResult.assocFirst!['name'], 'Flutter Development');
    });

    test('Test WHERE BETWEEN and NOT BETWEEN', () async {
      // BETWEEN: years 2022..2023 → 3 books
      var betweenQuery =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id'), QSelect('publication_year')])
            ..whereOne(
              QField('publication_year'),
              QO.BETWEEN,
              QMath('2022 AND 2023'),
            )
            ..orderBy(QOrder('id'));

      var betweenResult = await execute(betweenQuery.toSQL<Postgres>());
      expect(betweenResult.errorMsg, isEmpty);
      expect(betweenResult.rows.length, 3);

      // NOT BETWEEN: years NOT in 2022..2023 → 1 book (2020)
      var notBetweenQuery =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id'), QSelect('publication_year')])
            ..whereOne(
              QField('publication_year'),
              QO.NOT_BETWEEN,
              QMath('2022 AND 2023'),
            );

      var notBetweenResult = await execute(notBetweenQuery.toSQL<Postgres>());
      expect(notBetweenResult.errorMsg, isEmpty);
      expect(notBetweenResult.rows.length, 1);
      expect(notBetweenResult.assocFirst!['publication_year'], '2020');
    });

    test('Test WHERE IS NULL and IS NOT NULL', () async {
      // IS NULL: all books have NULL category_id
      var isNullQuery =
          Sqler()
            ..from(books.qName)
            ..selects([SQL.count<Postgres>(QField('id', as: 'cnt'))])
            ..whereOne(QField('category_id'), QO.IS_NULL, QMath(''));

      var isNullResult = await execute(isNullQuery.toSQL<Postgres>());
      expect(isNullResult.errorMsg, isEmpty);
      expect(isNullResult.assocFirst!['cnt'], '4');

      // IS NOT NULL: all names are non-null
      var isNotNullQuery =
          Sqler()
            ..from(books.qName)
            ..selects([SQL.count<Postgres>(QField('id', as: 'cnt'))])
            ..whereOne(QField('name'), QO.IS_NOT_NULL, QMath(''));

      var isNotNullResult = await execute(isNotNullQuery.toSQL<Postgres>());
      expect(isNotNullResult.errorMsg, isEmpty);
      expect(isNotNullResult.assocFirst!['cnt'], '4');
    });

    test('Test WHERE comparison operators (NEQ, LT, LTE)', () async {
      // NEQ: year != 2023 → 3 rows
      var neqResult = await execute(
        (Sqler()
              ..from(books.qName)
              ..selects([QSelect('id')])
              ..whereOne(QField('publication_year'), QO.NEQ, QVar(2023)))
            .toSQL<Postgres>(),
      );
      expect(neqResult.errorMsg, isEmpty);
      expect(neqResult.rows.length, 3);

      // LT: year < 2022 → 1 row
      var ltResult = await execute(
        (Sqler()
              ..from(books.qName)
              ..selects([QSelect('id'), QSelect('publication_year')])
              ..whereOne(QField('publication_year'), QO.LT, QVar(2022)))
            .toSQL<Postgres>(),
      );
      expect(ltResult.errorMsg, isEmpty);
      expect(ltResult.rows.length, 1);
      expect(ltResult.assocFirst!['publication_year'], '2020');

      // LTE: year <= 2022 → 3 rows
      var lteResult = await execute(
        (Sqler()
              ..from(books.qName)
              ..selects([QSelect('id')])
              ..whereOne(QField('publication_year'), QO.LTE, QVar(2022)))
            .toSQL<Postgres>(),
      );
      expect(lteResult.errorMsg, isEmpty);
      expect(lteResult.rows.length, 3);
    });

    // ── GROUP BY / HAVING ────────────────────────────────────────────────────

    test('Test GROUP BY with HAVING', () async {
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([
              QSelect('publication_year'),
              SQL.count<Postgres>(QField('id', as: 'book_count')),
            ])
            ..groupBy(['publication_year'])
            ..having(Having([Condition(QMath('COUNT(*)'), QO.GTE, QVar(2))]))
            ..orderBy(QOrder('publication_year'));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      expect(result.rows.length, 1);
      expect(result.assocFirst!['publication_year'], '2022');
      expect(result.assocFirst!['book_count'], '2');
    });

    // ── CASE expression ──────────────────────────────────────────────────────

    test('Test CASE expression', () async {
      var caseField = Case.select(
        conditions: [
          CaseCondition(
            when: Condition(QField('publication_year'), QO.GTE, QVar(2022)),
            then: QVar('Recent'),
          ),
        ],
        as: QField('era'),
        elseValue: QVar('Classic'),
      );

      var query =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id'), QSelect('name'), caseField])
            ..orderBy(QOrder('id'));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      expect(result.rows.length, 4);
      expect(result.assocFirst!['era'], 'Recent');
      expect(result.assocLast!['era'], 'Classic');

      final eras = result.assoc.map((r) => r['era']).toList();
      expect(eras.where((e) => e == 'Recent').length, 3);
      expect(eras.where((e) => e == 'Classic').length, 1);
    });

    // ── SubQuery / QFromQuery ────────────────────────────────────────────────

    test('Test SubQuery in SELECT', () async {
      var totalCountSub =
          Sqler()
            ..selects([SQL.count<Postgres>(QField('id', as: 'cnt'))])
            ..from(books.qName);

      var query =
          Sqler()
            ..from(books.qName)
            ..selects([
              QSelect('id'),
              QSelect('name'),
              QSelectCustom(SubQuery(totalCountSub), as: 'total_books'),
            ])
            ..whereOne(QField('id'), QO.EQ, QVar(1));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      expect(result.rows.length, 1);
      expect(result.assocFirst!['name'], 'Dart Programming');
      expect(result.assocFirst!['total_books'], '4');
    });

    test('Test QFromQuery (subquery as FROM source)', () async {
      var innerQuery =
          Sqler()
            ..selects([
              QSelect('id'),
              QSelect('name'),
              QSelect('publication_year'),
            ])
            ..from(books.qName)
            ..whereOne(QField('publication_year'), QO.GTE, QVar(2022));

      var outerQuery =
          Sqler()
            ..selects([QSelectAll()])
            ..from(QFromQuery(innerQuery, as: 'recent_books'))
            ..orderBy(QOrder('id'));

      var result = await execute(outerQuery.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      expect(result.rows.length, 3);
      expect(outerQuery.toSQL<Postgres>(), contains('recent_books'));
    });

    // ── UNION / UNION ALL ────────────────────────────────────────────────────

    test('Test UNION and UNION ALL', () async {
      var q1 =
          Sqler()
            ..selects([QSelect('publication_year')])
            ..from(books.qName);

      var q2 =
          Sqler()
            ..selects([QSelect('publication_year')])
            ..from(books.qName);

      // UNION removes duplicates: distinct years are 2020, 2022, 2023 → 3 rows
      var union = Union([q1, q2]);
      var unionResult = await execute(union.toSQL<Postgres>());
      expect(unionResult.errorMsg, isEmpty);
      expect(unionResult.rows.length, 3);

      // UNION ALL keeps all rows: 4 + 4 = 8 rows
      var unionAll = Union([q1, q2], uniunAll: true);
      var unionAllResult = await execute(unionAll.toSQL<Postgres>());
      expect(unionAllResult.errorMsg, isEmpty);
      expect(unionAllResult.rows.length, 8);
    });

    // ── EXISTS ───────────────────────────────────────────────────────────────

    test('Test EXISTS in WHERE', () async {
      // Non-correlated: category id=1 exists → all books match
      var subExists =
          Sqler()
            ..selects([QSelect('id')])
            ..from(categoriesTable.qName)
            ..whereOne(QField('id'), QO.EQ, QVar(1));

      var existsQuery =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id')])
            ..whereOne(QMath(''), QO.EXISTS, QVar(subExists));

      var existsResult = await execute(existsQuery.toSQL<Postgres>());
      expect(existsResult.errorMsg, isEmpty);
      expect(existsResult.rows.length, 4);

      // Non-correlated: category id=999 does not exist → no books match
      var subNotExists =
          Sqler()
            ..selects([QSelect('id')])
            ..from(categoriesTable.qName)
            ..whereOne(QField('id'), QO.EQ, QVar(999));

      var notExistsQuery =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id')])
            ..whereOne(QMath(''), QO.EXISTS, QVar(subNotExists));

      var notExistsResult = await execute(notExistsQuery.toSQL<Postgres>());
      expect(notExistsResult.errorMsg, isEmpty);
      expect(notExistsResult.rows.length, 0);
    });

    // ── Query copy() ─────────────────────────────────────────────────────────

    test('Test query copy()', () async {
      var original =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id'), QSelect('name')])
            ..orderBy(QOrder('id'));

      // Copy with an additional limit
      var withLimit = original.copyWith(limit: Limit(null, 2));

      var originalResult = await execute(original.toSQL<Postgres>());
      var limitedResult = await execute(withLimit.toSQL<Postgres>());

      expect(originalResult.rows.length, 4);
      expect(limitedResult.rows.length, 2);
      expect(original.toSQL<Postgres>(), isNot(contains('LIMIT')));
      expect(withLimit.toSQL<Postgres>(), contains('LIMIT 2'));

      // Copy with a WHERE override
      var filtered = original.copyWith(
        where: [WhereOne(QField('publication_year'), QO.EQ, QVar(2023))],
      );
      var filteredResult = await execute(filtered.toSQL<Postgres>());
      expect(filteredResult.rows.length, 1);
      expect(filteredResult.assocFirst!['name'], 'Dart Programming');
    });

    // ── UPDATE ───────────────────────────────────────────────────────────────

    test('Test UPDATE', () async {
      // Set category_id on two books
      var update1 =
          Sqler()
            ..from(books.qName)
            ..updateSet('category_id', QVar(1))
            ..whereOne(QField('id'), QO.EQ, QVar(1));

      var r1 = await execute(update1.toSQL<Postgres>());
      expect(r1.affectedRows, 1);
      expect(r1.errorMsg, isEmpty);

      var update2 =
          Sqler()
            ..from(books.qName)
            ..updateSet('category_id', QVar(2))
            ..whereOne(QField('id'), QO.EQ, QVar(4));

      var r2 = await execute(update2.toSQL<Postgres>());
      expect(r2.affectedRows, 1);
      expect(r2.errorMsg, isEmpty);

      // Verify both updates took effect
      var verify =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id'), QSelect('category_id')])
            ..whereOne(QField('id'), QO.IN, QVar([1, 4]))
            ..orderBy(QOrder('id'));

      var vResult = await execute(verify.toSQL<Postgres>());
      expect(vResult.errorMsg, isEmpty);
      expect(vResult.assocFirst!['category_id'], '1');
      expect(vResult.assocLast!['category_id'], '2');
    });

    // ── INNER JOIN (after UPDATE) ────────────────────────────────────────────

    test('Test INNER JOIN', () async {
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([
              ...books.getFieldsAs('books', 'b'),
              ...categoriesTable.getFieldsAs('cat', 'c'),
            ])
            ..join(
              categoriesTable.createJoin(
                OnOne(QField('books.category_id'), QO.EQ, QField('cat.id')),
                as: 'cat',
              ),
            )
            ..orderBy(QOrder('books.id'));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      expect(result.rows.length, 2);
      expect(result.assocFirst!['b_name'], 'Dart Programming');
      expect(result.assocFirst!['c_title'], 'Programming');
      expect(result.assocLast!['b_name'], 'Web Development with Dart');
      expect(result.assocLast!['c_title'], 'Web Development');
    });

    // ── RIGHT JOIN (after UPDATE) ────────────────────────────────────────────

    test('Test RIGHT JOIN', () async {
      // books RIGHT JOIN categories → all 3 categories returned
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([
              ...books.getFieldsAs('books', 'b'),
              ...categoriesTable.getFieldsAs('cat', 'c'),
            ])
            ..join(
              categoriesTable.createRightJoin(
                OnOne(QField('books.category_id'), QO.EQ, QField('cat.id')),
                as: 'cat',
              ),
            )
            ..orderBy(QOrder('cat.id'));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      expect(result.rows.length, 3);
      // Category 3 (Mobile Development) has no matching book
      expect(result.assocLast!['c_title'], 'Mobile Development');
      expect(result.assocLast!['b_name'], isNull);
    });

    // ── DELETE ───────────────────────────────────────────────────────────────

    test('Test DELETE', () async {
      // Insert a throwaway book
      await execute(
        Sqler().insert(QField('books'), [
          {
            'name': QVar('Temp Book to Delete'),
            'author': QVar('Temp Author'),
            'publication_year': QVar(2000),
            'published_date': QVar(DateTime(2000, 1, 1)),
            'content': QVar('This book will be deleted.'),
            'password': QVar.password('temp'),
          },
        ]).toSQL<Postgres>(),
      );

      // Confirm it was inserted
      var before =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id')])
            ..whereOne(QField('name'), QO.EQ, QVar('Temp Book to Delete'));
      var beforeResult = await execute(before.toSQL<Postgres>());
      expect(beforeResult.rows.isNotEmpty, isTrue);

      // Delete it
      var deleteQuery =
          Sqler()
            ..delete()
            ..from(books.qName)
            ..whereOne(QField('name'), QO.EQ, QVar('Temp Book to Delete'));
      var deleteResult = await execute(deleteQuery.toSQL<Postgres>());
      expect(deleteResult.affectedRows, 1);
      expect(deleteResult.errorMsg, isEmpty);

      // Verify it is gone
      var after =
          Sqler()
            ..from(books.qName)
            ..selects([QSelect('id')])
            ..whereOne(QField('name'), QO.EQ, QVar('Temp Book to Delete'));
      var afterResult = await execute(after.toSQL<Postgres>());
      expect(afterResult.rows.isEmpty, isTrue);
    });
  });

  // ── Complex Multi-Table Schema ──────────────────────────────────────────────
  // Schema:
  //   publishers     ──< lib_books >── book_authors >── lib_authors
  //   (one-to-many)      (many-to-many via junction)
  //   lib_books      ──< reviews
  //   (one-to-many)

  await execute('DROP TABLE IF EXISTS reviews');
  await execute('DROP TABLE IF EXISTS book_authors');
  await execute('DROP TABLE IF EXISTS lib_books');
  await execute('DROP TABLE IF EXISTS lib_authors');
  await execute('DROP TABLE IF EXISTS publishers');

  var publishers = MTable(
    name: 'publishers',
    fields: [
      MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
      MFieldVarchar(name: 'name', length: 200, isNullable: false),
      MFieldVarchar(name: 'country', length: 100, isNullable: false),
    ],
  );

  var libAuthors = MTable(
    name: 'lib_authors',
    fields: [
      MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
      MFieldVarchar(name: 'first_name', length: 100, isNullable: false),
      MFieldVarchar(name: 'last_name', length: 100, isNullable: false),
    ],
  );

  var libBooks = MTable(
    name: 'lib_books',
    fields: [
      MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
      MFieldVarchar(name: 'title', length: 200, isNullable: false),
      MFieldInt(name: 'publisher_id', isNullable: true, defaultValue: 'NULL'),
      MFieldInt(name: 'year', isNullable: true, defaultValue: 'NULL'),
      MFieldDecimal(name: 'price', m: 10, d: 2, isNullable: true),
      MFieldBoolean(name: 'in_stock', isNullable: false),
    ],
  );

  var bookAuthors = MTable(
    name: 'book_authors',
    fields: [
      MFieldInt(name: 'book_id', isNullable: false),
      MFieldInt(name: 'author_id', isNullable: false),
    ],
  );

  var reviewsTable = MTable(
    name: 'reviews',
    fields: [
      MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
      MFieldInt(name: 'book_id', isNullable: false),
      MFieldVarchar(name: 'reviewer', length: 100, isNullable: false),
      MFieldInt(name: 'rating', isNullable: false),
    ],
  );

  await execute(publishers.toSQL<Postgres>());
  await execute(libAuthors.toSQL<Postgres>());
  await execute(libBooks.toSQL<Postgres>());
  await execute(bookAuthors.toSQL<Postgres>());
  await execute(reviewsTable.toSQL<Postgres>());

  // Publishers: 4 rows
  // id=1 OReilly/USA, id=2 Packt/UK, id=3 Manning/USA, id=4 Apress/USA
  await execute(
    Sqler().insert(publishers.qName, [
      {'name': QVar('OReilly'), 'country': QVar('USA')},
      {'name': QVar('Packt'), 'country': QVar('UK')},
      {'name': QVar('Manning'), 'country': QVar('USA')},
      {'name': QVar('Apress'), 'country': QVar('USA')},
    ]).toSQL<Postgres>(),
  );

  // Authors: 5 rows
  // id=1 John Smith, id=2 Jane Doe, id=3 Robert Chen,
  // id=4 Maria Garcia, id=5 Takeshi Nakamura
  await execute(
    Sqler().insert(libAuthors.qName, [
      {'first_name': QVar('John'), 'last_name': QVar('Smith')},
      {'first_name': QVar('Jane'), 'last_name': QVar('Doe')},
      {'first_name': QVar('Robert'), 'last_name': QVar('Chen')},
      {'first_name': QVar('Maria'), 'last_name': QVar('Garcia')},
      {'first_name': QVar('Takeshi'), 'last_name': QVar('Nakamura')},
    ]).toSQL<Postgres>(),
  );

  // Books: 8 rows
  // id=1 Dart in Depth (OReilly, 49.99, in_stock)
  // id=2 Flutter Complete Guide (Packt, 54.99, in_stock)
  // id=3 Web APIs with Dart (Manning, 39.99, in_stock)
  // id=4 Machine Learning Basics (OReilly, 59.99, in_stock)
  // id=5 Mobile App Architecture (Apress, 44.99, NOT in_stock)
  // id=6 Data Engineering (Packt, 64.99, in_stock)
  // id=7 Business Analytics (Manning, 34.99, NOT in_stock)
  // id=8 Advanced Dart Patterns (OReilly, 55.99, in_stock)
  await execute(
    Sqler().insert(libBooks.qName, [
      {
        'title': QVar('Dart in Depth'),
        'publisher_id': QVar(1),
        'year': QVar(2022),
        'price': QVar(49.99),
        'in_stock': QVar(true),
      },
      {
        'title': QVar('Flutter Complete Guide'),
        'publisher_id': QVar(2),
        'year': QVar(2023),
        'price': QVar(54.99),
        'in_stock': QVar(true),
      },
      {
        'title': QVar('Web APIs with Dart'),
        'publisher_id': QVar(3),
        'year': QVar(2021),
        'price': QVar(39.99),
        'in_stock': QVar(true),
      },
      {
        'title': QVar('Machine Learning Basics'),
        'publisher_id': QVar(1),
        'year': QVar(2022),
        'price': QVar(59.99),
        'in_stock': QVar(true),
      },
      {
        'title': QVar('Mobile App Architecture'),
        'publisher_id': QVar(4),
        'year': QVar(2023),
        'price': QVar(44.99),
        'in_stock': QVar(false),
      },
      {
        'title': QVar('Data Engineering'),
        'publisher_id': QVar(2),
        'year': QVar(2020),
        'price': QVar(64.99),
        'in_stock': QVar(true),
      },
      {
        'title': QVar('Business Analytics'),
        'publisher_id': QVar(3),
        'year': QVar(2021),
        'price': QVar(34.99),
        'in_stock': QVar(false),
      },
      {
        'title': QVar('Advanced Dart Patterns'),
        'publisher_id': QVar(1),
        'year': QVar(2023),
        'price': QVar(55.99),
        'in_stock': QVar(true),
      },
    ]).toSQL<Postgres>(),
  );

  // book_authors (many-to-many junction):
  //   book 1  → author 1 (John Smith)
  //   book 2  → authors 1,2 (John Smith + Jane Doe)       co-authored
  //   book 3  → author 3 (Robert Chen)
  //   book 4  → authors 3,4 (Robert Chen + Maria Garcia)  co-authored
  //   book 5  → author 2 (Jane Doe)
  //   book 6  → author 5 (Takeshi Nakamura)
  //   book 7  → author 5 (Takeshi Nakamura)
  //   book 8  → authors 1,3 (John Smith + Robert Chen)    co-authored
  // Author book counts: John=3, Jane=2, Robert=3, Maria=1, Takeshi=2
  await execute(
    Sqler().insert(bookAuthors.qName, [
      {'book_id': QVar(1), 'author_id': QVar(1)},
      {'book_id': QVar(2), 'author_id': QVar(1)},
      {'book_id': QVar(2), 'author_id': QVar(2)},
      {'book_id': QVar(3), 'author_id': QVar(3)},
      {'book_id': QVar(4), 'author_id': QVar(3)},
      {'book_id': QVar(4), 'author_id': QVar(4)},
      {'book_id': QVar(5), 'author_id': QVar(2)},
      {'book_id': QVar(6), 'author_id': QVar(5)},
      {'book_id': QVar(7), 'author_id': QVar(5)},
      {'book_id': QVar(8), 'author_id': QVar(1)},
      {'book_id': QVar(8), 'author_id': QVar(3)},
    ]).toSQL<Postgres>(),
  );

  // Reviews per book:
  //   book 1: Alice(5), Bob(4), Charlie(3)   avg=4.0
  //   book 2: Diana(5), Eve(5)               avg=5.0
  //   book 3: Frank(2)                        avg=2.0
  //   book 4: Grace(4), Henry(5), Iris(4)    avg=4.33
  //   book 5: Jack(3), Kim(2)                avg=2.5
  //   book 6: Lena(5)                         avg=5.0
  //   book 7: (no reviews)
  //   book 8: Mike(5), Nancy(4)              avg=4.5
  // Overall avg = 56 / 14 = 4.0
  await execute(
    Sqler().insert(reviewsTable.qName, [
      {'book_id': QVar(1), 'reviewer': QVar('Alice'), 'rating': QVar(5)},
      {'book_id': QVar(1), 'reviewer': QVar('Bob'), 'rating': QVar(4)},
      {'book_id': QVar(1), 'reviewer': QVar('Charlie'), 'rating': QVar(3)},
      {'book_id': QVar(2), 'reviewer': QVar('Diana'), 'rating': QVar(5)},
      {'book_id': QVar(2), 'reviewer': QVar('Eve'), 'rating': QVar(5)},
      {'book_id': QVar(3), 'reviewer': QVar('Frank'), 'rating': QVar(2)},
      {'book_id': QVar(4), 'reviewer': QVar('Grace'), 'rating': QVar(4)},
      {'book_id': QVar(4), 'reviewer': QVar('Henry'), 'rating': QVar(5)},
      {'book_id': QVar(4), 'reviewer': QVar('Iris'), 'rating': QVar(4)},
      {'book_id': QVar(5), 'reviewer': QVar('Jack'), 'rating': QVar(3)},
      {'book_id': QVar(5), 'reviewer': QVar('Kim'), 'rating': QVar(2)},
      {'book_id': QVar(6), 'reviewer': QVar('Lena'), 'rating': QVar(5)},
      {'book_id': QVar(8), 'reviewer': QVar('Mike'), 'rating': QVar(5)},
      {'book_id': QVar(8), 'reviewer': QVar('Nancy'), 'rating': QVar(4)},
    ]).toSQL<Postgres>(),
  );

  group('Complex Multi-Table Queries', () {
    // ── 3-WAY LEFT JOIN ────────────────────────────────────────────────────

    test('3-way LEFT JOIN with GROUP BY: review count per book', () async {
      // lib_books LEFT JOIN publishers LEFT JOIN reviews → group by book
      var query =
          Sqler()
            ..selects([
              QSelect('lib_books.id'),
              QSelect('lib_books.title'),
              QSelect('publishers.name', as: 'publisher'),
              SQL.count<Postgres>(QField('reviews.id', as: 'review_count')),
            ])
            ..from(libBooks.qName)
            ..join(
              LeftJoin(
                'publishers',
                OnOne(
                  QField('lib_books.publisher_id'),
                  QO.EQ,
                  QField('publishers.id'),
                ),
              ),
            )
            ..join(
              LeftJoin(
                'reviews',
                OnOne(QField('reviews.book_id'), QO.EQ, QField('lib_books.id')),
              ),
            )
            ..groupBy(['lib_books.id', 'lib_books.title', 'publishers.name'])
            ..orderBy(QOrder('lib_books.id'));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      // All 8 books appear — LEFT JOIN preserves books with no reviews
      expect(result.rows.length, 8);
      // Business Analytics (book 7) has 0 reviews
      final book7 = result.assoc.firstWhere(
        (r) => r['title'] == 'Business Analytics',
      );
      expect(book7['review_count'], '0');
      // Dart in Depth (book 1) has 3 reviews and publisher OReilly
      final book1 = result.assoc.firstWhere(
        (r) => r['title'] == 'Dart in Depth',
      );
      expect(book1['review_count'], '3');
      expect(book1['publisher'], 'OReilly');
    });

    // ── MANY-TO-MANY JOIN ──────────────────────────────────────────────────

    test('Many-to-many JOIN: books with all their authors', () async {
      // lib_books JOIN book_authors JOIN lib_authors
      var query =
          Sqler()
            ..selects([
              QSelect('lib_books.id', as: 'book_id'),
              QSelect('lib_books.title'),
              QSelect('lib_authors.first_name'),
              QSelect('lib_authors.last_name'),
            ])
            ..from(libBooks.qName)
            ..join(
              Join(
                'book_authors',
                OnOne(
                  QField('book_authors.book_id'),
                  QO.EQ,
                  QField('lib_books.id'),
                ),
              ),
            )
            ..join(
              Join(
                'lib_authors',
                OnOne(
                  QField('lib_authors.id'),
                  QO.EQ,
                  QField('book_authors.author_id'),
                ),
              ),
            )
            ..orderBy(QOrder('lib_books.id'))
            ..orderBy(QOrder('lib_authors.id'));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      // 11 book–author associations total
      expect(result.rows.length, 11);
      // Flutter Complete Guide (book 2) has 2 authors
      final book2Rows = result.assoc.where(
        (r) => r['title'] == 'Flutter Complete Guide',
      );
      expect(book2Rows.length, 2);
      // Advanced Dart Patterns (book 8) has 2 authors
      final book8Rows = result.assoc.where(
        (r) => r['title'] == 'Advanced Dart Patterns',
      );
      expect(book8Rows.length, 2);
      // First row: book 1 by John Smith
      expect(result.assocFirst!['book_id'], '1');
      expect(result.assocFirst!['first_name'], 'John');
    });

    // ── CORRELATED EXISTS ──────────────────────────────────────────────────

    test('Correlated EXISTS: books with at least one 5-star review', () async {
      var subExists =
          Sqler()
            ..selects([QSelect('id')])
            ..from(reviewsTable.qName)
            ..whereAnd([
              ConditionString('reviews.book_id = lib_books.id'),
              Condition(QField('reviews.rating'), QO.EQ, QVar(5)),
            ]);

      var query =
          Sqler()
            ..selects([QSelect('id'), QSelect('title')])
            ..from(libBooks.qName)
            ..whereOne(QMath(''), QO.EXISTS, QVar(subExists))
            ..orderBy(QOrder('id'));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      // Books 1,2,4,6,8 each have at least one 5-star review → 5 results
      expect(result.rows.length, 5);
    });

    // ── NOT EXISTS ─────────────────────────────────────────────────────────

    test('NOT EXISTS: books with no reviews at all', () async {
      var query =
          Sqler()
            ..selects([QSelect('id'), QSelect('title')])
            ..from(libBooks.qName)
            ..whereAnd([
              ConditionString(
                'NOT EXISTS (SELECT 1 FROM reviews WHERE reviews.book_id = lib_books.id)',
              ),
            ])
            ..orderBy(QOrder('id'));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      // Only book 7 (Business Analytics) has no reviews
      expect(result.rows.length, 1);
      expect(result.assocFirst!['title'], 'Business Analytics');
    });

    // ── SUBQUERY AS FROM SOURCE ────────────────────────────────────────────

    test('QFromQuery + JOIN: books at or above overall average rating', () async {
      // Inner query: compute per-book average rating
      var avgPerBook =
          Sqler()
            ..selects([
              QSelect('book_id'),
              SQL.avg<Postgres>(QField('rating', as: 'avg_rating')),
            ])
            ..from(reviewsTable.qName)
            ..groupBy(['book_id']);

      var query =
          Sqler()
            ..selects([QSelect('lib_books.title'), QSelect('avg_r.avg_rating')])
            ..from(QFromQuery(avgPerBook, as: 'avg_r'))
            ..join(
              Join(
                'lib_books',
                OnOne(QField('lib_books.id'), QO.EQ, QField('avg_r.book_id')),
              ),
            )
            ..whereAnd([
              // Filter: per-book avg >= overall avg (4.0)
              ConditionString(
                'avg_r.avg_rating >= (SELECT AVG(rating) FROM reviews)',
              ),
            ])
            ..orderBy(QOrder('avg_r.avg_rating', desc: true));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      // Overall avg = 4.0; qualifying books: 1(4.0), 2(5.0), 4(4.33), 6(5.0), 8(4.5)
      expect(result.rows.length, 5);
    });

    // ── GROUP BY + HAVING ACROSS JOIN ──────────────────────────────────────

    test(
      'Multi-table aggregation + HAVING: publishers with avg price > 45',
      () async {
        var query =
            Sqler()
              ..selects([
                QSelect('publishers.name', as: 'publisher'),
                SQL.count<Postgres>(QField('lib_books.id', as: 'book_count')),
                SQL.avg<Postgres>(QField('lib_books.price', as: 'avg_price')),
              ])
              ..from(publishers.qName)
              ..join(
                Join(
                  'lib_books',
                  OnOne(
                    QField('lib_books.publisher_id'),
                    QO.EQ,
                    QField('publishers.id'),
                  ),
                ),
              )
              ..groupBy(['publishers.id', 'publishers.name'])
              ..having(
                Having([
                  Condition(QMath('AVG(lib_books."price")'), QO.GT, QVar(45.0)),
                ]),
              )
              ..orderBy(QOrder('publishers.name'));

        var result = await execute(query.toSQL<Postgres>());
        expect(result.errorMsg, isEmpty);
        // OReilly avg=55.32 ✓  Packt avg=59.99 ✓
        // Manning avg=37.49 ✗  Apress avg=44.99 ✗
        expect(result.rows.length, 2);
        expect(result.assoc[0]['publisher'], 'OReilly');
        expect(result.assoc[1]['publisher'], 'Packt');
      },
    );

    // ── MANY-TO-MANY AGGREGATION ───────────────────────────────────────────

    test(
      'Authors with 2+ books via many-to-many (HAVING COUNT DISTINCT)',
      () async {
        var query =
            Sqler()
              ..selects([
                QSelect('lib_authors.id'),
                QSelect('lib_authors.first_name'),
                QSelect('lib_authors.last_name'),
                SQL.count<Postgres>(
                  QField('lib_books.id', as: 'book_count', distinct: true),
                ),
              ])
              ..from(libAuthors.qName)
              ..join(
                Join(
                  'book_authors',
                  OnOne(
                    QField('book_authors.author_id'),
                    QO.EQ,
                    QField('lib_authors.id'),
                  ),
                ),
              )
              ..join(
                Join(
                  'lib_books',
                  OnOne(
                    QField('lib_books.id'),
                    QO.EQ,
                    QField('book_authors.book_id'),
                  ),
                ),
              )
              ..groupBy([
                'lib_authors.id',
                'lib_authors.first_name',
                'lib_authors.last_name',
              ])
              ..having(
                Having([
                  Condition(
                    QMath('COUNT(DISTINCT lib_books."id")'),
                    QO.GTE,
                    QVar(2),
                  ),
                ]),
              )
              ..orderBy(QOrder('lib_authors.id'));

        var result = await execute(query.toSQL<Postgres>());
        expect(result.errorMsg, isEmpty);
        // John Smith=3 ✓, Jane Doe=2 ✓, Robert Chen=3 ✓, Takeshi Nakamura=2 ✓
        // Maria Garcia=1 ✗
        expect(result.rows.length, 4);
        expect(result.assocFirst!['first_name'], 'John');
        expect(result.assocLast!['first_name'], 'Takeshi');
      },
    );

    // ── CASE EXPRESSION + JOIN ─────────────────────────────────────────────

    test('CASE expression + JOIN: classify books into price tiers', () async {
      var priceTier = Case.select(
        conditions: [
          CaseCondition(
            when: Condition(QField('lib_books.price'), QO.LT, QVar(40.0)),
            then: QVar('Budget'),
          ),
          CaseCondition(
            when: Condition(
              QField('lib_books.price'),
              QO.BETWEEN,
              QMath('40.0 AND 55.0'),
            ),
            then: QVar('Mid-Range'),
          ),
        ],
        as: QField('price_tier'),
        elseValue: QVar('Premium'),
      );

      var query =
          Sqler()
            ..selects([
              QSelect('lib_books.title'),
              QSelect('publishers.name', as: 'publisher'),
              priceTier,
            ])
            ..from(libBooks.qName)
            ..join(
              Join(
                'publishers',
                OnOne(
                  QField('lib_books.publisher_id'),
                  QO.EQ,
                  QField('publishers.id'),
                ),
              ),
            )
            ..orderBy(QOrder('lib_books.price'));

      var result = await execute(query.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      expect(result.rows.length, 8);
      // Budget (< 40.0): books 7(34.99), 3(39.99) → 2
      expect(result.assoc.where((r) => r['price_tier'] == 'Budget').length, 2);
      // Mid-Range (40.0–55.0 inclusive): books 5(44.99), 1(49.99), 2(54.99) → 3
      expect(
        result.assoc.where((r) => r['price_tier'] == 'Mid-Range').length,
        3,
      );
      // Premium (else, price > 55.0): books 8(55.99), 4(59.99), 6(64.99) → 3
      expect(result.assoc.where((r) => r['price_tier'] == 'Premium').length, 3);
    });

    // ── MULTI-CONDITION FILTERING ──────────────────────────────────────────

    test(
      'Complex WHERE + INNER JOIN + HAVING: in-stock books in price range with 2+ reviews',
      () async {
        var query =
            Sqler()
              ..selects([
                QSelect('lib_books.title'),
                QSelect('lib_books.price'),
                QSelect('publishers.name', as: 'publisher'),
                SQL.count<Postgres>(QField('reviews.id', as: 'review_count')),
              ])
              ..from(libBooks.qName)
              ..join(
                Join(
                  'publishers',
                  OnOne(
                    QField('lib_books.publisher_id'),
                    QO.EQ,
                    QField('publishers.id'),
                  ),
                ),
              )
              ..join(
                // INNER JOIN: only books that have at least one review survive
                Join(
                  'reviews',
                  OnOne(
                    QField('reviews.book_id'),
                    QO.EQ,
                    QField('lib_books.id'),
                  ),
                ),
              )
              ..whereAnd([
                Condition(QField('lib_books.in_stock'), QO.EQ, QVar(true)),
                Condition(
                  QField('lib_books.price'),
                  QO.BETWEEN,
                  QMath('40.0 AND 65.0'),
                ),
                Condition(
                  QField('publishers.country'),
                  QO.IN,
                  QVar(['USA', 'UK']),
                ),
              ])
              ..groupBy([
                'lib_books.id',
                'lib_books.title',
                'lib_books.price',
                'publishers.name',
              ])
              ..having(
                Having([
                  Condition(QMath('COUNT(reviews."id")'), QO.GT, QVar(1)),
                ]),
              )
              ..orderBy(QOrder('lib_books.price'));

        var result = await execute(query.toSQL<Postgres>());
        expect(result.errorMsg, isEmpty);
        // in_stock + price 40–65 + USA/UK: books 1,2,4,6,8
        // HAVING COUNT > 1: books 1(3), 2(2), 4(3), 8(2) qualify; book 6(1 review) excluded
        expect(result.rows.length, 4);
      },
    );

    // ── UNION ──────────────────────────────────────────────────────────────

    test('UNION: expensive books OR highly rated books', () async {
      // Branch 1: books priced above 55
      var expensiveBooks =
          Sqler()
            ..selects([
              QSelect('lib_books.title'),
              QSelect('publishers.name', as: 'source'),
            ])
            ..from(libBooks.qName)
            ..join(
              Join(
                'publishers',
                OnOne(
                  QField('lib_books.publisher_id'),
                  QO.EQ,
                  QField('publishers.id'),
                ),
              ),
            )
            ..whereOne(QField('lib_books.price'), QO.GT, QVar(55.0));

      // Branch 2: books with avg rating >= 4.5
      var highlyRated =
          Sqler()
            ..selects([
              QSelect('lib_books.title'),
              QSelect('publishers.name', as: 'source'),
            ])
            ..from(libBooks.qName)
            ..join(
              Join(
                'publishers',
                OnOne(
                  QField('lib_books.publisher_id'),
                  QO.EQ,
                  QField('publishers.id'),
                ),
              ),
            )
            ..join(
              Join(
                'reviews',
                OnOne(QField('reviews.book_id'), QO.EQ, QField('lib_books.id')),
              ),
            )
            ..groupBy(['lib_books.id', 'lib_books.title', 'publishers.name'])
            ..having(
              Having([
                Condition(QMath('AVG(reviews."rating")'), QO.GTE, QVar(4.5)),
              ]),
            );

      var union = Union([expensiveBooks, highlyRated]);
      var result = await execute(union.toSQL<Postgres>());
      expect(result.errorMsg, isEmpty);
      // Expensive (>55): books 4,6,8 → {4,6,8}
      // Highly rated (avg>=4.5): books 2(5.0), 6(5.0), 8(4.5) → {2,6,8}
      // UNION distinct: {2,4,6,8} → 4 rows
      expect(result.rows.length, 4);
    });

    // ── 4-TABLE JOIN WITH SUBQUERY JOINS ──────────────────────────────────

    test(
      '4-table JOIN: books with publisher, author count, and review count',
      () async {
        // lib_books JOIN publishers LEFT JOIN book_authors LEFT JOIN reviews
        // COUNT(DISTINCT ...) corrects for cartesian product when both JOINs
        // expand rows (e.g. 2 authors × 2 reviews = 4 rows per book).
        var query =
            Sqler()
              ..selects([
                QSelect('lib_books.title'),
                QSelect('publishers.name', as: 'publisher'),
                SQL.count<Postgres>(
                  QField(
                    'book_authors.author_id',
                    as: 'author_count',
                    distinct: true,
                  ),
                ),
                SQL.count<Postgres>(
                  QField('reviews.id', as: 'review_count', distinct: true),
                ),
              ])
              ..from(libBooks.qName)
              ..join(
                Join(
                  'publishers',
                  OnOne(
                    QField('lib_books.publisher_id'),
                    QO.EQ,
                    QField('publishers.id'),
                  ),
                ),
              )
              ..join(
                LeftJoin(
                  'book_authors',
                  OnOne(
                    QField('book_authors.book_id'),
                    QO.EQ,
                    QField('lib_books.id'),
                  ),
                ),
              )
              ..join(
                LeftJoin(
                  'reviews',
                  OnOne(
                    QField('reviews.book_id'),
                    QO.EQ,
                    QField('lib_books.id'),
                  ),
                ),
              )
              ..groupBy(['lib_books.id', 'lib_books.title', 'publishers.name'])
              ..orderBy(QOrder('lib_books.id'));

        var result = await execute(query.toSQL<Postgres>());
        expect(result.errorMsg, isEmpty);
        expect(result.rows.length, 8);
        // Dart in Depth: 1 author, 3 reviews
        final dartBook = result.assoc.firstWhere(
          (r) => r['title'] == 'Dart in Depth',
        );
        expect(dartBook['author_count'], '1');
        expect(dartBook['review_count'], '3');
        // Flutter Complete Guide: 2 authors, 2 reviews
        final flutterBook = result.assoc.firstWhere(
          (r) => r['title'] == 'Flutter Complete Guide',
        );
        expect(flutterBook['author_count'], '2');
        expect(flutterBook['review_count'], '2');
        // Business Analytics: 1 author, 0 reviews (COUNT of NULLs = 0)
        final bizBook = result.assoc.firstWhere(
          (r) => r['title'] == 'Business Analytics',
        );
        expect(bizBook['author_count'], '1');
        expect(bizBook['review_count'], '0');
      },
    );
  });

  // ── Index Support ─────────────────────────────────────────────────────────

  group('Index Support — PostgreSQL', () {
    const tblName = 'idx_pg_test';

    // toSQL<Postgres>() on a table with indexes returns multiple newline-separated
    // statements (CREATE TABLE + CREATE INDEX ...). Execute each individually.
    Future<void> createTable(MTable t) async {
      for (final stmt in t.toSQL<Postgres>().split('\n')) {
        if (stmt.trim().isNotEmpty) await execute(stmt);
      }
    }

    setUp(() async => execute('DROP TABLE IF EXISTS "$tblName"'));
    tearDown(() async => execute('DROP TABLE IF EXISTS "$tblName"'));

    // ── SQL generation ──────────────────────────────────────────────────────

    test(
      'Indexes are emitted as separate CREATE INDEX statements, not inline',
      () {
        final sql =
            MTable(
              name: tblName,
              fields: [
                MFieldInt(
                  name: 'id',
                  isPrimaryKey: true,
                  isAutoIncrement: true,
                ),
              ],
              indexes: [
                MIndex(
                  indexName: 'uq_email',
                  columns: [MIndexColumn('email')],
                  type: MIndexType.unique,
                ),
                MIndex(
                  indexName: 'idx_last_name',
                  columns: [MIndexColumn('last_name')],
                ),
              ],
            ).toSQL<Postgres>();

        // CREATE TABLE line must not contain INDEX
        expect(sql.split('\n').first, isNot(contains('INDEX')));
        expect(
          sql,
          contains('CREATE UNIQUE INDEX "uq_email" ON "$tblName" ("email")'),
        );
        expect(
          sql,
          contains('CREATE INDEX "idx_last_name" ON "$tblName" ("last_name")'),
        );
      },
    );

    test('USING is placed before the column list for PostgreSQL', () {
      final sql = MIndex(
        indexName: 'idx_gin',
        columns: [MIndexColumn('content')],
        using: MIndexUsing.gin,
      ).toCreateIndexSQL<Postgres>(tblName);
      expect(sql, contains('USING gin'));
      expect(sql.indexOf('USING gin'), lessThan(sql.indexOf('("content")')));
    });

    test(
      'USING is placed after the column list for MySQL (cross-DB contrast)',
      () {
        final sql = MIndex(
          indexName: 'idx_btree',
          columns: [MIndexColumn('email')],
          using: MIndexUsing.btree,
        ).toCreateIndexSQL<Mysql>(tblName);
        expect(sql.indexOf('(`email`)'), lessThan(sql.indexOf('USING BTREE')));
      },
    );

    test('CONCURRENTLY is emitted for PostgreSQL only', () {
      final idx = MIndex(
        indexName: 'idx_c',
        columns: [MIndexColumn('email')],
        concurrently: true,
      );
      expect(
        idx.toCreateIndexSQL<Postgres>(tblName),
        contains('CREATE INDEX CONCURRENTLY'),
      );
      expect(
        idx.toCreateIndexSQL<Mysql>(tblName),
        isNot(contains('CONCURRENTLY')),
      );
      expect(
        idx.toCreateIndexSQL<Sqlite>(tblName),
        isNot(contains('CONCURRENTLY')),
      );
    });

    test(
      'Partial index WHERE clause is emitted for PostgreSQL and SQLite only',
      () {
        final idx = MIndex(
          indexName: 'idx_partial',
          columns: [MIndexColumn('email')],
          where: 'deleted_at IS NULL',
        );
        expect(
          idx.toCreateIndexSQL<Postgres>(tblName),
          contains('WHERE deleted_at IS NULL'),
        );
        expect(
          idx.toCreateIndexSQL<Sqlite>(tblName),
          contains('WHERE deleted_at IS NULL'),
        );
        expect(idx.toCreateIndexSQL<Mysql>(tblName), isNot(contains('WHERE')));
      },
    );

    test('NULLS FIRST / NULLS LAST are emitted for PostgreSQL only', () {
      final idx = MIndex(
        indexName: 'idx_nulls',
        columns: [MIndexColumn('score', desc: true, nullsFirst: false)],
      );
      expect(
        idx.toCreateIndexSQL<Postgres>(tblName),
        contains('"score" DESC NULLS LAST'),
      );
      expect(idx.toCreateIndexSQL<Mysql>(tblName), isNot(contains('NULLS')));
      expect(idx.toCreateIndexSQL<Sqlite>(tblName), isNot(contains('NULLS')));
    });

    test('MySQL COMMENT and INVISIBLE are not emitted for PostgreSQL', () {
      final sql = MIndex(
        indexName: 'idx_opts',
        columns: [MIndexColumn('email')],
        comment: 'lookup',
        invisible: true,
      ).toCreateIndexSQL<Postgres>(tblName);
      expect(sql, isNot(contains('COMMENT')));
      expect(sql, isNot(contains('INVISIBLE')));
    });

    test('Prefix length is ignored for PostgreSQL (MySQL-only feature)', () {
      final sql = MIndex(
        indexName: 'idx_pfx',
        columns: [MIndexColumn('bio', prefixLength: 100)],
      ).toCreateIndexSQL<Postgres>(tblName);
      expect(sql, isNot(contains('(100)')));
    });

    // ── DB execution ────────────────────────────────────────────────────────

    test(
      'Table with composite and unique indexes creates without error',
      () async {
        await createTable(
          MTable(
            name: tblName,
            fields: [
              MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
              MFieldVarchar(name: 'email', length: 255, isNullable: false),
              MFieldVarchar(name: 'last_name', length: 100),
              MFieldVarchar(name: 'first_name', length: 100),
            ],
            indexes: [
              MIndex(
                indexName: 'uq_email',
                columns: [MIndexColumn('email')],
                type: MIndexType.unique,
              ),
              MIndex(
                indexName: 'idx_full_name',
                columns: [
                  MIndexColumn('last_name'),
                  MIndexColumn('first_name'),
                ],
              ),
            ],
          ),
        );
        final r = await execute(
          "INSERT INTO \"$tblName\" (email, last_name, first_name) "
          "VALUES ('x@pg.com', 'Doe', 'John')",
        );
        expect(r.errorMsg, isEmpty);
        expect(r.affectedRows, 1);
      },
    );

    test('Unique index rejects duplicate values in PostgreSQL', () async {
      await createTable(
        MTable(
          name: tblName,
          fields: [
            MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
            MFieldVarchar(name: 'email', length: 255, isNullable: false),
          ],
          indexes: [
            MIndex(
              indexName: 'uq_email',
              columns: [MIndexColumn('email')],
              type: MIndexType.unique,
            ),
          ],
        ),
      );
      final r1 = await execute(
        "INSERT INTO \"$tblName\" (email) VALUES ('a@pg.com')",
      );
      expect(r1.errorMsg, isEmpty);
      final r2 = await execute(
        "INSERT INTO \"$tblName\" (email) VALUES ('a@pg.com')",
      );
      expect(r2.errorMsg, isNotEmpty); // unique-violation error
    });

    test(
      'Partial index with WHERE clause creates and the table is queryable',
      () async {
        await createTable(
          MTable(
            name: tblName,
            fields: [
              MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
              MFieldVarchar(name: 'email', length: 255),
              MFieldInt(name: 'active', isNullable: true, defaultValue: 'NULL'),
            ],
            indexes: [
              MIndex(
                indexName: 'idx_active_emails',
                columns: [MIndexColumn('email')],
                where: 'active = 1',
              ),
            ],
          ),
        );
        await execute(
          "INSERT INTO \"$tblName\" (email, active) VALUES ('a@pg.com', 1)",
        );
        await execute(
          "INSERT INTO \"$tblName\" (email, active) VALUES ('b@pg.com', 0)",
        );
        final r = await execute("SELECT * FROM \"$tblName\" ORDER BY id");
        expect(r.errorMsg, isEmpty);
        expect(r.rows.length, 2);
      },
    );

    test('BTREE index creates and supports equality queries', () async {
      await createTable(
        MTable(
          name: tblName,
          fields: [
            MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
            MFieldVarchar(name: 'email', length: 255),
          ],
          indexes: [
            MIndex(
              indexName: 'idx_email_btree',
              columns: [MIndexColumn('email')],
              using: MIndexUsing.btree,
            ),
          ],
        ),
      );
      await execute("INSERT INTO \"$tblName\" (email) VALUES ('btree@pg.com')");
      final r = await execute(
        "SELECT * FROM \"$tblName\" WHERE email = 'btree@pg.com'",
      );
      expect(r.errorMsg, isEmpty);
      expect(r.rows.length, 1);
    });

    test('Descending index with NULLS LAST creates successfully', () async {
      await createTable(
        MTable(
          name: tblName,
          fields: [
            MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
            MFieldInt(name: 'score', isNullable: true, defaultValue: 'NULL'),
          ],
          indexes: [
            MIndex(
              indexName: 'idx_score_desc',
              columns: [MIndexColumn('score', desc: true, nullsFirst: false)],
            ),
          ],
        ),
      );
      await execute("INSERT INTO \"$tblName\" (score) VALUES (10)");
      await execute("INSERT INTO \"$tblName\" (score) VALUES (NULL)");
      final r = await execute(
        "SELECT score FROM \"$tblName\" ORDER BY score DESC NULLS LAST",
      );
      expect(r.errorMsg, isEmpty);
      expect(r.rows.length, 2);
      expect(r.assocFirst!['score'], '10');
      expect(r.assocLast!['score'], isNull);
    });

    test(
      'addIndex() method chains and reflects in toSQL<Postgres>()',
      () async {
        final t = MTable(
          name: tblName,
          fields: [
            MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
            MFieldVarchar(name: 'slug', length: 200),
          ],
        )..addIndex(
          MIndex(
            indexName: 'uq_slug',
            columns: [MIndexColumn('slug')],
            type: MIndexType.unique,
          ),
        );
        expect(t.indexes.length, 1);
        final sql = t.toSQL<Postgres>();
        expect(sql, contains('CREATE UNIQUE INDEX "uq_slug"'));
        await createTable(t);
        // Verify constraint
        await execute("INSERT INTO \"$tblName\" (slug) VALUES ('hello')");
        final r = await execute(
          "INSERT INTO \"$tblName\" (slug) VALUES ('hello')",
        );
        expect(r.errorMsg, isNotEmpty);
      },
    );
  });
}
