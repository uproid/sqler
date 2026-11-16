// SQL-injection security tests for Sqler.
//
// Every test in this file feeds *attacker-controlled* strings through the
// public API (QVar, QVarLike, QField, QSelect, QOrder, Sqler.updateSet, ...)
// and asserts that the generated SQL is inert:
//
//  * a hostile value must stay a single string literal,
//  * a hostile identifier must stay a single quoted identifier,
//  * a hostile value must never change the meaning of the query.
//
// The "live" groups run the generated SQL against a real MySQL server
// (`make mysql-start`) and an in-memory SQLite database and check that no
// data leaks / is modified. The "generation" groups need no database.
//
// Each test uses its own tables (`inj_*`) so it can run in parallel with the
// other test files that share the `test` database.
import 'package:sqler/sqler.dart';
import 'package:test/test.dart';

import 'helpers/injection_helpers.dart';

/// Marker stored in the `admin` row. If it ever shows up in a result set that
/// was not supposed to select the admin row, data has been leaked.
const adminSecret = 'TOP-SECRET-ADMIN-TOKEN';

/// Values an attacker might submit where a *value* is expected.
const valueBreakouts = <String>[
  // Classic tautologies (neutralised by quote escaping).
  "' OR '1'='1",
  "' OR 1=1 -- ",
  // Backslash breakouts (MySQL treats `\` as an escape character, so
  // `\'` -> `\\'` closes the literal early unless the backslash is escaped).
  r"\' OR 1=1 -- ",
  // The builder wraps conditions in parentheses, so a working payload has to
  // close them first - an attacker simply tries a few variants.
  r"\') OR 1=1 -- ",
  r"\')) OR 1=1 -- ",
  r"\') UNION SELECT id, secret, secret, secret, secret FROM inj_users -- ",
  r"\\' OR 1=1 -- ",
  r"\",
  "\\\\",
];

/// Strings that are perfectly legitimate data and must survive a round trip
/// through INSERT + SELECT unchanged.
const legitimateStrings = <String>[
  "O'Brien",
  'He said "hi"',
  r'C:\temp\new',
  r'back\\slash',
  r'trailing\',
  r"\'",
  r'\n is not a newline',
  r'\0 is not a NUL',
  '100% _sure_',
  'multi\nline',
  'unicode: ß 漢字 😀',
];

/// (Re)creates and seeds the small `inj_*` schema used by this file.
Future<void> resetInj(Db db) async {
  final run = db.run;
  final mysql = db.mysql;
  await run('DROP TABLE IF EXISTS inj_users');
  await run('DROP TABLE IF EXISTS inj_notes');
  if (mysql) {
    await run(
      'CREATE TABLE inj_users (id INT PRIMARY KEY AUTO_INCREMENT, '
      'name VARCHAR(255), bio TEXT, role VARCHAR(50), secret VARCHAR(255))',
    );
    await run(
      'CREATE TABLE inj_notes (id INT PRIMARY KEY AUTO_INCREMENT, '
      'author TEXT, body TEXT)',
    );
  } else {
    await run(
      'CREATE TABLE inj_users (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT, bio TEXT, role TEXT, secret TEXT)',
    );
    await run(
      'CREATE TABLE inj_notes (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'author TEXT, body TEXT)',
    );
  }
  await run(
    "INSERT INTO inj_users (name, bio, role, secret) VALUES "
    "('alice', 'hi', 'user', 'alice-secret'), "
    "('bob', 'yo', 'user', 'bob-secret'), "
    "('admin', 'root', 'admin', '$adminSecret')",
  );
}

// -----------------------------------------------------------------------------
// Tests
// -----------------------------------------------------------------------------

