// Realistic, larger-scale SQL-injection tests for Sqler.
//
// `sqler_injection_test.dart` attacks single building blocks. This file builds
// the kind of queries a real application builds - product search with joins,
// LIKE and IN filters, sales reports with aggregates / GROUP BY / HAVING,
// derived tables and sub-queries, UNIONs, CASE expressions, bulk UPDATE /
// INSERT / DELETE, `{param}` placeholders, user-supplied column names - and
// then attacks EVERY user-controlled input of EVERY query, one at a time and
// all at once, on MySQL (`make mysql-start`) and SQLite (in-memory).
//
// How a hostile input is judged (differential testing):
//
//  1. Skeleton: all string literals / quoted identifiers are masked. A safe
//     builder yields exactly the same skeleton for a hostile input as for a
//     harmless one (`zzz-no-match`). If the skeleton differs the input changed
//     the *structure* of the query -> injection. (No database needed.)
//  2. Live (reads): the result must equal the result for the harmless input
//     and must never contain a secret column.
//  3. Live (writes): executed inside a transaction; the resulting database
//     state must equal the state produced by the harmless input, with the
//     hostile text stored verbatim wherever a value was meant to be stored.
//     Hostile column names must leave the database untouched.
//
// All tables are `shop_*` so this file can run in parallel with the others.
import 'dart:convert';
import 'dart:math';

import 'package:sqler/sqler.dart';
import 'package:test/test.dart';

import 'helpers/injection_helpers.dart';

// -----------------------------------------------------------------------------
// Schema & seed data (seeded through Sqler itself, with awkward legit strings)
// -----------------------------------------------------------------------------

const shopTables = [
  'shop_categories',
  'shop_users',
  'shop_products',
  'shop_orders',
  'shop_order_items',
  'shop_audit',
];

Future<void> resetShop(Db db) async {
  final id =
      db.mysql
          ? 'INT PRIMARY KEY AUTO_INCREMENT'
          : 'INTEGER PRIMARY KEY AUTOINCREMENT';
  for (final t in shopTables.reversed) {
    await db.run('DROP TABLE IF EXISTS $t');
  }
  await db.run(
    'CREATE TABLE shop_categories (id $id, name TEXT, parent_id INT)',
  );
  await db.run(
    'CREATE TABLE shop_users (id $id, name TEXT, email TEXT, role TEXT, '
    'password_hash TEXT, api_token TEXT, created_at TEXT)',
  );
  await db.run(
    'CREATE TABLE shop_products (id $id, title TEXT, description TEXT, '
    'category_id INT, price INT, stock INT)',
  );
  await db.run(
    'CREATE TABLE shop_orders (id $id, user_id INT, status TEXT, total INT, '
    'note TEXT, created_at TEXT)',
  );
  await db.run(
    'CREATE TABLE shop_order_items (id $id, order_id INT, product_id INT, '
    'qty INT, price INT)',
  );
  await db.run('CREATE TABLE shop_audit (id $id, actor TEXT, action TEXT)');

  Future<void> insert(String table, List<Map<String, Object?>> rows) => db.run(
    db.sql(
      Sqler().insert(QField(table), [
        for (final r in rows) {for (final e in r.entries) e.key: QVar(e.value)},
      ]),
    ),
  );

  await insert('shop_categories', [
    {'name': 'Books', 'parent_id': null},
    {'name': 'Games', 'parent_id': null},
    {'name': 'Board games', 'parent_id': 2},
  ]);
  await insert('shop_users', [
    {
      'name': 'alice',
      'email': 'alice@example.com',
      'role': 'user',
      'password_hash': 'SECRET-HASH-alice',
      'api_token': 'SECRET-TOKEN-alice',
      'created_at': '2024-01-10',
    },
    {
      'name': 'bob',
      'email': 'bob@example.com',
      'role': 'user',
      'password_hash': 'SECRET-HASH-bob',
      'api_token': 'SECRET-TOKEN-bob',
      'created_at': '2024-02-11',
    },
    {
      'name': 'admin',
      'email': 'admin@example.com',
      'role': 'admin',
      'password_hash': 'SECRET-HASH-admin',
      'api_token': 'TOP-SECRET-ADMIN-TOKEN',
      'created_at': '2023-12-01',
    },
  ]);
  await insert('shop_products', [
    {
      'title': 'Dart in Action',
      'description': 'A book about Dart',
      'category_id': 1,
      'price': 3500,
      'stock': 10,
    },
    {
      'title': 'SQL Cookbook',
      'description': 'Recipes for SQL',
      'category_id': 1,
      'price': 4500,
      'stock': 0,
    },
    {
      'title': 'Chess Set',
      'description': 'Classic board game',
      'category_id': 3,
      'price': 2500,
      'stock': 5,
    },
    {
      'title': 'Catan',
      'description': 'Trade and build',
      'category_id': 3,
      'price': 4000,
      'stock': 7,
    },
    {
      'title': 'Video Game X',
      'description': 'Console game',
      'category_id': 2,
      'price': 6000,
      'stock': 2,
    },
    {
      'title': 'Reilly Guide',
      'description': 'A practical guide',
      'category_id': 1,
      'price': 5000,
      'stock': 3,
    },
  ]);
  await insert('shop_orders', [
    {
      'user_id': 1,
      'status': 'paid',
      'total': 8000,
      'note': 'first order',
      'created_at': '2024-01-15',
    },
    {
      'user_id': 1,
      'status': 'pending',
      'total': 2500,
      'note': 'second',
      'created_at': '2024-02-01',
    },
    {
      'user_id': 2,
      'status': 'paid',
      'total': 4500,
      'note': 'gift',
      'created_at': '2024-02-20',
    },
    {
      'user_id': 2,
      'status': 'cancelled',
      'total': 6000,
      'note': 'oops',
      'created_at': '2024-03-05',
    },
    {
      'user_id': 3,
      'status': 'paid',
      'total': 100,
      'note': 'internal',
      'created_at': '2024-03-06',
    },
  ]);
  await insert('shop_order_items', [
    {'order_id': 1, 'product_id': 1, 'qty': 2, 'price': 3500},
    {'order_id': 2, 'product_id': 3, 'qty': 1, 'price': 2500},
    {'order_id': 3, 'product_id': 2, 'qty': 1, 'price': 4500},
  ]);
  await insert('shop_audit', [
    {'actor': 'alice', 'action': 'login'},
    {'actor': 'bob', 'action': 'login'},
  ]);
}

