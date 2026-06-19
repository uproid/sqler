import 'package:sqler/sqler.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() async {
  var conn = sqlite3.open('./test_db.sqlite');

  Future<SqliteResult> execute(String sql) async {
    try {
      var resultSet = conn.select(sql);
      return SqliteResult(resultSet);
    } catch (e) {
      print('Error: $e\n----------\n$sql');
      return SqliteResult(ResultSet([], [], []), errorMsg: e.toString());
    }
  }

  conn.select('DROP TABLE IF EXISTS books');
  conn.select('DROP TABLE IF EXISTS categories');
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
  await execute(books.toSQL<Sqlite>());

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
      var result = await execute(query.toSQL<Sqlite>());
      // expect(result.affectedRows, BigInt.from(1));
      // expect(result.insertId, greaterThan(BigInt.zero));
      expect(result.errorMsg, isEmpty);
    });

    test('Select all books', () async {
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([QSelectAll()]);
      var result = await execute(query.toSQL<Sqlite>());

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
      var result = await execute(query.toSQL<Sqlite>());

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
      var result = await execute(query.toSQL<Sqlite>());
      // expect(result.affectedRows, BigInt.from(3));
      // expect(result.insertId, greaterThan(BigInt.zero));
      expect(result.errorMsg, isEmpty);
    });

    test('Test Aggregation Functions', () async {
      var query =
          Sqler()
            ..from(books.qName)
            ..selects([
              SQL.sum<Sqlite>(
                QField('publication_year', as: 'sum_publication_year'),
              ),
              SQL.avg<Sqlite>(
                QField('publication_year', as: 'avg_publication_year'),
              ),
              SQL.count<Sqlite>(
                QField('publication_year', as: 'count_books', distinct: true),
              ),
              SQL.min<Sqlite>(
                QField('publication_year', as: 'min_publication_year'),
              ),
              SQL.max<Sqlite>(
                QField('publication_year', as: 'max_publication_year'),
              ),
            ]);

      var result = await execute(query.toSQL<Sqlite>());
      expect(result.rows.isNotEmpty, isTrue);
      expect(result.errorMsg, isEmpty);
      expect(result.assocFirst!['sum_publication_year'], isNotNull);
      expect(result.assocFirst!['avg_publication_year'], isNotNull);
      expect(result.assocFirst!['sum_publication_year'], '8087');
      expect(result.assocFirst!['avg_publication_year'], '2021.75');
      expect(result.assocFirst!['count_books'], '3');
      expect(result.assocFirst!['min_publication_year'], '2020');
      expect(result.assocFirst!['max_publication_year'], '2023');
    });

    test('Test EXPLAIN', () async {
      Sqler bookQuery =
          Sqler()
            ..from(books.qName)
            ..selects([QSelectAll()])
            ..whereOne(QField('id'), QO.EQ, QVar(1));
      var explainQuery = SqlExplain(bookQuery);
      var result = await execute(explainQuery.toSQL<Sqlite>());

      expect(result.assoc, isList);
      expect(result.errorMsg, isEmpty);
    });

    test('Test Join', () async {
      execute(categoriesTable.toSQL<Sqlite>());

      Sqler insertQuery =
          Sqler()..insert(categoriesTable.qName, [
            {'title': QVar('Programming')},
            {'title': QVar('Web Development')},
            {'title': QVar('Mobile Development')},
          ]);

      execute(insertQuery.toSQL<Sqlite>());

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

      var result1 = await execute(queryBooks1.toSQL<Sqlite>());
      var result2 = await execute(queryBooks2.toSQL<Sqlite>());

      expect(queryBooks1.toSQL<Sqlite>(), queryBooks2.toSQL<Sqlite>());
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

      var result = await execute(query.toSQL<Sqlite>());
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
      var result = await execute(query.toSQL<Sqlite>());
      expect(result.rows.length, 4);
      expect(
        result.cols.length,
        books.fields.length * 2 + categoriesTable.fields.length,
      );
    });
  });

  // ── Index Support ─────────────────────────────────────────────────────────

  group('Index Support — SQLite', () {
    const tblName = 'idx_sqlite_test';

    // conn.execute() uses sqlite3_exec which handles multiple statements
    // (CREATE TABLE + appended CREATE INDEX statements).
    void createTable(MTable t) => conn.execute(t.toSQL<Sqlite>());

    setUp(() => conn.execute('DROP TABLE IF EXISTS "$tblName"'));
    tearDown(() => conn.execute('DROP TABLE IF EXISTS "$tblName"'));

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
            ).toSQL<Sqlite>();

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

    test('Partial index WHERE clause is emitted for SQLite', () {
      final sql = MIndex(
        indexName: 'idx_partial',
        columns: [MIndexColumn('email')],
        where: 'deleted_at IS NULL',
      ).toCreateIndexSQL<Sqlite>(tblName);
      expect(sql, contains('WHERE deleted_at IS NULL'));
    });

    test('DESC column sort order is emitted for SQLite', () {
      final sql = MIndex(
        indexName: 'idx_composite',
        columns: [
          MIndexColumn('last_name'),
          MIndexColumn('first_name', desc: true),
        ],
      ).toCreateIndexSQL<Sqlite>(tblName);
      expect(sql, contains('"last_name"'));
      expect(sql, contains('"first_name" DESC'));
    });

    test('Auto-generated index names use double-quoted SQLite identifiers', () {
      final sql = MIndex(
        columns: [MIndexColumn('email')],
        type: MIndexType.unique,
      ).toCreateIndexSQL<Sqlite>(tblName);
      expect(sql, contains('"uq_email"'));
      expect(sql, contains('"$tblName"'));
    });

    test('MySQL-only options are not emitted for SQLite', () {
      final sql = MIndex(
        indexName: 'idx_opts',
        columns: [MIndexColumn('bio', prefixLength: 100)],
        comment: 'bio lookup',
        invisible: true,
        concurrently: true,
      ).toCreateIndexSQL<Sqlite>(tblName);
      expect(sql, isNot(contains('COMMENT')));
      expect(sql, isNot(contains('INVISIBLE')));
      expect(sql, isNot(contains('(100)'))); // prefix length dropped for SQLite
      expect(sql, isNot(contains('CONCURRENTLY')));
    });

    test('NULLS FIRST/LAST is not emitted for SQLite', () {
      final sql = MIndex(
        indexName: 'idx_nulls',
        columns: [MIndexColumn('score', nullsFirst: true)],
      ).toCreateIndexSQL<Sqlite>(tblName);
      expect(sql, isNot(contains('NULLS')));
    });

    // ── DB execution ────────────────────────────────────────────────────────

    test('Table with multiple indexes creates without error', () {
      expect(
        () => createTable(
          MTable(
            name: tblName,
            fields: [
              MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
              MFieldVarchar(name: 'email', length: 255, isNullable: false),
              MFieldVarchar(name: 'last_name', length: 100),
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
          ),
        ),
        returnsNormally,
      );
    });

    test('Unique index rejects duplicate values in SQLite', () {
      createTable(
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
      conn.execute("INSERT INTO \"$tblName\" (email) VALUES ('a@sqlite.com')");
      expect(
        () => conn.execute(
          "INSERT INTO \"$tblName\" (email) VALUES ('a@sqlite.com')",
        ),
        throwsA(anything),
      );
    });

    test(
      'Partial index with WHERE clause creates and the table is queryable',
      () {
        createTable(
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
        conn.execute(
          "INSERT INTO \"$tblName\" (email, active) VALUES ('a@sqlite.com', 1)",
        );
        conn.execute(
          "INSERT INTO \"$tblName\" (email, active) VALUES ('b@sqlite.com', 0)",
        );
        final rows = conn.select('SELECT * FROM "$tblName"');
        expect(rows.length, 2);
      },
    );

    test('Composite index creates and allows efficient filtering', () {
      createTable(
        MTable(
          name: tblName,
          fields: [
            MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
            MFieldVarchar(name: 'last_name', length: 100),
            MFieldVarchar(name: 'first_name', length: 100),
          ],
          indexes: [
            MIndex(
              indexName: 'idx_full_name',
              columns: [MIndexColumn('last_name'), MIndexColumn('first_name')],
            ),
          ],
        ),
      );
      conn.execute(
        "INSERT INTO \"$tblName\" (last_name, first_name) VALUES ('Smith', 'John')",
      );
      conn.execute(
        "INSERT INTO \"$tblName\" (last_name, first_name) VALUES ('Doe', 'Jane')",
      );
      final rows = conn.select(
        "SELECT * FROM \"$tblName\" WHERE last_name = 'Smith'",
      );
      expect(rows.length, 1);
      expect(rows.first['first_name'], 'John');
    });

    test('addIndex() chains and reflects in toSQL<Sqlite>()', () {
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
      final sql = t.toSQL<Sqlite>();
      expect(sql, contains('CREATE UNIQUE INDEX "uq_slug"'));
      createTable(t);
      conn.execute("INSERT INTO \"$tblName\" (slug) VALUES ('hello')");
      expect(
        () => conn.execute("INSERT INTO \"$tblName\" (slug) VALUES ('hello')"),
        throwsA(anything),
      );
    });
  });
}

class SqliteResult {
  static const String _countRecordsField = 'count_records';
  final ResultSet resultSet;

  String errorMsg;
  SqliteResult(this.resultSet, {this.errorMsg = ''});

  bool get success => errorMsg.isEmpty;
  bool get error => !success;
  List<String> get cols => resultSet.columnNames;

  List<List<Object?>> get rows => resultSet.rows;
  int get numFields => cols.length;
  int get numRows => rows.length;

  List<Map<String, String?>> get assoc {
    List<Map<String, String?>> list = [];
    for (var row in rows) {
      Map<String, String?> map = {};
      for (var i = 0; i < cols.length; i++) {
        map[cols[i]] = row[i]?.toString();
      }
      list.add(map);
    }
    return list;
  }

  Map<String, String?>? get assocFirst {
    if (rows.isEmpty) {
      return null;
    }
    return assoc.first;
  }

  Map<String, String?>? get assocLast {
    if (rows.isEmpty) {
      return null;
    }
    return assoc.last;
  }

  /// This method returns the count of records from results
  /// with from this filed = `count_records`.
  int get countRecords {
    return int.tryParse((assocFirst?[_countRecordsField] ?? 0).toString()) ?? 0;
  }
}