void main() {
  // ---------------------------------------------------------------------------
  // 1. Pure SQL-generation tests (no database needed)
  // ---------------------------------------------------------------------------
  group('Generation: string values must stay a single literal', () {
    for (final payload in [...valueBreakouts, ...legitimateStrings]) {
      test('QVar MySQL: ${payload.replaceAll('\n', r'\n')}', () {
        final sql = QVar(payload).toSQL<Mysql>();
        expect(
          isSingleStringLiteral(sql, mysql: true),
          isTrue,
          reason: 'literal closed early: $sql',
        );
      });

      test('QVar SQLite: ${payload.replaceAll('\n', r'\n')}', () {
        final sql = QVar(payload).toSQL<Sqlite>();
        expect(
          isSingleStringLiteral(sql, mysql: false),
          isTrue,
          reason: 'literal closed early: $sql',
        );
      });
    }

    test('QVar inside a list (IN (...)) is escaped too', () {
      final sql = QVar([r"\' OR 1=1 -- ", 'ok']).toSQL<Mysql>();
      // Split the "(a, b)" list into its two literals.
      final first = sql.substring(1, sql.lastIndexOf(", '"));
      expect(isSingleStringLiteral(first, mysql: true), isTrue, reason: sql);
    });

    test('QVarLike MySQL keeps the pattern inside one literal', () {
      for (final payload in valueBreakouts) {
        final sql = QVarLike(payload).toSQL<Mysql>();
        // strip the leading/trailing wildcard so we can inspect the literal
        expect(
          isSingleStringLiteral(sql, mysql: true),
          isTrue,
          reason: 'LIKE literal closed early: $sql',
        );
      }
    });

    test('QVarLike SQLite must use SQLite escaping (not MySQL escaping)', () {
      // MySQL style `\'` does not escape anything in SQLite.
      // SQLite also needs the ESCAPE suffix that makes backslash-% literal.
      final full = QVarLike("O'Brien").toSQL<Sqlite>();
      const suffix = r" ESCAPE '\'";
      final sql = full.replaceFirst(suffix, '');
      expect(full, endsWith(suffix));
      expect(
        isSingleStringLiteral(sql, mysql: false),
        isTrue,
        reason: 'QVarLike ignores the SQLite dialect: $sql',
      );
    });

    test('QVar with a Map (JSON type confusion) must not emit raw text', () {
      // e.g. a JSON body {"name": {"x": "' OR 1=1 -- "}} reaching QVar.
      const evil = "' OR 1=1 -- ";
      String? sql;
      try {
        sql = QVar({'x': evil}).toSQL<Mysql>();
      } catch (_) {
        return; // rejecting unsupported types is a valid, safe behaviour
      }
      expect(
        isSingleStringLiteral(sql, mysql: true),
        isTrue,
        reason: 'arbitrary object was toString()-ed into the SQL: $sql',
      );
    });

    test('QVar with a custom object must not emit raw toString()', () {
      String? sql;
      try {
        sql = QVar(_Evil()).toSQL<Mysql>();
      } catch (_) {
        return;
      }
      expect(
        isSingleStringLiteral(sql, mysql: true),
        isTrue,
        reason: 'arbitrary object was toString()-ed into the SQL: $sql',
      );
    });
  });

  group('Generation: identifiers must stay a single quoted identifier', () {
    test('QField backtick in name is escaped (MySQL)', () {
      final sql = QField('a`b').toSQL<Mysql>();
      expect(unescapedQuotes(sql, '`'), 2, reason: sql);
    });

    test('QField double quote in name is escaped (SQLite)', () {
      final sql = QField('a"b').toSQL<Sqlite>();
      expect(unescapedQuotes(sql, '"'), 2, reason: sql);
    });

    test('QField alias with backtick is escaped', () {
      final sql = QField('a', as: 'x` , (SELECT 1) AS `y').toSQL<Mysql>();
      expect(stripQuoted(sql, '`'), isNot(contains('SELECT')), reason: sql);
    });

    test('QField table prefix (before the dot) is not emitted raw', () {
      final sql = QField('x; DROP TABLE inj_users -- .col').toSQL<Mysql>();
      final outside = stripQuoted(sql, '`');
      expect(outside, isNot(contains('DROP')), reason: sql);
      expect(outside, isNot(contains(';')), reason: sql);
    });

    test('QSelect column / alias are escaped', () {
      final sql = QSelect('name` , `secret', as: 'x` , `role').toSQL<Mysql>();
      expect(stripQuoted(sql, '`'), isNot(contains(',')), reason: sql);
    });

    test('QOrder column is escaped', () {
      final sql = QOrder('id` , (SELECT 1) -- ', desc: true).toSQL<Mysql>();
      expect(stripQuoted(sql, '`'), isNot(contains('SELECT')), reason: sql);
    });

    test('groupBy column is escaped', () {
      final sql =
          Sqler().addSelect(QSelectAll()).from(QField('t')).groupBy([
            'id` , (SELECT 1) -- ',
          ]).toSQL<Mysql>();
      expect(stripQuoted(sql, '`'), isNot(contains('SELECT 1')), reason: sql);
    });

    test('Join table and alias are escaped', () {
      final sql =
          Join(
            'users` JOIN secrets ON 1=1 -- ',
            On(),
            as: 'u` JOIN x -- ',
          ).toSQL<Mysql>();
      final outside = stripQuoted(sql, '`');
      expect(outside, isNot(contains('secrets')), reason: sql);
      expect(outside, isNot(contains('JOIN x')), reason: sql);
    });

    test('QFromQuery alias is escaped', () {
      final sql =
          QFromQuery(
            Sqler().addSelect(QSelectAll()).from(QField('t')),
            as: 'a` UNION SELECT 1 -- ',
          ).toSQL<Mysql>();
      expect(
        stripQuoted(sql, '`').split(' AS ').last,
        isNot(contains('UNION')),
      );
    });

    test('INSERT column names (map keys from user JSON) are escaped', () {
      final sql =
          Sqler().insert(QField('t'), [
            {'a` , `role': QVar('admin')},
          ]).toSQL<Mysql>();
      expect(stripQuoted(sql, '`'), isNot(contains(', ?')), reason: sql);
      expect(unescapedQuotes(sql, '`') % 2, 0, reason: sql);
    });

    test('UPDATE column names are escaped', () {
      final sql =
          Sqler()
              .update(QField('t'))
              .updateSet("bio` = 'x', `role", QVar('admin'))
              .toSQL<Mysql>();
      expect(unescapedQuotes(sql, '`') % 2, 0, reason: sql);
      expect(stripQuoted(sql, '`'), isNot(contains(', ?')), reason: sql);
    });
  });

  group('Generation: boolean structure', () {
    test(
      'OrWhere next to other conditions keeps the other filters binding',
      () {
        // A tenant / owner filter must apply to BOTH sides of the OR.
        final sql =
            Sqler()
                .addSelect(QSelectAll())
                .from(QField('t'))
                .whereOne(QField('tenant_id'), QO.EQ, QVar(1))
                .where(
                  OrWhere([
                    Condition(QField('a'), QO.EQ, QVar(1)),
                    Condition(QField('b'), QO.EQ, QVar(2)),
                  ]),
                )
                .toSQL<Mysql>();
        expect(
          sql,
          contains('AND ( ( ( `a` = 1 ) ) OR ( ( `b` = 2 ) ) )'),
          reason: sql,
        );
      },
    );
  });

  group('Generation: {param} placeholders', () {
    test('user data containing {key} is NOT replaced by a bound param', () {
      final sql =
          Sqler()
              .addSelect(QSelectAll())
              .from(QField('inj_users'))
              .whereOne(QField('name'), QO.EQ, QVar('{role}'))
              .whereOne(QField('role'), QO.EQ, QParam('role'))
              .addParam('role', QVar('admin'))
              .toSQL<Mysql>();
      expect(
        sql,
        contains("'{role}'"),
        reason: 'user supplied "{role}" was expanded to a server param: $sql',
      );
    });

    test('a bound param value containing {other} is not re-expanded', () {
      final sql =
          Sqler()
              .addSelect(QSelectAll())
              .from(QField('t'))
              .whereOne(QField('a'), QO.EQ, QParam('p1'))
              .whereOne(QField('b'), QO.EQ, QParam('p2'))
              .addParam('p1', QVar('{p2}'))
              .addParam('p2', QVar('SERVER-VALUE'))
              .toSQL<Mysql>();
      expect(
        sql,
        isNot(contains('SERVER-VALUE\'\'')),
        reason: 'param values are expanded recursively: $sql',
      );
      expect(sql, contains("'{p2}'"), reason: sql);
    });

    test('a param value can not break out of a literal via a placeholder', () {
      // p holds a (correctly escaped) hostile string; a *second* user value
      // that merely contains "{p}" must not drag it into a different context.
      final sql =
          Sqler()
              .addSelect(QSelectAll())
              .from(QField('t'))
              .whereOne(QField('a'), QO.EQ, QVar("x{p}"))
              .addParam('p', QVar("' OR 1=1 -- "))
              .toSQL<Sqlite>();
      expect(sql, contains("'x{p}'"), reason: sql);
    });
  });

  group('Generation: DDL (MTable / MField)', () {
    test('field default value is escaped', () {
      const payload = "x' COMMENT 'y";
      final sql =
          MFieldVarchar(
            name: 'a',
            length: 10,
            defaultValue: payload,
          ).toSQL<Mysql>();
      expect(sql, isNot(contains(payload)), reason: sql);
    });

    test('field comment is escaped', () {
      const payload = "x' , b INT -- ";
      final sql =
          MFieldVarchar(name: 'a', length: 10, comment: payload).toSQL<Mysql>();
      expect(sql, isNot(contains(payload)), reason: sql);
    });

    test('enum values are escaped', () {
      const payload = "a'), ('b";
      final sql = MFieldEnum(name: 'e', values: [payload, 'ok']).toSQL<Mysql>();
      expect(sql, isNot(contains(payload)), reason: sql);
    });

    test('foreign key identifiers are escaped', () {
      final sql =
          ForeignKey(
            name: 'a` ) -- ',
            refTable: 't` -- ',
            refColumn: 'id` -- ',
          ).toSQL<Mysql>();
      expect(unescapedQuotes(sql, '`'), 6, reason: sql);
    });

    test('table name is escaped', () {
      final sql =
          MTable(
            name: 'x` ( id INT ); DROP TABLE inj_users; -- ',
            fields: [MFieldInt(name: 'id')],
          ).toSQL<Mysql>();
      expect(stripQuoted(sql, '`'), isNot(contains('DROP')), reason: sql);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Live tests: the generated SQL is executed on a real database
  // ---------------------------------------------------------------------------
  void liveSuite(String title, Future<Db> Function() open) {
    group('Live $title', () {
      late Db db;

      setUpAll(() async => db = await open());
      tearDownAll(() async => await db.close());
      setUp(() async => await resetInj(db));

      Sqler selectUsers() =>
          Sqler().addSelect(QSelectAll()).from(QField('inj_users'));

      for (final s in legitimateStrings) {
        test(
          'round trip keeps value intact: ${s.replaceAll('\n', r'\n')}',
          () async {
            final insert = db.sql(
              Sqler().insert(QField('inj_notes'), [
                {'author': QVar('me'), 'body': QVar(s)},
              ]),
            );
            await db.run(insert);

            final rows = await db.run(
              db.sql(
                Sqler()
                    .addSelect(QSelect('body'))
                    .from(QField('inj_notes'))
                    .whereOne(QField('author'), QO.EQ, QVar('me')),
              ),
            );
            expect(rows.length, 1, reason: insert);
            expect(rows.first['body'], s, reason: 'corrupted value: $insert');

            // ... and it can be found again with an equality filter
            final found = await db.run(
              db.sql(
                Sqler()
                    .addSelect(QSelect('id'))
                    .from(QField('inj_notes'))
                    .whereOne(QField('body'), QO.EQ, QVar(s)),
              ),
            );
            expect(found.length, 1, reason: 'cannot search for: $s');
          },
        );
      }

      group('WHERE value', () {
        for (final payload in valueBreakouts) {
          test('SELECT is not injectable: $payload', () async {
            final sql = db.sql(
              selectUsers().whereOne(QField('name'), QO.EQ, QVar(payload)),
            );
            final rows = await db.attack(sql);
            expect(rows, isEmpty, reason: 'injection succeeded: $sql');
            expect(leaks(rows), isFalse, reason: sql);
          });

          test('UPDATE only touches intended rows: $payload', () async {
            final sql = db.sql(
              Sqler()
                  .update(QField('inj_users'))
                  .updateSet('bio', QVar('PWNED'))
                  .whereOne(QField('name'), QO.EQ, QVar(payload)),
            );
            await db.attack(sql);
            final hit = await db.run(
              "SELECT COUNT(*) AS c FROM inj_users WHERE bio = 'PWNED'",
            );
            expect(hit.first['c'], '0', reason: 'mass update: $sql');
          });

          test('DELETE only touches intended rows: $payload', () async {
            final sql = db.sql(
              Sqler()
                  .delete()
                  .from(QField('inj_users'))
                  .whereOne(QField('name'), QO.EQ, QVar(payload)),
            );
            await db.attack(sql);
            final left = await db.run('SELECT COUNT(*) AS c FROM inj_users');
            expect(left.first['c'], '3', reason: 'mass delete: $sql');
          });
        }

        test('login bypass: user=\\  password=") OR 1=1 -- "', () async {
          final sql = db.sql(
            selectUsers()
                .whereOne(QField('name'), QO.EQ, QVar(r'\'))
                .whereOne(QField('secret'), QO.EQ, QVar(') OR 1=1 -- ')),
          );
          final rows = await db.attack(sql);
          expect(rows, isEmpty, reason: 'authentication bypass: $sql');
        });

        test('IN (...) list is not injectable', () async {
          final sql = db.sql(
            selectUsers().whereOne(
              QField('name'),
              QO.IN,
              QVar([r"\", ') OR 1=1 -- ']),
            ),
          );
          final rows = await db.attack(sql);
          expect(rows, isEmpty, reason: 'injection succeeded: $sql');
        });

        test('range filter (>= and <=) is not injectable', () async {
          // NOTE: QO.BETWEEN with QVar([a, b]) renders "BETWEEN (a, b)", which
          // is not valid SQL, so a range is expressed with two conditions.
          final sql = db.sql(
            selectUsers()
                .whereOne(QField('name'), QO.GTE, QVar(r"\') OR 1=1 -- "))
                .whereOne(QField('name'), QO.LTE, QVar(r"\")),
          );
          final rows = await db.attack(sql);
          expect(rows, isEmpty, reason: 'injection succeeded: $sql');
        });

        test(
          'INSERT with two attacker controlled fields can not subselect',
          () async {
            const author = r'\';
            const body = ', (SELECT secret FROM inj_users WHERE id = 3)) -- ';
            final sql = db.sql(
              Sqler().insert(QField('inj_notes'), [
                {'author': QVar(author), 'body': QVar(body)},
              ]),
            );
            await db.attack(sql);
            final rows = await db.run('SELECT author, body FROM inj_notes');
            expect(leaks(rows), isFalse, reason: 'data exfiltration: $sql');
          },
        );

        test('UPDATE value breakout can not set other columns', () async {
          final sql = db.sql(
            Sqler()
                .update(QField('inj_users'))
                .updateSet('bio', QVar(r"\"))
                .updateSet('name', QVar(", role = 'admin' WHERE id = 2 -- "))
                .whereOne(QField('id'), QO.EQ, QVar(1)),
          );
          await db.attack(sql);
          final rows = await db.run(
            "SELECT role FROM inj_users WHERE name = 'bob'",
          );
          expect(rows.first['role'], 'user', reason: 'priv-esc: $sql');
        });
      });

      group('LIKE', () {
        for (final payload in valueBreakouts) {
          test('QVarLike is not injectable: $payload', () async {
            final sql = db.sql(
              selectUsers().whereOne(
                QField('name'),
                QO.LIKE,
                QVarLike(payload),
              ),
            );
            final rows = await db.attack(sql);
            expect(rows, isEmpty, reason: 'injection succeeded: $sql');
          });
        }

        test('QVarLike with an apostrophe works (no syntax error)', () async {
          await db.run(
            "INSERT INTO inj_notes (author, body) VALUES "
            "('x', 'it''s fine')",
          );
          final sql = db.sql(
            Sqler()
                .addSelect(QSelectAll())
                .from(QField('inj_notes'))
                .whereOne(QField('body'), QO.LIKE, QVarLike("it's")),
          );
          final rows = await db.run(sql);
          expect(rows.length, 1, reason: sql);
        });

        test('LIKE wildcard "_" in user input is treated literally', () async {
          await db.run(
            "INSERT INTO inj_notes (author, body) VALUES "
            "('x', 'a_b'), ('x', 'axb')",
          );
          final sql = db.sql(
            Sqler()
                .addSelect(QSelect('body'))
                .from(QField('inj_notes'))
                .whereOne(
                  QField('body'),
                  QO.LIKE,
                  QVarLike('a_b', left: false, right: false),
                ),
          );
          final rows = await db.run(sql);
          expect(rows.map((r) => r['body']).toList(), [
            'a_b',
          ], reason: '"_" in user input acted as a wildcard: $sql');
        });

        test('LIKE wildcard "%" in user input is treated literally', () async {
          await db.run(
            "INSERT INTO inj_notes (author, body) VALUES "
            "('x', '100%'), ('x', '1000')",
          );
          final sql = db.sql(
            Sqler()
                .addSelect(QSelect('body'))
                .from(QField('inj_notes'))
                .whereOne(
                  QField('body'),
                  QO.LIKE,
                  QVarLike('100%', left: false, right: false),
                ),
          );
          final rows = await db.run(sql);
          expect(rows.map((r) => r['body']).toList(), [
            '100%',
          ], reason: '"%" in user input is not matched literally: $sql');
        });
      });

      group('Identifiers', () {
        test('QSelect(column) can not select extra columns', () async {
          final sql = db.sql(
            Sqler()
                .addSelect(QSelect('name${db.q}, ${db.q}secret'))
                .from(QField('inj_users')),
          );
          final rows = await db.attack(sql);
          expect(leaks(rows), isFalse, reason: 'column injection: $sql');
          expect(
            rows.any((r) => r.containsKey('secret')),
            isFalse,
            reason: 'column injection: $sql',
          );
        });

        test('QSelect alias can not select extra columns', () async {
          final sql = db.sql(
            Sqler()
                .addSelect(
                  QSelect(
                    'name',
                    as: 'x${db.q}, ${db.q}secret${db.q} AS ${db.q}y',
                  ),
                )
                .from(QField('inj_users')),
          );
          final rows = await db.attack(sql);
          expect(leaks(rows), isFalse, reason: 'alias injection: $sql');
        });

        test('table.column prefix can not inject a UNION', () async {
          final sql = db.sql(
            Sqler()
                .addSelect(
                  QSelect('1 UNION SELECT secret FROM inj_users -- .a'),
                )
                .from(QField('inj_users')),
          );
          final rows = await db.attack(sql);
          expect(leaks(rows), isFalse, reason: 'UNION injection: $sql');
        });

        test('FROM table name can not inject', () async {
          final sql = db.sql(
            Sqler()
                .addSelect(QSelectAll())
                .from(
                  QField(
                    'inj_notes${db.q} UNION SELECT * FROM ${db.q}inj_users',
                  ),
                ),
          );
          final rows = await db.attack(sql);
          expect(leaks(rows), isFalse, reason: 'UNION injection: $sql');
        });

        test('UPDATE column name (mass assignment) can not set role', () async {
          final sql = db.sql(
            Sqler()
                .update(QField('inj_users'))
                .updateSet("bio${db.q} = 'x', ${db.q}role", QVar('admin'))
                .whereOne(QField('id'), QO.EQ, QVar(2)),
          );
          await db.attack(sql);
          final rows = await db.run(
            "SELECT role FROM inj_users WHERE name = 'bob'",
          );
          expect(rows.first['role'], 'user', reason: 'priv-esc: $sql');
        });

        test('INSERT column name can not smuggle extra columns', () async {
          final sql = db.sql(
            Sqler().insert(QField('inj_users'), [
              {"name${db.q}, ${db.q}role": QVar('x')},
            ]),
          );
          await db.attack(sql);
          final rows = await db.run("SELECT * FROM inj_users WHERE name = 'x'");
          // With proper quoting the column does not exist and nothing is inserted.
          expect(rows, isEmpty, reason: 'column injection: $sql');
        });
      });

      group('ORDER BY / GROUP BY / Joins', () {
        test('QOrder can not append extra sort expressions', () async {
          // Valid SQL only if the identifier quote was broken.
          final sql = db.sql(
            selectUsers().orderBy(
              QOrder('role${db.q}, ${db.q}name${db.q} DESC, ${db.q}id'),
            ),
          );
          final rows = await db.attack(sql);
          // MySQL: unknown column -> error -> []. SQLite treats unknown "x" as
          // a string literal, so make the check dialect independent by also
          // looking at the generated SQL.
          if (db.mysql) {
            expect(rows, isEmpty, reason: 'ORDER BY injection: $sql');
          } else {
            expect(
              stripQuoted(sql, '"'),
              isNot(contains('DESC')),
              reason: 'ORDER BY injection: $sql',
            );
          }
        });

        test('Join table name can not inject', () async {
          final sql = db.sql(
            selectUsers().join(Join('inj_notes${db.q} ON 1=1 -- ', On())),
          );
          final rows = await db.attack(sql);
          expect(rows, isEmpty, reason: 'JOIN injection: $sql');
        });
      });
    });
  }

  liveSuite('MySQL', openMysql);
  liveSuite('SQLite (in-memory)', () async => openSqlite());
}

class _Evil {
  @override
  String toString() => "' OR 1=1 -- ";
}