typedef Snapshot = Map<String, List<List<String?>>>;

/// Whole database state (autoincrement ids are left out because InnoDB does
/// not roll them back).
Future<Snapshot> snapshot(Db db) async {
  final snap = <String, List<List<String?>>>{};
  for (final t in shopTables) {
    final rows = await db.run('SELECT * FROM $t ORDER BY id');
    snap[t] = [
      for (final r in rows)
        [
          for (final e in r.entries)
            if (e.key != 'id') e.value,
        ],
    ];
  }
  return snap;
}

/// Replaces cells that contain exactly [from] with [to].
Snapshot normalize(Snapshot s, String from, String to) => {
  for (final e in s.entries)
    e.key: [
      for (final row in e.value) [for (final c in row) c == from ? to : c],
    ],
};

/// Every row of [after] is either untouched ([before]) or what the
/// "match every row" statement produced ([full]); no row appeared / vanished.
bool stateBetween(Snapshot before, Snapshot after, Snapshot full) {
  for (final t in shopTables) {
    final b = before[t]!, a = after[t]!, f = full[t]!;
    if (a.length != b.length || f.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final ja = jsonEncode(a[i]);
      if (ja != jsonEncode(b[i]) && ja != jsonEncode(f[i])) return false;
    }
  }
  return true;
}

Future<T> inTransaction<T>(Db db, Future<T> Function() body) async {
  await db.run('BEGIN');
  try {
    return await body();
  } finally {
    await db.run('ROLLBACK');
  }
}

// -----------------------------------------------------------------------------
// Hostile input catalogue
// -----------------------------------------------------------------------------

const control = 'zzz-no-match';

List<String> valuePayloads() {
  final payloads = <String>[
    "' OR '1'='1",
    "' OR 1=1 -- ",
    "' OR 1=1 #",
    "') OR 1=1 -- ",
    "')) OR 1=1 -- ",
    r"\' OR 1=1 -- ",
    r"\') OR 1=1 -- ",
    r"\')) OR 1=1 -- ",
    r"\'))) OR 1=1 /*",
    r"\\' OR 1=1 -- ",
    r"\",
    r"\\",
    r"\\\",
    "'",
    "''",
    "'''",
    '"',
    '" OR ""="',
    '`',
    "x'; DROP TABLE shop_users; -- ",
    r"x\'; DROP TABLE shop_users; -- ",
    "'; UPDATE shop_users SET role='admin' -- ",
    r"\'; UPDATE shop_users SET role=0x61646d696e -- ",
    "' AND (SELECT COUNT(*) FROM shop_users) > 0 -- ",
    "' OR EXISTS(SELECT 1 FROM shop_users WHERE role='admin') -- ",
    "%",
    "_",
    "%' OR title LIKE '%",
    r"\%",
    r"\_",
    "{cat}",
    "{minStock}",
    "{role}",
    "{secret}",
    "{email}",
    "{hash}",
    "{",
    "}",
    "{}",
    "x{secret}y",
    "{secret}'",
    "'{secret}",
    "ʼ OR 1=1 -- ", // modifier letter apostrophe
    "＇ OR 1=1 -- ", // fullwidth apostrophe
    "¿' OR 1=1 -- ", // GBK-style multibyte trick
    "line1\nline2' OR 1=1 -- ",
    "tab\t'\r\n",
    "unicode ß 漢字 😀 ' OR 1=1 -- ",
    ' ',
    '',
    '0x27',
    '1e1',
    '-1',
    '1; SELECT 1',
  ];

  // UNION based exfiltration for 1..12 selected columns, several closing styles
  for (final prefix in ["'", r"\'", r"\')", r"\'))"]) {
    for (var n = 1; n <= 12; n++) {
      payloads.add(
        '$prefix UNION SELECT ${List.filled(n, 'api_token').join(', ')} '
        'FROM shop_users -- ',
      );
    }
  }

  payloads.addAll(_fuzz(seed: 1337, count: 60));
  return payloads;
}

