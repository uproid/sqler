import 'package:mysql_client/mysql_client.dart';
import 'package:mysql_client/mysql_protocol.dart';
import 'package:sqler/sqler.dart';
import 'package:test/test.dart';

main() async {
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
            ..from(QField('books'))
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
            ..from(QField('books'))
            ..selects([QSelectAll()])
            ..where(WhereOne(QField('id'), QO.EQ, QVar(1)));
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
            ..from(QField('books'))
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

  /// This method returns the count of records from results
  /// with from this filed = `count_records`.
  int get countRecords {
    return int.tryParse((assocFirst?[_countRecordsField] ?? 0).toString()) ?? 0;
  }
}
