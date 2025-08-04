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

  group('Test on Mysql connection', () {
    setUp(() async {
      await execute(
        'CREATE TABLE IF NOT EXISTS books (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), author VARCHAR(255), publication_year INT, published_date DATE, content TEXT)',
      );
    });

    tearDown(() async {
      await execute('DROP TABLE IF EXISTS books');
      await conn.close();
    });

    test('Insert a book', () async {
      var query = Sqler().insert(QField('books'), [
        {
          'name': QVar('Dart Programming'),
          'author': QVar('John Doe'),
          'publication_year': QVar(2023),
          'published_date': QVar(DateTime(2023, 1, 1)),
          'content': QVar('An introduction to Dart programming language.'),
        },
      ]);
      var result = await execute(query.toSQL());
      expect(result.affectedRows, 1);
      expect(result.insertId, greaterThan(0));
      expect(result.errorMsg, isEmpty);
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