List<String> identPayloads(String q) {
  final payloads = <String>[
    q,
    '$q$q',
    'x$q',
    '${q}x',
    'title$q, ${q}api_token',
    'title$q, ${q}api_token$q AS ${q}x',
    'id$q FROM shop_users UNION SELECT api_token FROM shop_users -- ',
    '$q FROM shop_users UNION SELECT api_token, api_token, api_token FROM shop_users -- ',
    '1 UNION SELECT api_token FROM shop_users -- .a',
    'x) OR 1=1 -- .id',
    'price; DROP TABLE shop_users -- ',
    'price DESC, (SELECT api_token FROM shop_users LIMIT 1)',
    'title desc',
    'a.${q}b',
    r'a\' + q,
    '$q.$q',
    '..',
    ' ',
    'role$q = ${q}admin',
    "role = 'admin' -- ",
    'name$q = ${q}x$q, ${q}role',
    '{cat}',
    '{secret}',
    '漢字😀',
  ];
  payloads.addAll(
    _fuzz(
      seed: 99,
      count: 40,
      extra: [q],
    ).where((p) => !p.split('.').contains('*')),
  );
  return payloads;
}

/// Deterministic pseudo random strings made of SQL meta characters.
List<String> _fuzz({
  required int seed,
  required int count,
  List<String> extra = const [],
}) {
  final rnd = Random(seed);
  final atoms = [
    "'",
    '"',
    r'\',
    '`',
    '%',
    '_',
    ';',
    '#',
    '--',
    '/*',
    '*/',
    '(',
    ')',
    '{',
    '}',
    ',',
    ' ',
    '\n',
    '=',
    '<',
    '>',
    '|',
    '&',
    '!',
    '?',
    '@',
    r'$',
    '.',
    ':',
    'OR',
    'AND',
    'UNION',
    'SELECT',
    'FROM',
    'WHERE',
    '1',
    '0',
    'a',
    'Z',
    'x',
    'api_token',
    'shop_users',
    'NULL',
    'SLEEP(0)',
    '0x27',
    '¿',
    '😀',
    ...extra,
  ];
  return [
    for (var i = 0; i < count; i++)
      List.generate(
        1 + rnd.nextInt(14),
        (_) => atoms[rnd.nextInt(atoms.length)],
      ).join(),
  ];
}

// -----------------------------------------------------------------------------
// Scenario framework
// -----------------------------------------------------------------------------

enum Kind { value, like, ident }

typedef Inputs = Map<String, Object>;

class Field {
  final String name;
  final Kind kind;

  /// String, or List&lt;String&gt; (the last element is the one attacked).
  final Object benign;

  /// Compared with a number: payloads that start with a digit legitimately
  /// change the comparison and are not used.
  final bool numeric;

  /// A value for which the predicate matches every row (range filters, where a
  /// hostile text can legitimately select any subset): the result may then only
  /// shrink compared with this reference.
  final String? matchAll;

  const Field(
    this.name,
    this.kind,
    this.benign, {
    this.numeric = false,
    this.matchAll,
  });
}

class Scenario {
  final String name;
  final List<Field> fields;
  final SQL Function(Inputs inputs, bool mysql) build;

  /// Mutating statement (checked via database snapshots) or SELECT.
  final bool write;

  /// Minimum number of rows the benign read must return.
  final int minRows;

  /// Execute against a database (EXPLAIN & friends are generation-only).
  final bool live;

  /// Tables a write statement is allowed to change.
  final Set<String> targets;

  Scenario(
    this.name,
    this.fields,
    this.build, {
    this.write = false,
    this.minRows = 1,
    this.live = true,
    this.targets = const {},
  });

  Inputs get benign => {for (final f in fields) f.name: f.benign};

  Inputs with_(Field f, String v) {
    final i = Inputs.of(benign);
    final b = f.benign;
    i[f.name] = b is List ? [...b.cast<String>().take(b.length - 1), v] : v;
    return i;
  }

  /// Every input hostile at once; [pick] chooses the payload per field.
  Inputs allHostile(String Function(Field) pick) {
    final i = Inputs.of(benign);
    for (final f in fields) {
      final v = pick(f);
      final b = f.benign;
      i[f.name] = b is List ? [...b.cast<String>().take(b.length - 1), v] : v;
    }
    return i;
  }

  String sqlFor(Inputs i, bool mysql) {
    final s = build(i, mysql);
    return mysql ? s.toSQL<Mysql>() : s.toSQL<Sqlite>();
  }
}

String _s(Inputs i, String k) => i[k]! as String;
List<String> _l(Inputs i, String k) => (i[k]! as List).cast<String>();

// ---- the application queries ------------------------------------------------

/// Product search: LEFT JOIN, OR'd LIKE, range + IN filters, user chosen sort.
Sqler productSearch(Inputs i, bool my) => Sqler()
    .addSelect(QSelect('p.id'))
    .addSelect(QSelect('p.title'))
    .addSelect(QSelect('p.price'))
    .addSelect(QSelect('c.name', as: 'category'))
    .from(QField('shop_products', as: 'p'))
    .join(
      LeftJoin(
        'shop_categories',
        OnOne(QField('p.category_id'), QO.EQ, QField('c.id')),
        as: 'c',
      ),
    )
    .where(
      OrWhere([
        Condition(QField('p.title'), QO.LIKE, QVarLike(_s(i, 'q'))),
        Condition(QField('p.description'), QO.LIKE, QVarLike(_s(i, 'q'))),
      ]),
    )
    .whereOne(QField('p.price'), QO.GTE, QVar(_s(i, 'min')))
    .whereOne(QField('p.price'), QO.LTE, QVar(_s(i, 'max')))
    .whereOne(QField('p.category_id'), QO.IN, QVar(_l(i, 'cats')))
    .whereOne(QField('p.stock'), QO.GT, QVar(0))
    .orderBy(QOrder(_s(i, 'sort'), desc: true))
    .orderBy(QOrder('p.id'))
    .limit(20, 0);

