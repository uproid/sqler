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

  group('Test index', () {
    test('Create table with index', () async {
      var users = MTable(
        name: 'users',
        fields: [
          MFieldInt(name: 'id'),
          MFieldVarchar(name: 'name', length: 100),
          MFieldVarchar(name: 'email', length: 100),
        ],
        indexes: [
          MIndex(
            columns: [MIndexColumn('email', desc: true, nullsFirst: true)],
            indexName: 'users_email_index',
            type: MIndexType.unique,
          ),
        ],
      );

      print(users.toSQL<Postgres>());
      var res = await execute(users.toSQL<Postgres>());
      expect(res.success, true);
    });
  });
}
