import 'package:mysql_client/mysql_client.dart';
import 'package:mysql_client/mysql_protocol.dart';
import 'package:sqler/sqler.dart';
import 'package:test/test.dart';

void main() async {
  var conn = await MySQLConnection.createConnection(
    host: 'localhost',
    port: 3306,
    userName: 'test',
    password: 'test',
    databaseName: 'test',
  );
  await conn.connect();

  Future<MySqlResult> execute(String sql) async {
    try {
      var resultSet = await conn.execute(sql);
      return MySqlResult(resultSet);
    } catch (e) {
      print('Error: $e\n----------\n$sql');
      return MySqlResult(
        EmptyResultSet(
          okPacket: MySQLPacketOK(
            header: 0,
            affectedRows: BigInt.zero,
            lastInsertID: BigInt.zero,
          ),
        ),
        errorMsg: e.toString(),
      );
    }
  }

  await conn.execute('DROP TABLE IF EXISTS books');
  await conn.execute('DROP TABLE IF EXISTS categories');
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

  await execute(books.toSQL());

  group('Test on Mysql connection', () {
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
      var result = await execute(query.toSQL());
      expect(result.affectedRows, BigInt.from(1));
      expect(result.insertId, greaterThan(BigInt.zero));
      expect(result.errorMsg, isEmpty);
    });

    test('Select all books', () async {
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([QSelectAll()]);
      var result = await execute(query.toSQL());

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
      var result = await execute(query.toSQL());

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
      var result = await execute(query.toSQL());
      expect(result.affectedRows, BigInt.from(3));
      expect(result.insertId, greaterThan(BigInt.zero));
      expect(result.errorMsg, isEmpty);
    });

    test('Test Aggregation Functions', () async {
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([
              SQL.sum(QField('publication_year', as: 'sum_publication_year')),
              SQL.avg(QField('publication_year', as: 'avg_publication_year')),
              SQL.count(
                QField('publication_year', as: 'count_books', distinct: true),
              ),
              SQL.min(QField('publication_year', as: 'min_publication_year')),
              SQL.max(QField('publication_year', as: 'max_publication_year')),
            ]);

      var result = await execute(query.toSQL());
      expect(result.rows.isNotEmpty, isTrue);
      expect(result.errorMsg, isEmpty);
      expect(result.assocFirst!['sum_publication_year'], isNotNull);
      expect(result.assocFirst!['avg_publication_year'], isNotNull);
      expect(result.assocFirst!['sum_publication_year'], '8087');
      expect(result.assocFirst!['avg_publication_year'], '2021.7500');
      expect(result.assocFirst!['count_books'], '3');
      expect(result.assocFirst!['min_publication_year'], '2020');
      expect(result.assocFirst!['max_publication_year'], '2023');
    });

    test('Test EXPLAIN', () async {
      var bookQuery =
          Sqler()
            ..from(books.qName)
            ..selects([QSelectAll()]);
      var explainQuery = SqlExplain(bookQuery);
      var result = await execute(explainQuery.toSQL());
      expect(result.assoc, isList);
      expect(result.rows.length, greaterThan(0));
      expect(result.rows.isNotEmpty, isTrue);
      expect(result.error, isFalse);
    });

    test('Test Join', () async {
      execute(categoriesTable.toSQL());

      Sqler insertQuery = Sqler().insert(categoriesTable.qName, [
        {'title': QVar('Programming')},
        {'title': QVar('Web Development')},
        {'title': QVar('Mobile Development')},
      ]);

      execute(insertQuery.toSQL());

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
            );

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
            );

      var result1 = await execute(queryBooks1.toSQL());
      var result2 = await execute(queryBooks2.toSQL());

      expect(queryBooks1.toSQL(), queryBooks2.toSQL());
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

      var result = await execute(query.toSQL());
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
      var result = await execute(query.toSQL());
      expect(result.rows.length, 4);
      expect(
        result.resultSet.cols.length,
        books.fields.length * 2 + categoriesTable.fields.length,
      );
    });
  });

  // ── Index Support ─────────────────────────────────────────────────────────

  group('Index Support — MySQL', () {
    const tblName = 'idx_mysql_test';

    MTable buildTable(List<MIndex> indexes) => MTable(
      name: tblName,
      fields: [
        MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
        MFieldVarchar(name: 'email', length: 255, isNullable: false),
        MFieldVarchar(name: 'last_name', length: 100),
        MFieldText(name: 'bio', isNullable: true),
        MFieldInt(name: 'score', isNullable: true, defaultValue: 'NULL'),
      ],
      indexes: indexes,
    );

    setUp(() async => execute('DROP TABLE IF EXISTS `$tblName`'));
    tearDown(() async => execute('DROP TABLE IF EXISTS `$tblName`'));

    // ── SQL generation ──────────────────────────────────────────────────────

    test('Indexes are emitted inline inside CREATE TABLE for MySQL', () {
      final sql =
          buildTable([
            MIndex(
              indexName: 'uq_email',
              columns: [MIndexColumn('email')],
              type: MIndexType.unique,
            ),
            MIndex(indexName: 'idx_name', columns: [MIndexColumn('last_name')]),
            MIndex(
              indexName: 'idx_bio_pfx',
              columns: [MIndexColumn('bio', prefixLength: 100)],
            ),
            MIndex(
              indexName: 'ft_bio',
              columns: [MIndexColumn('bio')],
              type: MIndexType.fulltext,
            ),
          ]).toSQL();

      expect(sql, contains('UNIQUE INDEX `uq_email` (`email`)'));
      expect(sql, contains('INDEX `idx_name` (`last_name`)'));
      expect(sql, contains('INDEX `idx_bio_pfx` (`bio`(100))'));
      expect(sql, contains('FULLTEXT INDEX `ft_bio` (`bio`)'));
      // Single statement — no separate CREATE INDEX appended
      expect(sql.trim(), isNot(startsWith('CREATE INDEX')));
      expect(';\n', isNot(isIn(sql))); // no newline-delimited second statement
    });

    test('toCreateIndexSQL generates a correct standalone MySQL statement', () {
      final sql = MIndex(
        indexName: 'uq_email',
        columns: [MIndexColumn('email')],
        type: MIndexType.unique,
      ).toCreateIndexSQL<Mysql>(tblName);
      expect(
        sql,
        equals('CREATE UNIQUE INDEX `uq_email` ON `$tblName` (`email`);'),
      );
    });

    test('USING BTREE is placed after the column list for MySQL', () {
      final sql = MIndex(
        indexName: 'idx_btree',
        columns: [MIndexColumn('email')],
        using: MIndexUsing.btree,
      ).toCreateIndexSQL<Mysql>(tblName);
      expect(sql, contains('USING BTREE'));
      expect(sql.indexOf('(`email`)'), lessThan(sql.indexOf('USING BTREE')));
    });

    test('INVISIBLE and COMMENT options are emitted for MySQL', () {
      final sql =
          MIndex(
            indexName: 'idx_opts',
            columns: [MIndexColumn('score')],
            comment: 'score lookup',
            invisible: true,
          ).toSQL<Mysql>();
      expect(sql, contains("COMMENT 'score lookup'"));
      expect(sql, contains('INVISIBLE'));
    });

    test('DESC column sort order is emitted', () {
      final sql =
          MIndex(
            indexName: 'idx_score_desc',
            columns: [MIndexColumn('score', desc: true)],
          ).toSQL<Mysql>();
      expect(sql, contains('`score` DESC'));
    });

    test('Auto-generated index names use type prefix and column name', () {
      expect(
        MIndex(columns: [MIndexColumn('slug')]).toSQL<Mysql>(),
        contains('`idx_slug`'),
      );
      expect(
        MIndex(
          columns: [MIndexColumn('slug')],
          type: MIndexType.unique,
        ).toSQL<Mysql>(),
        contains('`uq_slug`'),
      );
      expect(
        MIndex(
          columns: [MIndexColumn('slug')],
          type: MIndexType.fulltext,
        ).toSQL<Mysql>(),
        contains('`ft_slug`'),
      );
      expect(
        MIndex(
          columns: [MIndexColumn('slug')],
          type: MIndexType.spatial,
        ).toSQL<Mysql>(),
        contains('`sp_slug`'),
      );
    });

    test('Multi-column composite index lists all columns in order', () {
      final sql = MIndex(
        indexName: 'idx_composite',
        columns: [MIndexColumn('last_name'), MIndexColumn('email', desc: true)],
      ).toCreateIndexSQL<Mysql>(tblName);
      expect(sql, contains('(`last_name`, `email` DESC)'));
    });

    // ── DB execution ────────────────────────────────────────────────────────

    test('Table with mixed index types creates without error', () async {
      final r = await execute(
        buildTable([
          MIndex(
            indexName: 'uq_email',
            columns: [MIndexColumn('email')],
            type: MIndexType.unique,
          ),
          MIndex(
            indexName: 'ft_bio',
            columns: [MIndexColumn('bio')],
            type: MIndexType.fulltext,
          ),
        ]).toSQL(),
      );
      expect(r.errorMsg, isEmpty);
    });

    test('Unique index rejects duplicate values', () async {
      await execute(
        buildTable([
          MIndex(
            indexName: 'uq_email',
            columns: [MIndexColumn('email')],
            type: MIndexType.unique,
          ),
        ]).toSQL(),
      );
      final r1 = await execute(
        "INSERT INTO `$tblName` (email, last_name) VALUES ('a@test.com', 'A')",
      );
      expect(r1.errorMsg, isEmpty);
      final r2 = await execute(
        "INSERT INTO `$tblName` (email, last_name) VALUES ('a@test.com', 'B')",
      );
      expect(r2.errorMsg, isNotEmpty); // duplicate-key error
    });

    test('FULLTEXT index supports MATCH AGAINST queries', () async {
      await execute(
        buildTable([
          MIndex(
            indexName: 'ft_bio',
            columns: [MIndexColumn('bio')],
            type: MIndexType.fulltext,
          ),
        ]).toSQL(),
      );
      await execute(
        "INSERT INTO `$tblName` (email, last_name, bio) "
        "VALUES ('x@test.com', 'X', 'Dart programming language')",
      );
      final r = await execute(
        "SELECT * FROM `$tblName` WHERE MATCH(bio) AGAINST('Dart' IN BOOLEAN MODE)",
      );
      expect(r.errorMsg, isEmpty);
      expect(r.rows.length, greaterThanOrEqualTo(1));
    });

    test('Prefix index on TEXT column creates and allows queries', () async {
      await execute(
        buildTable([
          MIndex(
            indexName: 'idx_bio_pfx',
            columns: [MIndexColumn('bio', prefixLength: 50)],
          ),
        ]).toSQL(),
      );
      await execute(
        "INSERT INTO `$tblName` (email, last_name, bio) "
        "VALUES ('y@test.com', 'Y', 'Short bio text')",
      );
      final r = await execute(
        "SELECT * FROM `$tblName` WHERE bio = 'Short bio text'",
      );
      expect(r.errorMsg, isEmpty);
      expect(r.rows.length, 1);
    });

    test('addIndex() appends index and reflects in generated SQL', () async {
      final t = MTable(
        name: tblName,
        fields: [
          MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
          MFieldVarchar(name: 'email', length: 255),
        ],
      )..addIndex(
        MIndex(
          indexName: 'uq_email',
          columns: [MIndexColumn('email')],
          type: MIndexType.unique,
        ),
      );
      expect(t.indexes.length, 1);
      expect(t.toSQL(), contains('UNIQUE INDEX `uq_email`'));
      final r = await execute(t.toSQL());
      expect(r.errorMsg, isEmpty);
    });
  });
}

class MySqlResult {
  static const String _countRecordsField = 'count_records';
  final IResultSet resultSet;

  String errorMsg;
  MySqlResult(this.resultSet, {this.errorMsg = ''});

  bool get success => errorMsg.isEmpty;
  bool get error => !success;

  Iterable<ResultSetRow> get rows => resultSet.rows;
  BigInt get affectedRows => resultSet.affectedRows;
  BigInt get insertId => resultSet.lastInsertID;
  int get numFields => resultSet.numOfColumns;
  int get numRows => resultSet.numOfRows;

  List<Map<String, dynamic>> get assoc =>
      rows.map((row) => row.assoc()).toList();

  Map<String, dynamic>? get assocFirst {
    if (rows.isEmpty) {
      return null;
    }
    return rows.first.assoc();
  }

  Map<String, dynamic>? get assocLast {
    if (rows.isEmpty) {
      return null;
    }
    return rows.last.assoc();
  }

  /// This method returns the count of records from results
  /// with from this filed = `count_records`.
  int get countRecords {
    return int.tryParse((assocFirst?[_countRecordsField] ?? 0).toString()) ?? 0;
  }
}