const productSearchFields = [
  Field('q', Kind.like, 'game'),
  Field('min', Kind.value, '1000', numeric: true),
  Field('max', Kind.value, '5000', numeric: true),
  Field('cats', Kind.value, ['1', '3'], numeric: true),
  Field('sort', Kind.ident, 'p.price'),
];

/// Login check, optionally through `{param}` placeholders.
Sqler login(Inputs i, {required bool params}) {
  final q = Sqler()
      .addSelect(QSelect('id'))
      .addSelect(QSelect('name'))
      .addSelect(QSelect('role'))
      .from(QField('shop_users'))
      .whereOne(
        QField('email'),
        QO.EQ,
        params ? QParam('email') : QVar(_s(i, 'email')),
      )
      .whereOne(
        QField('password_hash'),
        QO.EQ,
        params ? QParam('hash') : QVar(_s(i, 'hash')),
      );
  if (params) {
    q.addParams({'email': QVar(_s(i, 'email')), 'hash': QVar(_s(i, 'hash'))});
  }
  return q;
}

/// Sales report: aggregates, JOIN, IN / range / LIKE filters, GROUP BY, HAVING.
Sqler salesReport(Inputs i, bool my) {
  QSelectField count(QField f) =>
      my ? SQL.count<Mysql>(f) : SQL.count<Sqlite>(f);
  QSelectField sum(QField f) => my ? SQL.sum<Mysql>(f) : SQL.sum<Sqlite>(f);
  return Sqler()
      .addSelect(QSelect(_s(i, 'group'), as: 'customer'))
      .addSelect(count(QField('o.id', as: 'orders')))
      .addSelect(sum(QField('o.total', as: 'spent')))
      .from(QField('shop_users', as: 'u'))
      .join(
        Join(
          'shop_orders',
          OnOne(QField('u.id'), QO.EQ, QField('o.user_id')),
          as: 'o',
        ),
      )
      .whereOne(QField('o.status'), QO.IN, QVar(_l(i, 'statuses')))
      .whereOne(QField('o.created_at'), QO.GTE, QVar(_s(i, 'from')))
      .whereOne(QField('o.created_at'), QO.LTE, QVar(_s(i, 'to')))
      .where(
        OrWhere([
          Condition(QField('u.name'), QO.LIKE, QVarLike(_s(i, 'term'))),
          Condition(QField('u.email'), QO.LIKE, QVarLike(_s(i, 'term'))),
        ]),
      )
      .groupBy([_s(i, 'group')])
      .having(
        Having([
          Condition(
            QField('spent'),
            QO.GT,
            QVar(int.tryParse(_s(i, 'minSpent')) ?? _s(i, 'minSpent')),
          ),
        ]),
      )
      .orderBy(QOrder('spent', desc: true))
      .limit(5);
}

/// Derived table + IN (sub-query) + NEQ, aliases chosen by the caller.
Sqler customersWithOrders(Inputs i, bool my) {
  final orderUsers = Sqler()
      .addSelect(QSelect('user_id'))
      .from(QField('shop_orders'))
      .whereOne(QField('status'), QO.EQ, QVar(_s(i, 'status')));
  final inner = Sqler()
      .addSelect(QSelect('u.name'))
      .addSelect(QSelect('u.email'))
      .from(QField('shop_users', as: 'u'))
      .whereOne(QField('u.id'), QO.IN, QVar(orderUsers))
      .where(
        OrWhere([
          Condition(QField('u.email'), QO.LIKE, QVarLike(_s(i, 'term'))),
          Condition(QField('u.name'), QO.LIKE, QVarLike(_s(i, 'term'))),
        ]),
      );
  return Sqler()
      .addSelect(QSelect('d.name'))
      .addSelect(QSelect('d.email'))
      .from(QFromQuery(inner, as: _s(i, 'alias')))
      .whereOne(QField('d.name'), QO.NEQ, QVar(_s(i, 'excluded')))
      .orderBy(QOrder('d.name'));
}

/// UNION ALL of two different tables, user chosen ORDER BY.
Union unionSearch(Inputs i, bool my) {
  final a = Sqler()
      .addSelect(QSelect('title'))
      .addSelect(QSelect('price'))
      .from(QField('shop_products'))
      .whereOne(QField('title'), QO.LIKE, QVarLike(_s(i, 't1')));
  final b = Sqler()
      .addSelect(QSelect('name', as: 'title'))
      .addSelect(QSelect('parent_id', as: 'price'))
      .from(QField('shop_categories'))
      .whereOne(QField('name'), QO.EQ, QVar(_s(i, 't2')));
  return Union([a, b], uniunAll: true)..addOrderBy(QOrder(_s(i, 'sort')));
}

/// CASE expression with user supplied labels / thresholds / alias.
Sqler stockLevels(Inputs i, bool my) => Sqler()
    .addSelect(QSelect('title'))
    .addSelect(
      Case(
        conditions: [
          CaseCondition(
            when: Condition(QField('stock'), QO.LT, QVar(_s(i, 'low'))),
            then: QVar(_s(i, 'lowLabel')),
          ),
          CaseCondition(
            when: Condition(QField('price'), QO.GT, QVar(_s(i, 'high'))),
            then: QVar(_s(i, 'highLabel')),
          ),
        ],
        elseValue: QVar(_s(i, 'okLabel')),
        as: QField(_s(i, 'alias')),
      ),
    )
    .from(QField('shop_products'))
    .orderBy(QOrder('id'));

