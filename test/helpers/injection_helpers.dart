import 'package:mysql_client/mysql_client.dart';
import 'package:sqler/sqler.dart';
import 'package:sqlite3/sqlite3.dart';

/// Marker contained in every secret column (password hashes, API tokens).
/// If it ever shows up in a result set that did not ask for it, data leaked.
const secretMarker = 'SECRET';

// -----------------------------------------------------------------------------
// Oracles
// -----------------------------------------------------------------------------

/// Returns true if [sql] is exactly ONE well-formed SQL string literal
/// (i.e. the value can't terminate the literal early and smuggle SQL).
bool isSingleStringLiteral(String sql, {required bool mysql}) {
  if (sql.length < 2 || !sql.startsWith("'") || !sql.endsWith("'")) {
    return false;
  }
  var i = 1;
  while (i < sql.length) {
    final c = sql[i];
    if (mysql && c == r'\') {
      i += 2; // skip escaped character
      continue;
    }
    if (c == "'") {
      if (i == sql.length - 1) return true; // closing quote
      if (sql[i + 1] == "'") {
        i += 2; // doubled quote == literal quote
        continue;
      }
      return false; // literal closed early -> injection
    }
    i++;
  }
  return false; // never closed
}

/// Removes every properly quoted identifier / literal (honouring doubled
/// quote escapes) so that only text that is *outside* quotes remains.
String stripQuoted(String sql, String quote) {
  final out = StringBuffer();
  var i = 0;
  while (i < sql.length) {
    if (sql[i] == quote) {
      i++;
      while (i < sql.length) {
        if (sql[i] == quote) {
          if (i + 1 < sql.length && sql[i + 1] == quote) {
            i += 2;
            continue;
          }
          break;
        }
        i++;
      }
      i++; // closing quote
      out.write('?');
      continue;
    }
    out.write(sql[i]);
    i++;
  }
  return out.toString();
}

/// Number of identifier quotes that are NOT part of a doubled (escaped) pair.
/// A single identifier always has exactly 2; an unescaped quote inside the
/// name makes the count odd / larger.
int unescapedQuotes(String sql, String quote) {
  return sql.replaceAll('$quote$quote', '').split(quote).length - 1;
}

// -----------------------------------------------------------------------------
// Tiny DB abstraction so the same attack suite runs on MySQL and SQLite
// -----------------------------------------------------------------------------

typedef Row = Map<String, String?>;

class Db {
  final String name;
  final bool mysql;
  final Future<List<Row>> Function(String sql) _query;
  final Future<void> Function() close;

  Db(this.name, this.mysql, this._query, this.close);

  String get q => mysql ? '`' : '"';

  String sql(SQL s) => mysql ? s.toSQL<Mysql>() : s.toSQL<Sqlite>();

  /// Runs [sql]; errors propagate (use for legitimate statements).
  Future<List<Row>> run(String sql) => _query(sql);

  /// Runs [sql]; a database error counts as "the attack did not work".
  Future<List<Row>> attack(String sql) async {
    try {
      return await _query(sql);
    } catch (_) {
      return [];
    }
  }
}

Future<Db> openMysql() async {
  final conn = await MySQLConnection.createConnection(
    host: 'localhost',
    port: 3306,
    userName: 'test',
    password: 'test',
    databaseName: 'test',
  );
  await conn.connect();
  return Db('MySQL', true, (sql) async {
    final res = await conn.execute(sql);
    return res.rows.map((r) => r.assoc()).toList();
  }, () => conn.close());
}

Db openSqlite() {
  final db = sqlite3.openInMemory();
  return Db('SQLite', false, (sql) async {
    final res = db.select(sql);
    return res.map((r) => r.map((k, v) => MapEntry(k, v?.toString()))).toList();
  }, () async => db.close());
}

bool leaks(List<Row> rows) =>
    rows.any((r) => r.values.any((v) => v?.contains(secretMarker) ?? false));

/// Structural "skeleton" of a statement: every string literal and quoted
/// identifier is replaced by `?` (honouring the dialect's escape rules), and
/// dotted identifier chains (`?.?.?`) are collapsed.
///
/// A safe builder produces the *same* skeleton no matter what the user typed
/// into a value / identifier position. If a hostile input changes the
/// skeleton, it changed the structure of the query, i.e. it is an injection.
String skeleton(String sql, {required bool mysql}) {
  final out = StringBuffer();
  var i = 0;
  while (i < sql.length) {
    final c = sql[i];
    if (c == "'" || c == '"' || c == '`') {
      i++;
      while (i < sql.length) {
        if (mysql && c != '`' && sql[i] == r'\') {
          i += 2;
          continue;
        }
        if (sql[i] == c) {
          if (i + 1 < sql.length && sql[i + 1] == c) {
            i += 2;
            continue;
          }
          break;
        }
        i++;
      }
      i++;
      out.write('?');
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString().replaceAll(RegExp(r'\?(\.\?)+'), '?');
}