/// Pagination: COUNT(*) over the whole product search as a derived table.
Sqler productCount(Inputs i, bool my) => Sqler()
    .addSelect(
      my
          ? SQL.count<Mysql>(QField('*', as: 'total'))
          : SQL.count<Sqlite>(QField('*', as: 'total')),
    )
    .from(QFromQuery(productSearch(i, my), as: 'x'));

/// `{param}` placeholders next to hostile user data that looks like them.
Sqler paramReport(Inputs i, bool my) => Sqler()
    .addSelect(QSelect('id'))
    .addSelect(QSelect('title'))
    .addSelect(
      Case(
        conditions: [
          CaseCondition(
            when: Condition(QField('stock'), QO.GT, QVar(0)),
            then: QVar(_s(i, 'label')),
          ),
        ],
        elseValue: QVar('none'),
        as: QField('tag'),
      ),
    )
    .from(QField('shop_products'))
    .whereOne(QField('title'), QO.LIKE, QVarLike(_s(i, 'q')))
    .whereOne(QField('category_id'), QO.EQ, QParam('cat'))
    .whereOne(QField('stock'), QO.GTE, QParam('minStock'))
    .addParams({
      'cat': QVar(1),
      'minStock': QVar(0),
      'role': QVar('admin'),
      'secret': QVar('SECRET-FROM-PARAM'),
      'email': QVar('admin@example.com'),
      'hash': QVar('SECRET-HASH-admin'),
    });

// ---- mutating statements ----------------------------------------------------

Sqler editProduct(Inputs i, bool my) => Sqler()
    .update(QField('shop_products'))
    .updateSet('title', QVar(_s(i, 'title')))
    .updateSet('description', QVar(_s(i, 'desc')))
    .updateSet('stock', QVar(42))
    .whereOne(QField('title'), QO.EQ, QVar(_s(i, 'oldTitle')))
    .whereOne(QField('description'), QO.LIKE, QVarLike(_s(i, 'descLike')));

Sqler bulkStatus(Inputs i, bool my) => Sqler()
    .update(QField('shop_orders'))
    .updateSet('status', QVar(_s(i, 'newStatus')))
    .updateSet('note', QVar(_s(i, 'note')))
    .whereOne(QField('status'), QO.IN, QVar(_l(i, 'olds')))
    .whereOne(QField('user_id'), QO.EQ, QVar(1))
    .whereOne(QField('created_at'), QO.GTE, QVar(_s(i, 'from')))
    .whereOne(QField('created_at'), QO.LTE, QVar(_s(i, 'to')));

Sqler bulkInsert(Inputs i, bool my) => Sqler().insert(QField('shop_orders'), [
  {
    'user_id': QVar(1),
    'status': QVar('new'),
    'total': QVar(100),
    'note': QVar(_s(i, 'note1')),
    'created_at': QVar('2024-04-01'),
  },
  {
    'user_id': QVar(2),
    'status': QVar(_s(i, 'status')),
    'total': QVar(200),
    'note': QVar(_s(i, 'note2')),
    'created_at': QVar(_s(i, 'date')),
  },
  {
    'user_id': QVar(3),
    'status': QVar('new'),
    'total': QVar(300),
    'note': QVar(null),
    'created_at': QVar('2024-04-03'),
  },
]);

Sqler deleteWithSubquery(Inputs i, bool my) => Sqler()
    .delete()
    .from(QField('shop_orders'))
    .whereOne(QField('status'), QO.EQ, QVar(_s(i, 'status')))
    .whereOne(
      QField('user_id'),
      QO.IN,
      QVar(
        Sqler()
            .addSelect(QSelect('id'))
            .from(QField('shop_users'))
            .whereOne(QField('email'), QO.LIKE, QVarLike(_s(i, 'email'))),
      ),
    )
    .whereOne(QField('note'), QO.NOT_IN, QVar(_l(i, 'keep')));

/// "Update my profile" built from a user supplied field name.
Sqler massAssignment(Inputs i, bool my) => Sqler()
    .update(QField('shop_users'))
    .updateSet(_s(i, 'field'), QVar(_s(i, 'value')))
    .updateSet('name', QVar('renamed'))
    .whereOne(QField('email'), QO.EQ, QVar('bob@example.com'));

/// Insert built from a user supplied key/value map.
Sqler insertFromMap(Inputs i, bool my) => Sqler().insert(QField('shop_audit'), [
  {_s(i, 'key'): QVar('someone'), 'action': QVar(_s(i, 'action'))},
]);

final scenarios = <Scenario>[
  Scenario('product search', productSearchFields, productSearch),
  Scenario('login (inline values)', const [
    Field('email', Kind.value, 'alice@example.com'),
    Field('hash', Kind.value, 'SECRET-HASH-alice'),
  ], (i, my) => login(i, params: false)),
  Scenario('login (QParam placeholders)', const [
    Field('email', Kind.value, 'alice@example.com'),
    Field('hash', Kind.value, 'SECRET-HASH-alice'),
  ], (i, my) => login(i, params: true)),
  Scenario('sales report (aggregates, GROUP BY, HAVING)', const [
    Field('group', Kind.ident, 'u.name'),
    Field('statuses', Kind.value, ['paid', 'pending']),
    Field('from', Kind.value, '2024-01-01', matchAll: '0000'),
    Field('to', Kind.value, '2024-12-31', matchAll: 'zzzz'),
    Field('term', Kind.like, 'alice'),
    Field('minSpent', Kind.value, '0', numeric: true),
  ], salesReport),
  Scenario(
    'customers (derived table + sub-query)',
    const [
      Field('status', Kind.value, 'paid'),
      Field('term', Kind.like, 'example'),
      Field('excluded', Kind.value, 'admin'),
      Field('alias', Kind.ident, 'd'),
    ],
    customersWithOrders,
    minRows: 2,
  ),
  Scenario(
    'UNION ALL search',
    const [
      Field('t1', Kind.like, 'game'),
      Field('t2', Kind.value, 'Games'),
      Field('sort', Kind.ident, 'title'),
    ],
    unionSearch,
    minRows: 2,
  ),
  Scenario(
    'CASE stock levels',
    const [
      Field('low', Kind.value, '3', numeric: true),
      Field('lowLabel', Kind.value, 'LOW'),
      Field('high', Kind.value, '5500', numeric: true),
      Field('highLabel', Kind.value, 'PREMIUM'),
      Field('okLabel', Kind.value, 'OK'),
      Field('alias', Kind.ident, 'level'),
    ],
    stockLevels,
    minRows: 6,
  ),
  Scenario(
    'pagination COUNT(*) over search',
    productSearchFields,
    productCount,
  ),
  Scenario(
    'EXPLAIN of product search',
    productSearchFields,
    (i, my) => SqlExplain(productSearch(i, my)),
    live: false,
  ),
  Scenario('{param} placeholders vs hostile text', const [
    Field('q', Kind.like, 'a'),
    Field('label', Kind.value, 'IN-STOCK'),
  ], paramReport),
  // ---- writes
  Scenario(
    'UPDATE product (SET + WHERE + LIKE)',
    const [
      Field('title', Kind.value, 'New Title'),
      Field('desc', Kind.value, 'New description'),
      Field('oldTitle', Kind.value, 'Catan'),
      Field('descLike', Kind.like, 'build'),
    ],
    editProduct,
    write: true,
    targets: {'shop_products'},
  ),
  Scenario(
    'UPDATE orders in bulk (IN + range)',
    const [
      Field('newStatus', Kind.value, 'shipped'),
      Field('note', Kind.value, 'bulk'),
      Field('olds', Kind.value, ['pending', 'cancelled']),
      Field('from', Kind.value, '2024-01-01', matchAll: '0000'),
      Field('to', Kind.value, '2024-12-31', matchAll: 'zzzz'),
    ],
    bulkStatus,
    write: true,
    targets: {'shop_orders'},
  ),
  Scenario(
    'INSERT 3 orders in one statement',
    const [
      Field('note1', Kind.value, 'n1'),
      Field('status', Kind.value, 'new'),
      Field('note2', Kind.value, 'n2'),
      Field('date', Kind.value, '2024-04-02'),
    ],
    bulkInsert,
    write: true,
    targets: {'shop_orders'},
  ),
  Scenario(
    'DELETE with sub-query and NOT IN',
    const [
      Field('status', Kind.value, 'cancelled'),
      Field('email', Kind.like, 'bob@'),
      Field('keep', Kind.value, ['gift']),
    ],
    deleteWithSubquery,
    write: true,
    targets: {'shop_orders'},
  ),
  Scenario(
    'UPDATE with user supplied column name',
    const [
      Field('field', Kind.ident, 'created_at'),
      Field('value', Kind.value, '2025-01-01'),
    ],
    massAssignment,
    write: true,
    targets: {'shop_users'},
  ),
  Scenario(
    'INSERT from user supplied map',
    const [
      Field('key', Kind.ident, 'actor'),
      Field('action', Kind.value, 'signup'),
    ],
    insertFromMap,
    write: true,
    targets: {'shop_audit'},
  ),
];

// -----------------------------------------------------------------------------
// Comparison helpers
// -----------------------------------------------------------------------------

String rowsJson(List<Row> rows) => jsonEncode(rows);

List<Row> normalizeRows(List<Row> rows, String from, String to) => [
  for (final r in rows)
    {for (final e in r.entries) e.key: e.value == from ? to : e.value},
];

/// True if [p] appears literally in the (JSON encoded, lower-cased) seed data.
bool inCorpus(String corpus, String p) {
  final enc = jsonEncode(p);
  return corpus.contains(enc.substring(1, enc.length - 1).toLowerCase());
}

/// Text a database may legitimately read as a number.
bool numericLike(String p) => RegExp(r'^\s*[-+.]?\d').hasMatch(p);

String shortSql(String sql) =>
    sql.length > 700 ? '${sql.substring(0, 700)}...' : sql;

void main() {
  final values = valuePayloads();

  // ---------------------------------------------------------------------------
  // 1. Structure tests (no database)
  // ---------------------------------------------------------------------------
  for (final s in scenarios) {
    group('Skeleton: ${s.name}', () {
      for (final mysql in [true, false]) {
        final dialect = mysql ? 'MySQL' : 'SQLite';
        final idents = identPayloads(mysql ? '`' : '"');

        for (final f in s.fields) {
          test(
            '$dialect: hostile "${f.name}" does not change the query structure',
            () {
              final payloads =
                  (f.kind == Kind.ident ? idents : values)
                      .where((p) => !(f.numeric && numericLike(p)))
                      .toList();
              final controlValue =
                  f.kind == Kind.ident ? (f.benign as String) : control;
              final expected = skeleton(
                s.sqlFor(s.with_(f, controlValue), mysql),
                mysql: mysql,
              );

              final failures = <String>[];
              for (final p in payloads) {
                String sql;
                try {
                  sql = s.sqlFor(s.with_(f, p), mysql);
                } catch (_) {
                  continue; // refusing to build the query is a safe outcome
                }
                if (skeleton(sql, mysql: mysql) != expected) {
                  failures.add(
                    'payload: ${jsonEncode(p)}\n  sql: ${shortSql(sql)}',
                  );
                }
              }
              expect(
                failures,
                isEmpty,
                reason:
                    '${failures.length} injections, first:\n${failures.take(3).join('\n')}',
              );
            },
          );
        }

        test('$dialect: ALL inputs hostile at once', () {
          final expected = skeleton(
            s.sqlFor(
              s.allHostile(
                (f) => f.kind == Kind.ident ? f.benign as String : control,
              ),
              mysql,
            ),
            mysql: mysql,
          );
          final failures = <String>[];
          for (var n = 0; n < values.length; n++) {
            if (s.fields.any((f) => f.numeric) && numericLike(values[n])) {
              continue;
            }
            final inputs = s.allHostile(
              (f) =>
                  f.kind == Kind.ident ? idents[n % idents.length] : values[n],
            );
            String sql;
            try {
              sql = s.sqlFor(inputs, mysql);
            } catch (_) {
              continue;
            }
            if (skeleton(sql, mysql: mysql) != expected) {
              failures.add('sql: ${shortSql(sql)}');
            }
          }
          expect(
            failures,
            isEmpty,
            reason:
                '${failures.length} injections, first:\n${failures.take(3).join('\n')}',
          );
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 2. Live tests
  // ---------------------------------------------------------------------------
  void liveSuite(String title, Future<Db> Function() open) {
    group('Live $title', () {
      late Db db;
      late List<String> idents;
      late String corpus;

      setUpAll(() async {
        db = await open();
        idents = identPayloads(db.q);
        await resetShop(db);
        corpus = jsonEncode(await snapshot(db)).toLowerCase();
      });
      tearDownAll(() async {
        for (final t in shopTables.reversed) {
          await db.run('DROP TABLE IF EXISTS $t');
        }
        await db.close();
      });

      /// Payloads that would *legitimately* change the result are not usable
      /// for a differential check (e.g. the LIKE input " " matches every title
      /// containing a space, the number 1 changes a numeric comparison).
      bool usable(Field f, String p) {
        if (f.numeric && numericLike(p)) return false;
        if (f.kind == Kind.like && inCorpus(corpus, p)) {
          return false;
        }
        return true;
      }

      for (final s in scenarios.where((s) => s.live)) {
        group(s.name, () {
          test('benign input works (baseline)', () async {
            final sql = s.sqlFor(s.benign, db.mysql);
            if (!s.write) {
              final rows = await db.run(sql);
              expect(rows.length, greaterThanOrEqualTo(s.minRows), reason: sql);
              expect(leaks(rows), isFalse, reason: sql);
            } else {
              await inTransaction(db, () async {
                final before = await snapshot(db);
                await db.run(sql);
                final after = await snapshot(db);
                expect(
                  jsonEncode(after),
                  isNot(jsonEncode(before)),
                  reason: 'statement changed nothing: $sql',
                );
              });
            }
          });

          for (final f in s.fields) {
            test('hostile "${f.name}" is inert', () async {
              final payloads =
                  (f.kind == Kind.ident ? idents : values)
                      .where((p) => usable(f, p))
                      .toList();
              final failures = <String>[];

              if (!s.write) {
                final benignRows = await db.run(s.sqlFor(s.benign, db.mysql));
                final cols = benignRows.isEmpty ? 0 : benignRows.first.length;
                final reference =
                    f.kind == Kind.ident
                        ? benignRows
                        : await db.run(
                          s.sqlFor(s.with_(f, f.matchAll ?? control), db.mysql),
                        );

                for (final p in payloads) {
                  String sql;
                  try {
                    sql = s.sqlFor(s.with_(f, p), db.mysql);
                  } catch (_) {
                    continue;
                  }
                  final rows = await db.attack(sql);
                  if (leaks(rows)) {
                    failures.add('LEAK payload ${jsonEncode(p)}\n  $sql');
                  } else if (f.kind == Kind.ident || f.matchAll != null) {
                    // can't compare exactly: the row set may only shrink and
                    // no extra columns may appear
                    if (rows.length > reference.length ||
                        rows.any((r) => r.length != cols)) {
                      failures.add(
                        'EXTRA ROWS/COLUMNS payload ${jsonEncode(p)}\n  $sql',
                      );
                    }
                  } else if (rowsJson(normalizeRows(rows, p, control)) !=
                      rowsJson(normalizeRows(reference, p, control))) {
                    failures.add(
                      'RESULT DIFFERS payload ${jsonEncode(p)}\n  $sql',
                    );
                  }
                }
              } else {
                await inTransaction(db, () async {
                  final before = await snapshot(db);

                  // state produced by the harmless input (or by "match all")
                  Snapshot? reference;
                  if (f.kind != Kind.ident) {
                    await db.run('SAVEPOINT ref');
                    await db.run(
                      s.sqlFor(s.with_(f, f.matchAll ?? control), db.mysql),
                    );
                    reference = await snapshot(db);
                    await db.run('ROLLBACK TO SAVEPOINT ref');
                  }

                  for (final p in payloads) {
                    String sql;
                    try {
                      sql = s.sqlFor(s.with_(f, p), db.mysql);
                    } catch (_) {
                      continue;
                    }
                    await db.run('SAVEPOINT sp');
                    await db.attack(sql);
                    final after = await snapshot(db);
                    await db.run('ROLLBACK TO SAVEPOINT sp');

                    if (f.kind == Kind.ident) {
                      if (jsonEncode(after) != jsonEncode(before)) {
                        failures.add(
                          'DATABASE CHANGED payload ${jsonEncode(p)}\n  $sql',
                        );
                      }
                    } else if (f.matchAll != null) {
                      if (!stateBetween(
                        normalize(before, p, control),
                        normalize(after, p, control),
                        normalize(reference!, p, control),
                      )) {
                        failures.add(
                          'COLLATERAL CHANGES payload ${jsonEncode(p)}\n  $sql',
                        );
                      }
                    } else if (jsonEncode(normalize(after, p, control)) !=
                        jsonEncode(normalize(reference!, p, control))) {
                      failures.add(
                        'STATE DIFFERS payload ${jsonEncode(p)}\n  $sql',
                      );
                    }
                  }
                });
              }

              expect(
                failures,
                isEmpty,
                reason:
                    '${failures.length}/${payloads.length} payloads got through, first:\n'
                    '${failures.take(3).join('\n')}',
              );
            });
          }

          test('ALL inputs hostile at once', () async {
            final failures = <String>[];
            final hasLike = s.fields.any((f) => f.kind == Kind.like);

            Inputs hostile(String p) => s.allHostile(
              (f) => f.kind == Kind.ident ? f.benign as String : p,
            );

            await inTransaction(db, () async {
              final before = await snapshot(db);
              for (final p in values) {
                if (hasLike && inCorpus(corpus, p)) {
                  continue;
                }
                final sql = s.sqlFor(hostile(p), db.mysql);
                await db.run('SAVEPOINT sp');
                final rows = await db.attack(sql);
                final after = await snapshot(db);
                await db.run('ROLLBACK TO SAVEPOINT sp');

                if (leaks(rows)) {
                  failures.add('LEAK payload ${jsonEncode(p)}\n  $sql');
                }
                // nothing outside the table(s) the statement is meant for may change
                for (final t in shopTables) {
                  if (s.targets.contains(t)) continue;
                  if (jsonEncode(after[t]) != jsonEncode(before[t])) {
                    failures.add('$t CHANGED payload ${jsonEncode(p)}\n  $sql');
                  }
                }
              }
            });
            expect(
              failures,
              isEmpty,
              reason:
                  '${failures.length} payloads got through, first:\n${failures.take(3).join('\n')}',
            );
          });
        });
      }

      // -----------------------------------------------------------------------
      // Second-order injection: hostile text is stored first, then read back
      // from the database and used to build further queries.
      // -----------------------------------------------------------------------
      test(
        'second-order: stored payloads round-trip and are safe to reuse',
        () async {
          final failures = <String>[];
          for (final p in values) {
            await inTransaction(db, () async {
              await db.run(
                db.sql(
                  Sqler().insert(QField('shop_audit'), [
                    {'actor': QVar(p), 'action': QVar('login')},
                  ]),
                ),
              );
              final stored =
                  (await db.run(
                    'SELECT actor FROM shop_audit ORDER BY id DESC LIMIT 1',
                  )).first['actor'];
              if (stored != p) {
                failures.add(
                  'stored value differs for ${jsonEncode(p)}: ${jsonEncode(stored)}',
                );
                return;
              }

              final found = await db.run(
                db.sql(
                  Sqler()
                      .addSelect(QSelect('id'))
                      .from(QField('shop_audit'))
                      .whereOne(QField('actor'), QO.EQ, QVar(stored)),
                ),
              );
              if (found.length != 1) {
                failures.add(
                  'lookup of ${jsonEncode(p)} found ${found.length} rows',
                );
              }

              await db.run(
                db.sql(
                  Sqler()
                      .update(QField('shop_audit'))
                      .updateSet('action', QVar('seen'))
                      .whereOne(QField('actor'), QO.EQ, QVar(stored)),
                ),
              );
              final seen = await db.run(
                "SELECT COUNT(*) AS c FROM shop_audit WHERE action = 'seen'",
              );
              if (seen.first['c'] != '1') {
                failures.add(
                  'UPDATE by stored ${jsonEncode(p)} touched ${seen.first['c']} rows',
                );
              }

              await db.run(
                db.sql(
                  Sqler()
                      .delete()
                      .from(QField('shop_audit'))
                      .whereOne(QField('actor'), QO.EQ, QVar(stored)),
                ),
              );
              final left = await db.run('SELECT COUNT(*) AS c FROM shop_audit');
              if (left.first['c'] != '2') {
                failures.add(
                  'DELETE by stored ${jsonEncode(p)} left ${left.first['c']} rows',
                );
              }
            });
          }
          expect(failures, isEmpty, reason: failures.take(5).join('\n'));
        },
      );
    });
  }

  liveSuite('MySQL', openMysql);
  liveSuite('SQLite (in-memory)', () async => openSqlite());
}
