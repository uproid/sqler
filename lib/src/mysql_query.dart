import 'package:intl/intl.dart';

/// SQL Query Builder Library for MySQL
///
/// This library provides a comprehensive set of classes for building SQL queries
/// programmatically using a fluent interface. It supports all major SQL operations
/// including SELECT, INSERT, UPDATE, DELETE, and complex operations like JOINs,
/// subqueries, and conditional expressions.
///
/// Key features:
/// - Fluent interface with method chaining
/// - Type-safe query construction
/// - Support for parameterized queries
/// - Comprehensive WHERE clause building
/// - JOIN operations (INNER, LEFT, RIGHT)
/// - Aggregate functions and mathematical expressions
/// - CASE statements and subqueries
/// - Proper SQL escaping and formatting
///
/// Main classes:
/// - [Sqler]: The main query builder class
/// - [QField]: Represents database fields with proper quoting
/// - [QVar]: Represents values with proper escaping
/// - [Where]: Base class for WHERE conditions
/// - [Join]: Represents JOIN operations
/// - [QOrder]: Represents ORDER BY specifications
///
/// Example usage:
/// ```dart
/// var query = Sqler()
///   .addSelect(QSelect('users.name'))
///   .addSelect(QSelect('profiles.bio'))
///   .from(QField('users'))
///   .join(LeftJoin('profiles', On([
///     Condition(QField('users.id'), QO.EQ, QField('profiles.user_id'))
///   ])))
///   .where(WhereOne(QField('users.active'), QO.EQ, QVar(true)))
///   .orderBy(QOrder('users.name'))
///   .limit(10);
///
/// String sql = query.toSQL();
/// // Generates: SELECT `users`.`name`, `profiles`.`bio` FROM `users`
/// //           LEFT JOIN `profiles` ON ( ( `users`.`id` = `profiles`.`user_id` ) )
/// //           WHERE ( `users`.`active` = true ) ORDER BY `users`.`name` ASC LIMIT 10
/// ```

/// A SQL query builder for MySQL that provides a fluent interface for constructing
/// SQL statements including SELECT, INSERT, UPDATE, and DELETE operations.
///
/// The [Sqler] class implements the builder pattern, allowing method chaining
/// to construct complex SQL queries programmatically. It supports all major SQL
/// operations including joins, where clauses, grouping, ordering, and parameterized queries.
///
/// Example usage:
/// ```dart
/// var query = Sqler()
///   .addSelect(QSelect('name'))
///   .addSelect(QSelect('email'))
///   .from(QField('users'))
///   .where(WhereOne(QField('active'), QO.EQ, QVar(true)))
///   .orderBy(QOrder('name'))
///   .limit(10);
///
/// String sql = query.toSQL(); // Generates: SELECT `name`, `email` FROM `users` WHERE ( `active` = true ) ORDER BY `name` ASC LIMIT 10
/// ```
class Sqler implements SQL {
  /// List of fields to select in SELECT queries
  List<QSelectField> _select = [];

  /// Flag indicating if this is a DELETE operation
  bool _delete = false;

  /// List of tables/sources for FROM clause
  List<QField> _from = [];

  /// List of WHERE conditions
  List<Where> _where = [];

  /// Map of named parameters for parameterized queries
  Map<String, QVar> _params = {};

  /// List of fields for GROUP BY clause
  List<QField> _groupBy = [];

  /// List of HAVING conditions
  List<Having> _having = [];

  /// List of ORDER BY specifications
  List<QOrder> _orderBy = [];

  /// LIMIT clause configuration
  Limit _limit = Limit();

  /// List of JOIN operations
  List<Join> _joins = [];

  /// List of values for INSERT operations
  List<Map<String, QVar>> _insert = [];

  /// Map of field-value pairs for UPDATE operations
  Map<String, QVar> _update = {};

  /// Creates a new instance of [Sqler] query builder.
  ///
  /// All internal collections are initialized as empty, ready for building a query.
  Sqler();

  /// Clears all SELECT fields from the query.
  ///
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.clearSelect(); // Removes all previously added SELECT fields
  /// ```
  Sqler clearSelect() {
    _select = [];
    return this;
  }

  /// Clears all FROM tables from the query.
  ///
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.clearFrom(); // Removes all FROM tables
  /// ```
  Sqler clearFrom() {
    _from = [];
    return this;
  }

  /// Clears all WHERE conditions from the query.
  ///
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.clearWhere(); // Removes all WHERE conditions
  /// ```
  Sqler clearWhere() {
    _where = [];
    return this;
  }

  /// Clears all parameters from the query.
  ///
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.clearParams(); // Removes all named parameters
  /// ```
  Sqler clearParams() {
    _params = {};
    return this;
  }

  /// Clears all GROUP BY fields from the query.
  ///
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.clearGroupBy(); // Removes all GROUP BY fields
  /// ```
  Sqler clearGroupBy() {
    _groupBy = [];
    return this;
  }

  /// Clears all HAVING conditions from the query.
  ///
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.clearHaving(); // Removes all HAVING conditions
  /// ```
  Sqler clearHaving() {
    _having = [];
    return this;
  }

  /// Clears all ORDER BY specifications from the query.
  ///
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.clearOrderBy(); // Removes all ORDER BY fields
  /// ```
  Sqler clearOrderBy() {
    _orderBy = [];
    return this;
  }

  /// Clears the LIMIT clause from the query.
  ///
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.clearLimit(); // Removes LIMIT and OFFSET
  /// ```
  Sqler clearLimit() {
    _limit = Limit();
    return this;
  }

  /// Clears all JOIN operations from the query.
  ///
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.clearJoins(); // Removes all JOIN clauses
  /// ```
  Sqler clearJoins() {
    _joins = [];
    return this;
  }

  /// Clears all INSERT values from the query.
  ///
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.clearInsert(); // Removes all INSERT values
  /// ```
  Sqler clearInsert() {
    _insert = [];
    return this;
  }

  /// Clears all UPDATE field-value pairs from the query.
  ///
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.clearUpdate(); // Removes all UPDATE SET clauses
  /// ```
  Sqler clearUpdate() {
    _update = {};
    return this;
  }

  /// Clears the DELETE flag from the query.
  ///
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.clearDelete(); // Removes DELETE operation flag
  /// ```
  Sqler clearDelete() {
    _delete = false;
    return this;
  }

  /// Removes a specific SELECT field from the query by comparing SQL output.
  ///
  /// [select] The SELECT field to remove.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.removeSelect(QSelect('name')); // Removes the name field from SELECT
  /// ```
  Sqler removeSelect(QSelectField select) {
    _select.removeWhere((e) => e.toSQL() == select.toSQL());
    return this;
  }

  /// Removes a specific FROM table from the query by comparing SQL output.
  ///
  /// [from] The table to remove from FROM clause.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.removeFrom(QField('users')); // Removes users table from FROM
  /// ```
  Sqler removeFrom(QField from) {
    _from.removeWhere((e) => e.toSQL() == from.toSQL());
    return this;
  }

  /// Removes a specific WHERE condition from the query by comparing SQL output.
  ///
  /// [where] The WHERE condition to remove.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.removeWhere(WhereOne(QField('active'), QO.EQ, QVar(true))); // Removes this WHERE condition
  /// ```
  Sqler removeWhere(Where where) {
    _where.removeWhere((e) => e.toSQL() == where.toSQL());
    return this;
  }

  /// Removes a parameter from the query by its key.
  ///
  /// [key] The parameter key to remove.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.removeParam('userId'); // Removes the userId parameter
  /// ```
  Sqler removeParam(String key) {
    _params.remove(key);
    return this;
  }

  /// Removes a specific GROUP BY field from the query by comparing SQL output.
  ///
  /// [groupBy] The GROUP BY field to remove.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.removeGroupBy(QField('category')); // Removes category from GROUP BY
  /// ```
  Sqler removeGroupBy(QField groupBy) {
    _groupBy.removeWhere((e) => e.toSQL() == groupBy.toSQL());
    return this;
  }

  /// Removes a specific HAVING condition from the query by comparing SQL output.
  ///
  /// [having] The HAVING condition to remove.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.removeHaving(Having([Condition(QField('COUNT(*)'), QO.GT, QVar(5))])); // Removes this HAVING condition
  /// ```
  Sqler removeHaving(Having having) {
    _having.removeWhere((e) => e.toSQL() == having.toSQL());
    return this;
  }

  /// Removes a specific ORDER BY specification from the query by comparing SQL output.
  ///
  /// [orderBy] The ORDER BY specification to remove.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.removeOrderBy(QOrder('name')); // Removes name from ORDER BY
  /// ```
  Sqler removeOrderBy(QOrder orderBy) {
    _orderBy.removeWhere((e) => e.toSQL() == orderBy.toSQL());
    return this;
  }

  /// Removes a specific JOIN operation from the query by comparing SQL output.
  ///
  /// [join] The JOIN operation to remove.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.removeJoin(Join('orders', On([Condition(QField('users.id'), QO.EQ, QField('orders.user_id'))]))); // Removes this JOIN
  /// ```
  Sqler removeJoin(Join join) {
    _joins.removeWhere((e) => e.toSQL() == join.toSQL());
    return this;
  }

  /// Removes a specific INSERT value set from the query.
  ///
  /// [insert] The INSERT value map to remove.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.removeInsert({'name': QVar('John'), 'email': QVar('john@example.com')}); // Removes this INSERT value set
  /// ```
  Sqler removeInsert(Map<String, dynamic> insert) {
    _insert.removeWhere((e) => e == insert);
    return this;
  }

  /// Removes a specific field from the UPDATE SET clause.
  ///
  /// [field] The field name to remove from UPDATE.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.removeUpdate('email'); // Removes email field from UPDATE SET
  /// ```
  Sqler removeUpdate(String field) {
    _update.remove(field);
    return this;
  }

  /// Creates a copy of this query with optional overrides for specific properties.
  ///
  /// This method implements the copy-with pattern, allowing you to create a new
  /// [Sqler] instance based on the current one but with some properties modified.
  /// Any parameter that is `null` will use the value from the current instance.
  ///
  /// Returns a new [Sqler] instance with the specified modifications.
  ///
  /// Example:
  /// ```dart
  /// var baseQuery = Sqler().from(QField('users'));
  /// var modifiedQuery = baseQuery.copyWith(
  ///   selects: [QSelect('name'), QSelect('email')],
  ///   limit: Limit(0, 10)
  /// ); // Creates a new query with different SELECT and LIMIT
  /// ```
  Sqler copyWith({
    List<QSelectField>? selects,
    bool? delete,
    List<QField>? from,
    List<Where>? where,
    Map<String, QVar>? params,
    List<QField>? groupBy,
    List<Having>? having,
    List<QOrder>? orderBy,
    Limit? limit,
    List<Join>? joins,
    List<Map<String, QVar>>? insert,
    Map<String, QVar>? update,
  }) {
    var newQuery = Sqler();
    newQuery._select = selects ?? _select;
    newQuery._delete = delete ?? _delete;
    newQuery._from = from ?? _from;
    newQuery._where = where ?? _where;
    newQuery._params = params ?? _params;
    newQuery._groupBy = groupBy ?? _groupBy;
    newQuery._having = having ?? _having;
    newQuery._orderBy = orderBy ?? _orderBy;
    newQuery._limit = limit ?? _limit;
    newQuery._joins = joins ?? _joins;
    newQuery._insert = insert ?? _insert;
    newQuery._update = update ?? _update;

    return newQuery;
  }

  /// Adds multiple SELECT fields to the query.
  ///
  /// [select] List of SELECT fields to add.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.selects([QSelect('name'), QSelect('email'), QSelectAll()]); // Adds multiple SELECT fields
  /// ```
  Sqler selects(List<QSelectField> select) {
    _select.addAll(select);
    return this;
  }

  /// Sets up the query for an UPDATE operation on the specified table.
  ///
  /// [table] The table to update.
  /// Returns [this] to enable method chaining.
  ///
  /// Note: This clears any existing FROM tables and sets the specified table
  /// as the single target for the UPDATE operation.
  ///
  /// Example:
  /// ```dart
  /// query.update(QField('users')); // Sets up UPDATE operation on users table
  /// ```
  Sqler update(QField table) {
    _from = [table];
    return this;
  }

  // THIS ONE USED FOR WEBAPP PACKAGE
  // Q updateTable(MTable table) {
  //   _from = [QField(table.name)];
  //   return this;
  // }

  /// Adds a field-value pair to the UPDATE SET clause.
  ///
  /// [field] The field name to update.
  /// [value] The new value for the field.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.updateSet('name', QVar('John Doe')); // Sets name = 'John Doe' in UPDATE
  /// ```
  Sqler updateSet(String field, QVar value) {
    _update[field] = value;
    return this;
  }

  /// Sets the query to be a DELETE operation.
  ///
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.delete().from(QField('users')); // Creates DELETE FROM users query
  /// ```
  Sqler delete() {
    _delete = true;
    return this;
  }

  /// Adds a single SELECT field to the query.
  ///
  /// [select] The SELECT field to add.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.addSelect(QSelect('name')); // Adds name field to SELECT
  /// ```
  Sqler addSelect(QSelectField select) {
    _select.add(select);
    return this;
  }

  /// Adds a table or source to the FROM clause.
  ///
  /// [from] The table or source to add.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.from(QField('users')); // Adds users table to FROM clause
  /// ```
  Sqler from(QField from) {
    _from.add(from);
    return this;
  }

  // THIS ONE USED FOR WEBAPP PACKAGE
  // Q fromTable(MTable table) {
  //   _from.add(QField(table.name));
  //   return this;
  // }

  /// Adds a WHERE condition to the query.
  ///
  /// [where] The WHERE condition to add.
  /// Returns [this] to enable method chaining.
  ///
  /// Multiple WHERE conditions are combined with AND.
  ///
  /// Example:
  /// ```dart
  /// query.where(WhereOne(QField('active'), QO.EQ, QVar(true))); // WHERE active = true
  /// ```
  Sqler where(Where where) {
    _where.add(where);
    return this;
  }

  /// Checks if the query has any WHERE conditions.
  bool hasWhere() {
    return _where.isNotEmpty;
  }

  /// Checks if the query has any SELECT fields.
  bool hasSelect() {
    return _select.isNotEmpty;
  }

  /// Checks if the query has any FROM tables.
  bool hasFrom() {
    return _from.isNotEmpty;
  }

  /// Checks if the query has any JOIN operations.
  bool hasJoins() {
    return _joins.isNotEmpty;
  }

  /// Checks if the query has any GROUP BY fields.
  bool hasGroupBy() {
    return _groupBy.isNotEmpty;
  }

  /// Checks if the query has any HAVING conditions.
  bool hasHaving() {
    return _having.isNotEmpty;
  }

  /// Checks if the query has any ORDER BY specifications.
  bool hasOrderBy() {
    return _orderBy.isNotEmpty;
  }

  /// Checks if the query has a LIMIT clause.
  bool hasLimit() {
    return _limit.limit != null && _limit.offset != null;
  }

  /// Checks if the query has any INSERT values.
  bool hasInsert() {
    return _insert.isNotEmpty;
  }

  /// Checks if the query has any UPDATE field-value pairs.
  bool hasUpdate() {
    return _update.isNotEmpty;
  }

  /// Checks if the query is a DELETE operation.
  bool isDelete() {
    return _delete;
  }

  /// Adds multiple parameters to the query for parameterized queries.
  ///
  /// [params] Map of parameter key-value pairs to add.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.addParams({'userId': QVar(123), 'status': QVar('active')}); // Adds multiple parameters
  /// ```
  Sqler addParams(Map<String, QVar> params) {
    _params.addAll(params);
    return this;
  }

  /// Adds a single parameter to the query for parameterized queries.
  ///
  /// [key] The parameter key.
  /// [value] The parameter value.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.addParam('userId', QVar(123)); // Adds userId parameter
  /// ```
  Sqler addParam(String key, QVar value) {
    _params[key] = value;
    return this;
  }

  /// Adds an ORDER BY specification to the query.
  ///
  /// [orderBy] The ORDER BY specification to add.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.orderBy(QOrder('name')); // ORDER BY name ASC
  /// query.orderBy(QOrder('created_at', desc: true)); // ORDER BY created_at DESC
  /// ```
  Sqler orderBy(QOrder orderBy) {
    _orderBy.add(orderBy);
    return this;
  }

  /// Sets the LIMIT and optional OFFSET for the query.
  ///
  /// [limit] The maximum number of rows to return.
  /// [offset] Optional offset for pagination.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.limit(10); // LIMIT 10
  /// query.limit(10, 20); // LIMIT 10 OFFSET 20
  /// ```
  Sqler limit(int limit, [int? offset]) {
    _limit.limit = limit;
    _limit.offset = offset;
    return this;
  }

  /// Sets the GROUP BY fields for the query.
  ///
  /// [groupBy] List of field names to group by.
  /// Returns [this] to enable method chaining.
  ///
  /// Note: This replaces any existing GROUP BY fields.
  ///
  /// Example:
  /// ```dart
  /// query.groupBy(['category', 'status']); // GROUP BY category, status
  /// ```
  Sqler groupBy(List<String> groupBy) {
    _groupBy = groupBy.map((e) => QField(e)).toList();
    return this;
  }

  /// Adds a HAVING condition to the query.
  ///
  /// [having] The HAVING condition to add.
  /// Returns [this] to enable method chaining.
  ///
  /// HAVING is used with GROUP BY to filter grouped results.
  ///
  /// Example:
  /// ```dart
  /// query.having(Having([Condition(QField('COUNT(*)'), QO.GT, QVar(5))])); // HAVING COUNT(*) > 5
  /// ```
  Sqler having(Having having) {
    _having.add(having);
    return this;
  }

  /// Adds a JOIN operation to the query.
  ///
  /// [join] The JOIN operation to add.
  /// Returns [this] to enable method chaining.
  ///
  /// Example:
  /// ```dart
  /// query.join(Join('orders', On([Condition(QField('users.id'), QO.EQ, QField('orders.user_id'))]))); // JOIN orders ON users.id = orders.user_id
  /// ```
  Sqler join(Join join) {
    _joins.add(join);
    return this;
  }

  /// Sets up the query for an INSERT operation with the specified values.
  ///
  /// [table] The table to insert into.
  /// [values] List of field-value maps to insert.
  /// Returns [this] to enable method chaining.
  ///
  /// Note: This sets the FROM table and adds the values for insertion.
  ///
  /// Example:
  /// ```dart
  /// query.insert(QField('users'), [
  ///   {'name': QVar('John'), 'email': QVar('john@example.com')},
  ///   {'name': QVar('Jane'), 'email': QVar('jane@example.com')}
  /// ]); // INSERT INTO users (name, email) VALUES ('John', 'john@example.com'), ('Jane', 'jane@example.com')
  /// ```
  Sqler insert(QField table, List<Map<String, QVar>> values) {
    _from = [table];
    _insert.addAll(values);
    return this;
  }

  /// Generates the final SQL string from the query configuration.
  ///
  /// This method builds the complete SQL statement based on all the configured
  /// elements of the query. It handles INSERT, UPDATE, DELETE, and SELECT operations
  /// with their respective clauses.
  ///
  /// The method processes elements in the correct SQL order:
  /// - INSERT/UPDATE/DELETE/SELECT clause
  /// - FROM clause
  /// - JOIN clauses
  /// - WHERE clause
  /// - GROUP BY clause
  /// - HAVING clause
  /// - ORDER BY clause
  /// - LIMIT clause
  /// - Parameter substitution
  ///
  /// Returns the complete SQL string ready for execution.
  ///
  /// Throws [Exception] if UPDATE or DELETE operations don't have exactly one table.
  ///
  /// Example:
  /// ```dart
  /// var query = Sqler()
  ///   .addSelect(QSelect('name'))
  ///   .from(QField('users'))
  ///   .where(WhereOne(QField('active'), QO.EQ, QVar(true)));
  ///
  /// String sql = query.toSQL(); // "SELECT `name` FROM `users` WHERE ( `active` = true )"
  /// ```
  @override
  String toSQL() {
    if (_insert.isNotEmpty) {
      var sql = 'INSERT INTO ${_from.first.toSQL()} ';
      sql +=
          '(${_insert.first.keys.map((e) => QField(e).toSQL()).join(', ')}) ';
      sql += 'VALUES';

      for (var i = 0; i < _insert.length; i++) {
        var values = _insert[i].values
            .map((e) {
              return e.toSQL();
            })
            .join(', ');
        sql += ' ($values)';
        if (i != _insert.length - 1) {
          sql += ',';
        }
      }

      return sql;
    }
    String sql = '';

    if (_update.isNotEmpty) {
      if (_from.isEmpty || _from.length > 1) {
        throw Exception('Update operation requires exactly one table.');
      }
      sql = 'UPDATE ${_from.first.toSQL()}';
    } else if (_delete) {
      if (_from.isEmpty || _from.length > 1) {
        throw Exception('Delete operation requires exactly one table.');
      }
      sql = 'DELETE FROM ${_from[0].toSQL()}';
    } else {
      sql =
          'SELECT ${_select.map((e) => e.toSQL()).join(', ')} FROM ${_from.map((e) => e.toSQL()).join(', ')}';
    }

    // Joins
    if (_joins.isNotEmpty) {
      for (var join in _joins) {
        sql += ' ${join.toSQL()}';
      }
    }

    if (_update.isNotEmpty) {
      sql += ' SET ';
      sql += _update.entries
          .map((e) => '${QField(e.key).toSQL()} = ${e.value.toSQL()}')
          .join(', ');
    }

    // Where
    if (_where.isNotEmpty) {
      sql += ' WHERE ';
      sql += _where.map((e) => e.toSQL()).join(' AND ');
    }

    // Group by
    if (_groupBy.isNotEmpty) {
      sql += ' GROUP BY ${_groupBy.map((e) => e.toSQL()).join(', ')}';
    }

    // Having
    if (_having.isNotEmpty) {
      sql += ' HAVING ';
      for (int i = 0; i < _having.length; i++) {
        sql += _having[i].toSQL();
      }
    }

    // Order by
    if (_orderBy.isNotEmpty) {
      sql += ' ORDER BY ${_orderBy.map((e) => e.toSQL()).join(', ')}';
    }

    // Limit
    if (_limit.limit != null) {
      sql += _limit.toSQL();
    }

    if (_params.isNotEmpty) {
      for (var key in _params.keys) {
        var value = _params[key]!.toSQL();
        sql = sql.replaceAll('{$key}', value.toString());
      }
    }

    return sql;
  }
}

/// Represents an ORDER BY clause specification with field name and sort direction.
///
/// The [QOrder] class encapsulates the field to sort by and whether the sort
/// should be in descending order. It implements the [SQL] interface to generate
/// the appropriate SQL fragment.
///
/// Example usage:
/// ```dart
/// var order1 = QOrder('name'); // ORDER BY `name` ASC
/// var order2 = QOrder('created_at', desc: true); // ORDER BY `created_at` DESC
/// ```
class QOrder implements SQL {
  /// The field to order by
  QField field;

  /// Whether to sort in descending order (default is false for ascending)
  bool desc;

  /// Creates a new ORDER BY specification.
  ///
  /// [field] The field name to sort by.
  /// [desc] Optional flag for descending order (default is false for ascending).
  ///
  /// Example:
  /// ```dart
  /// var order = QOrder('name', desc: true); // Creates descending order by name
  /// ```
  QOrder(String field, {this.desc = false}) : field = QField(field);

  /// Generates the SQL fragment for this ORDER BY specification.
  ///
  /// Returns a string like "`field_name` ASC" or "`field_name` DESC".
  ///
  /// Example:
  /// ```dart
  /// QOrder('name').toSQL(); // "`name` ASC"
  /// QOrder('created_at', desc: true).toSQL(); // "`created_at` DESC"
  /// ```
  @override
  String toSQL() {
    return '${field.toSQL()} ${desc ? 'DESC' : 'ASC'}';
  }
}

/// Abstract base class for all SELECT field types.
///
/// Implementations of this class represent different types of fields that can
/// appear in a SELECT clause, such as regular fields, wildcard selects, or
/// custom expressions.
///
/// All implementations must provide a [toSQL] method that returns the SQL
/// representation of the field.
abstract class QSelectField implements SQL {
  @override
  String toSQL();
}

/// Represents a SELECT * (wildcard) field that selects all columns.
///
/// This is used when you want to select all columns from the table(s) in the query.
///
/// Example usage:
/// ```dart
/// var selectAll = QSelectAll(); // Generates: *
/// ```
class QSelectAll implements QSelectField {
  /// Creates a SELECT * field specification.
  QSelectAll();

  /// Returns the SQL wildcard "*" for selecting all columns.
  @override
  String toSQL() => '*';
}

/// Represents a custom SELECT field with optional alias.
///
/// This class wraps another [QSelectField] and optionally provides an alias for it.
/// It's useful for creating complex field expressions with custom names.
///
/// Example usage:
/// ```dart
/// var customField = QSelectCustom(QSelect('name'), as: 'full_name'); // `name` AS `full_name`
/// var customField2 = QSelectCustom(QMath('COUNT(*)')); // COUNT(*)
/// ```
class QSelectCustom implements QSelectField {
  /// The underlying field to select
  QSelectField field;

  /// Optional alias for the field
  String as;

  /// Creates a custom SELECT field with optional alias.
  ///
  /// [field] The underlying field to select.
  /// [as] Optional alias name for the field.
  QSelectCustom(this.field, {this.as = ''});

  /// Generates the SQL for this custom field with optional alias.
  ///
  /// Returns the field SQL with "AS alias" if an alias is provided,
  /// otherwise just the field SQL.
  ///
  /// Example:
  /// ```dart
  /// QSelectCustom(QSelect('name'), as: 'full_name').toSQL(); // "`name` AS `full_name`"
  /// QSelectCustom(QMath('COUNT(*)')).toSQL(); // "COUNT(*)"
  /// ```
  @override
  String toSQL() {
    return as.isNotEmpty
        ? '${field.toSQL()} AS ${QField(as).toSQL()}'
        : field.toSQL();
  }
}

/// Represents a mathematical expression or function in a SELECT clause.
///
/// This class allows embedding raw SQL mathematical expressions, aggregate functions,
/// or any custom SQL expressions in the SELECT clause.
///
/// Example usage:
/// ```dart
/// var count = QMath('COUNT(*)'); // COUNT(*)
/// var sum = QMath('SUM(price)'); // SUM(price)
/// var calc = QMath('price * quantity'); // price * quantity
/// ```
class QMath implements QSelectField {
  /// The mathematical expression or function as raw SQL
  String math;

  /// Creates a mathematical/functional SELECT field.
  ///
  /// [math] The raw SQL expression (e.g., 'COUNT(*)', 'SUM(price)', etc.).
  QMath(this.math);

  /// Returns the raw mathematical expression as-is.
  ///
  /// Example:
  /// ```dart
  /// QMath('COUNT(*)').toSQL(); // "COUNT(*)"
  /// ```
  @override
  String toSQL() {
    return math;
  }
}

/// Represents a standard field selection with optional alias.
///
/// This is the most common type of SELECT field, representing a single column
/// from a table with an optional alias.
///
/// Example usage:
/// ```dart
/// var field1 = QSelect('name'); // `name`
/// var field2 = QSelect('email', as: 'user_email'); // `email` AS `user_email`
/// ```
class QSelect implements QSelectField {
  /// The field name to select
  String field;

  /// Optional alias for the field
  String as;

  /// Creates a standard SELECT field with optional alias.
  ///
  /// [field] The field name to select.
  /// [as] Optional alias name for the field.
  QSelect(this.field, {this.as = ''});

  /// Generates the SQL for this field with optional alias.
  ///
  /// Returns the field name (properly quoted) with "AS alias" if an alias is provided.
  ///
  /// Example:
  /// ```dart
  /// QSelect('name').toSQL(); // "`name`"
  /// QSelect('email', as: 'user_email').toSQL(); // "`email` AS `user_email`"
  /// ```
  @override
  String toSQL() {
    return as.isNotEmpty
        ? '${QField(field).toSQL()} AS ${QField(as).toSQL()}'
        : QField(field).toSQL();
  }
}

/// Abstract base class for WHERE clause conditions.
///
/// The [Where] class provides the foundation for building WHERE conditions
/// in SQL queries. It can contain multiple SQL conditions that are combined
/// with AND by default.
///
/// Subclasses can override the [toSQL] method to implement different
/// combination logic (e.g., OR, custom grouping).
///
/// Example usage:
/// ```dart
/// // Used indirectly through concrete implementations like WhereOne, OrWhere, etc.
/// ```
abstract class Where implements SQL {
  /// List of SQL conditions contained in this WHERE clause
  List<SQL> _whereBodies = [];

  /// Creates a WHERE clause with optional initial conditions.
  ///
  /// [whereBodies] Optional list of initial SQL conditions.
  Where([List<SQL>? whereBodies]) {
    if (whereBodies != null) {
      _whereBodies.addAll(whereBodies);
    }
  }

  /// Generates SQL by combining all conditions with AND.
  ///
  /// Each condition is wrapped in parentheses and joined with " AND ".
  /// Subclasses can override this to implement different combination logic.
  ///
  /// Returns the combined SQL string for all conditions.
  @override
  String toSQL() {
    var sql = <String>[];
    for (int i = 0; i < _whereBodies.length; i++) {
      sql.add('( ${_whereBodies[i].toSQL()} )');
    }
    return sql.join(' AND ');
  }
}

/// Represents a simple WHERE condition with a single comparison.
///
/// This is the most common type of WHERE clause, representing a single
/// condition like "field = value" or "field > value".
///
/// Example usage:
/// ```dart
/// var where = WhereOne(QField('age'), QO.GT, QVar(18)); // WHERE ( age > 18 )
/// var where2 = WhereOne(QField('status'), QO.EQ, QVar('active')); // WHERE ( status = 'active' )
/// ```
class WhereOne extends Where {
  /// Creates a simple WHERE condition with left operand, operator, and right operand.
  ///
  /// [left] The left side of the condition (usually a field).
  /// [operator] The comparison operator.
  /// [right] The right side of the condition (usually a value).
  WhereOne(SQL left, QO operator, SQL right)
    : super([Condition(left, operator, right)]);

  /// Returns the SQL for the single condition without extra parentheses.
  ///
  /// Example:
  /// ```dart
  /// WhereOne(QField('age'), QO.GT, QVar(18)).toSQL(); // "( `age` > 18 )"
  /// ```
  @override
  String toSQL() {
    return _whereBodies.first.toSQL();
  }
}

/// Represents a WHERE clause that combines multiple conditions with OR.
///
/// This class is used when you need any of several conditions to be true,
/// rather than all conditions (which would use AND).
///
/// Example usage:
/// ```dart
/// var orWhere = OrWhere([
///   Condition(QField('status'), QO.EQ, QVar('active')),
///   Condition(QField('status'), QO.EQ, QVar('pending'))
/// ]); // WHERE ( ( status = 'active' ) OR ( status = 'pending' ) )
/// ```
class OrWhere extends Where {
  /// Creates an OR WHERE clause with optional initial conditions.
  ///
  /// [whereBodies] Optional list of initial SQL conditions to combine with OR.
  OrWhere([List<SQL>? whereBodies]) : super(whereBodies) {
    _whereBodies = whereBodies ?? [];
  }

  /// Generates SQL by combining all conditions with OR.
  ///
  /// Each condition is wrapped in parentheses and joined with " OR ".
  ///
  /// Returns the combined SQL string with OR logic.
  ///
  /// Example:
  /// ```dart
  /// // Returns: "( condition1 ) OR ( condition2 ) OR ( condition3 )"
  /// ```
  @override
  String toSQL() {
    var sql = <String>[];
    for (int i = 0; i < _whereBodies.length; i++) {
      sql.add('( ${_whereBodies[i].toSQL()} )');
    }
    return sql.join(' OR ');
  }
}

/// Represents a WHERE clause that combines multiple conditions with AND.
///
/// This class explicitly combines conditions with AND logic, which is the same
/// as the default behavior of the base [Where] class. It's provided for
/// explicit clarity when building complex conditions.
///
/// Example usage:
/// ```dart
/// var andWhere = AndWhere([
///   Condition(QField('age'), QO.GTE, QVar(18)),
///   Condition(QField('status'), QO.EQ, QVar('active'))
/// ]); // WHERE ( ( age >= 18 ) AND ( status = 'active' ) )
/// ```
class AndWhere extends Where {
  /// Creates an AND WHERE clause with optional initial conditions.
  ///
  /// [whereBodies] Optional list of initial SQL conditions to combine with AND.
  AndWhere([List<SQL>? whereBodies]) : super(whereBodies) {
    _whereBodies = whereBodies ?? [];
  }

  /// Generates SQL by combining all conditions with AND.
  ///
  /// Each condition is wrapped in parentheses and joined with " AND ".
  ///
  /// Returns the combined SQL string with AND logic.
  ///
  /// Example:
  /// ```dart
  /// // Returns: "( condition1 ) AND ( condition2 ) AND ( condition3 )"
  /// ```
  @override
  String toSQL() {
    var sql = <String>[];
    for (int i = 0; i < _whereBodies.length; i++) {
      sql.add('( ${_whereBodies[i].toSQL()} )');
    }
    return sql.join(' AND ');
  }
}

/// Represents a value in SQL with proper escaping and formatting.
///
/// The [QVar] class is responsible for converting Dart values into their
/// SQL representation with proper escaping to prevent SQL injection attacks.
/// It handles various data types including strings, numbers, dates, lists,
/// and null values.
///
/// Type parameter [T] can be used for type hints but doesn't affect the
/// conversion logic.
///
/// Example usage:
/// ```dart
/// var stringVar = QVar('Hello World'); // 'Hello World'
/// var numberVar = QVar(42); // 42
/// var dateVar = QVar(DateTime.now()); // '2023-12-01T10:30:00.000Z'
/// var listVar = QVar([1, 2, 3]); // (1, 2, 3)
/// var nullVar = QVar(null); // NULL
/// ```
class QVar<T> implements SQL {
  /// The Dart value to be converted to SQL
  dynamic value;

  /// Creates a new SQL value wrapper.
  ///
  /// [value] The Dart value to wrap (can be string, number, DateTime, List, or null).
  QVar(this.value);

  /// Converts this value to its SQL string representation.
  ///
  /// Delegates to the static [_to] method for the actual conversion.
  ///
  /// Returns the SQL-safe string representation of the value.
  @override
  String toSQL() {
    return QVar._to<T>(value);
  }

  /// Internal method that handles the conversion logic for different data types.
  ///
  /// [value] The value to convert.
  ///
  /// Returns the SQL representation based on the value type:
  /// - Strings: Escaped and quoted
  /// - DateTime: ISO string format
  /// - Lists: Comma-separated values in parentheses
  /// - null: "NULL"
  /// - Others: toString() representation
  static String _to<R>(dynamic value) {
    if (value is String) {
      value = QVar.escape(value);
      return "'$value'";
    } else if (value is DateTime) {
      return QVar.dateTime(value).toSQL();
    } else if (value is List) {
      return '(${value.map((e) => _to(e)).join(', ')})';
    } else if (value == null) {
      return 'NULL';
    }

    return value.toString();
  }

  /// Escapes special characters in strings to prevent SQL injection.
  ///
  /// Currently escapes double quotes and single quotes by adding backslashes.
  ///
  /// [input] The string to escape.
  ///
  /// Returns the escaped string safe for SQL queries.
  ///
  /// Note: This method is marked for improvement (@TODO).
  ///
  /// Example:
  /// ```dart
  /// QVar.escape("Hello 'World'"); // "Hello \\'World\\'"
  /// QVar.escape('Say "Hi"'); // "Say \\"Hi\\""
  /// ```
  // @TODO improve this method
  static String escape(String input) {
    input = input.replaceAll('"', '\\"');
    input = input.replaceAll("'", "\\'");
    //input = input.replaceAll('\x00', '\\0');
    return input;
  }

  /// Creates a QVar containing a DateTime value formatted as ISO 8601 string.
  ///
  /// [datetime] The DateTime to format.
  ///
  /// Returns a QVar with the ISO 8601 string representation.
  ///
  /// Example:
  /// ```dart
  /// var dateVar = QVar.dateTime(DateTime(2023, 12, 1)); // '2023-12-01T00:00:00.000Z'
  /// ```
  static QVar dateTime(DateTime datetime) => QVar(datetime.toIso8601String());

  /// Creates a QVar containing the current DateTime as ISO 8601 string.
  ///
  /// Returns a QVar with the current date and time.
  ///
  /// Example:
  /// ```dart
  /// var nowVar = QVar.dateTimeNow(); // Current timestamp
  /// ```
  static QVar dateTimeNow() => dateTime(DateTime.now());

  /// Creates a QVar containing a date formatted as 'yyyy-MM-dd'.
  ///
  /// [date] The DateTime to format (time portion ignored).
  ///
  /// Returns a QVar with the date-only string representation.
  ///
  /// Example:
  /// ```dart
  /// var dateVar = QVar.date(DateTime(2023, 12, 1)); // '2023-12-01'
  /// ```
  static QVar date(DateTime date) =>
      QVar(DateFormat('yyyy-MM-dd').format(date));

  /// Creates a QVar containing today's date formatted as 'yyyy-MM-dd'.
  ///
  /// Returns a QVar with today's date.
  ///
  /// Example:
  /// ```dart
  /// var todayVar = QVar.dateNow(); // Today's date
  /// ```
  static QVar dateNow() => date(DateTime.now());
}

/// Represents a LIKE pattern value with configurable wildcard placement.
///
/// This specialized QVar subclass is designed for SQL LIKE operations,
/// automatically adding wildcard characters (%) on the left and/or right
/// sides of the value.
///
/// Example usage:
/// ```dart
/// var startsWith = QVarLike('John', left: false, right: true); // 'John%'
/// var endsWith = QVarLike('Doe', left: true, right: false); // '%Doe'
/// var contains = QVarLike('Smith'); // '%Smith%' (default)
/// ```
class QVarLike extends QVar<String> {
  /// Whether to add wildcard on the left side
  bool left;

  /// Whether to add wildcard on the right side
  bool right;

  /// Creates a LIKE pattern value with configurable wildcard placement.
  ///
  /// [value] The base string value.
  /// [left] Whether to add % on the left (default: true).
  /// [right] Whether to add % on the right (default: true).
  QVarLike(String super.value, {this.left = true, this.right = true});

  /// Generates the SQL representation with proper escaping and wildcards.
  ///
  /// Escapes the value and any existing % characters, then adds wildcards
  /// as configured.
  ///
  /// Returns the quoted string with wildcards for LIKE operations.
  ///
  /// Example:
  /// ```dart
  /// QVarLike('John', left: false, right: true).toSQL(); // "'John%'"
  /// QVarLike('50%', left: true, right: false).toSQL(); // "'%50\\%'"
  /// ```
  @override
  String toSQL() {
    var res = QVar.escape(value).replaceAll('%', '\\%');

    if (left) {
      res = '%$res';
    }
    if (right) {
      res = '$res%';
    }
    return "'$res'";
  }
}

/// Represents a database field or column with proper SQL quoting and optional aliasing.
///
/// The [QField] class handles field names with proper backtick quoting for MySQL
/// and supports table.field notation as well as aliasing.
///
/// Example usage:
/// ```dart
/// var field1 = QField('name'); // `name`
/// var field2 = QField('users.email'); // `users`.`email`
/// var field3 = QField('count', as: 'total'); // `count` AS `total`
/// ```
class QField extends QVar<String> {
  /// Optional alias for the field
  String as;

  /// Creates a database field with optional alias.
  ///
  /// [field] The field name (can include table.field notation).
  /// [as] Optional alias for the field.
  QField(String super.field, {this.as = ''});

  /// Generates the SQL representation with proper quoting and aliasing.
  ///
  /// Handles table.field notation by quoting each part separately.
  /// Adds AS clause if an alias is provided.
  ///
  /// Returns the properly quoted field name with optional alias.
  ///
  /// Example:
  /// ```dart
  /// QField('name').toSQL(); // "`name`"
  /// QField('users.email').toSQL(); // "`users`.`email`"
  /// QField('count', as: 'total').toSQL(); // "`count` AS `total`"
  /// ```
  @override
  String toSQL() {
    var hasDot = value.contains('.');
    if (hasDot) {
      var parts = value.split('.');
      if (as.isNotEmpty) {
        return '${parts[0]}.`${parts[1]}` AS `$as`';
      }
      return '${parts[0]}.`${parts[1]}`';
    }

    if (as.isNotEmpty) {
      return '`$value` AS `$as`';
    }
    return '`$value`';
  }

  /// Convenience method to create a field representing an 'id' column.
  ///
  /// Returns a QField for the 'id' field, commonly used for primary keys.
  ///
  /// Example:
  /// ```dart
  /// var idField = QField.id(); // `id`
  /// ```
  static QField id() {
    return QField('id');
  }
}

/// Represents a subquery used as a table source in the FROM clause.
///
/// This class allows using a complete query as a table source, with
/// optional aliasing for referencing in the outer query.
///
/// Example usage:
/// ```dart
/// var subQuery = Sqler().addSelect(QSelect('user_id')).from(QField('orders'));
/// var fromQuery = QFromQuery(subQuery, as: 'order_users');
/// // Results in: (SELECT `user_id` FROM `orders`) AS `order_users`
/// ```
class QFromQuery extends QField {
  /// The subquery to use as a table source
  Sqler query;

  /// Creates a subquery table source with optional alias.
  ///
  /// [query] The subquery to execute.
  /// [as] Optional alias for the subquery result.
  QFromQuery(this.query, {String as = ''}) : super('', as: as);

  /// Generates the SQL for the subquery with optional alias.
  ///
  /// Wraps the subquery in parentheses and adds AS clause if alias is provided.
  ///
  /// Returns the subquery SQL wrapped for use as a table source.
  ///
  /// Example:
  /// ```dart
  /// // Returns: "(SELECT `user_id` FROM `orders`) AS `order_users`"
  /// ```
  @override
  String toSQL() {
    var sql = query.toSQL();
    if (as.isNotEmpty) {
      return '($sql) AS `$as`';
    }
    return '($sql)';
  }
}

class QParam extends QVar<String> {
  QParam(String super.param);

  @override
  String toSQL() {
    return '{${value.toString()}}';
  }
}

class QNull extends QVar<String> {
  QNull() : super('NULL');

  @override
  String toSQL() {
    return 'NULL';
  }
}

class CaseCondition implements SQL {
  Condition when;
  QVar then;

  CaseCondition({required this.when, required this.then});

  @override
  String toSQL() {
    return 'WHEN ${when.toSQL()} THEN ${then.toSQL()}';
  }
}

class SubQuery implements QSelectField {
  SQL subQuery;

  SubQuery(this.subQuery);

  @override
  String toSQL() {
    return '(${subQuery.toSQL()})';
  }
}

class Case implements QSelectField {
  QField? as;
  List<CaseCondition> conditions;
  QVar? elseValue;

  Case({required this.conditions, this.as, this.elseValue});

  @override
  String toSQL() {
    var sql = 'CASE';
    for (var condition in conditions) {
      sql += " ${condition.toSQL()}"; // Add space after each condition
    }
    if (elseValue != null) {
      sql += ' ELSE ${elseValue!.toSQL()}';
    }
    sql += ' END';
    if (as != null) {
      sql += ' AS ${as!.toSQL()}';
    }
    return sql;
  }

  static QSelectField select({
    required List<CaseCondition> conditions,
    QField? as,
    QVar? elseValue,
  }) {
    return Case(as: as, conditions: conditions, elseValue: elseValue);
  }
}

class On implements SQL {
  final List<Condition> _onBodies = [];

  On([List<Condition>? onBodies]) {
    if (onBodies != null) {
      _onBodies.addAll(onBodies);
    }
  }

  @override
  String toSQL() {
    var sql = <String>[];
    for (int i = 0; i < _onBodies.length; i++) {
      sql.add('( ${_onBodies[i].toSQL()} )');
    }
    return sql.join(' AND ');
  }
}

class Having implements SQL {
  final List<SQL> _havingBodies = [];

  Having([List<SQL>? whereBodies]) {
    if (whereBodies != null) {
      _havingBodies.addAll(whereBodies);
    }
  }

  @override
  String toSQL() {
    var sql = <String>[];
    for (int i = 0; i < _havingBodies.length; i++) {
      sql.add('( ${_havingBodies[i].toSQL()} )');
    }
    return sql.join(' AND  ');
  }
}

class Condition implements SQL {
  SQL right;
  SQL left;
  QO operator;

  Condition(this.left, this.operator, this.right);

  @override
  String toSQL() {
    return '( ${left.toSQL()} ${operator.toSQL()} ${right.toSQL()} )';
  }
}

/// Base interface for all SQL-generating classes.
///
/// The [SQL] interface defines the contract that all SQL query components
/// must implement. Every class that represents a part of an SQL query
/// (fields, conditions, operators, etc.) must provide a [toSQL] method
/// that returns the SQL string representation.
///
/// This interface also provides utility static methods for common SQL operations.
///
/// Example implementations:
/// ```dart
/// class MyCustomSQL implements SQL {
///   @override
///   String toSQL() => 'CUSTOM SQL HERE';
/// }
/// ```
abstract interface class SQL {
  /// Converts this SQL component to its string representation.
  ///
  /// Every implementation must provide this method to generate the
  /// appropriate SQL syntax for the component.
  ///
  /// Returns the SQL string for this component.
  String toSQL();

  /// Creates a COUNT aggregate function with optional alias.
  ///
  /// [alias] A QField that specifies the field to count and optional alias.
  ///
  /// Returns a QSelectField representing the COUNT function.
  ///
  /// Example:
  /// ```dart
  /// var count1 = SQL.count(QField('id')); // COUNT(`id`)
  /// var count2 = SQL.count(QField('id', as: 'total')); // COUNT(`id`) AS `total`
  /// ```
  static QSelectField count(QField alias) {
    if (alias.as.isNotEmpty) {
      return QMath(
        'COUNT(${QField(alias.value).toSQL()}) AS ${QField(alias.as).toSQL()}',
      );
    }
    return QMath('COUNT(${QField(alias.value).toSQL()})');
  }

  /// Creates a custom SQL expression as a selectable field.
  ///
  /// [sql] The raw SQL expression string.
  ///
  /// Returns a QSelectField containing the custom SQL.
  ///
  /// Example:
  /// ```dart
  /// var custom = SQL.custom('SUM(price * quantity)'); // SUM(price * quantity)
  /// ```
  static QSelectField custom(String sql) {
    return QMath(sql);
  }
}

/// Abstract base class for WHERE clause bodies with specific combination logic.
///
/// This class provides a foundation for building complex WHERE conditions
/// that can be combined with either AND or OR logic.
///
/// [Deprecated] - Consider using the more specific Where subclasses instead.
abstract class WhereBody implements SQL {
  /// The type of logic to use when combining conditions
  WhereType type;

  /// List of conditions to combine
  List<SQL> conditions;

  /// Creates a WHERE body with the specified conditions and combination type.
  ///
  /// [conditions] The list of SQL conditions.
  /// [type] The combination logic (default: AND).
  WhereBody(this.conditions, {this.type = WhereType.AND});

  /// Generates SQL by combining conditions with the specified logic.
  ///
  /// Returns the combined SQL string.
  @override
  String toSQL() {
    var res = [];
    for (var condition in conditions) {
      res.add(condition.toSQL());
    }
    return res.join('  ${type == WhereType.AND ? 'AND' : 'OR'} ');
  }
}

/// Enumeration for logical combination types in WHERE clauses.
///
/// This enum specifies how multiple conditions should be combined
/// in WHERE clause bodies.
// ignore: constant_identifier_names
enum WhereType {
  /// Combine conditions with AND logic
  AND,

  /// Combine conditions with OR logic
  OR,
}

/// Enumeration of SQL comparison and logical operators.
///
/// The [QO] enum provides all common SQL operators used in WHERE conditions,
/// HAVING clauses, and other conditional expressions. Each enum value
/// implements the [SQL] interface to generate the appropriate operator symbol.
///
/// Example usage:
/// ```dart
/// var condition1 = Condition(QField('age'), QO.GT, QVar(18)); // age > 18
/// var condition2 = Condition(QField('status'), QO.IN, QVar(['active', 'pending'])); // status IN ('active', 'pending')
/// var condition3 = Condition(QField('email'), QO.LIKE, QVarLike('gmail.com', left: true, right: false)); // email LIKE '%gmail.com'
/// ```
enum QO implements SQL {
  /// Equals operator (=)
  // ignore: constant_identifier_names
  EQ,

  /// Not equals operator (!=)
  // ignore: constant_identifier_names
  NEQ,

  /// Greater than operator (>)
  // ignore: constant_identifier_names
  GT,

  /// Less than operator (<)
  // ignore: constant_identifier_names
  LT,

  /// Greater than or equal operator (>=)
  // ignore: constant_identifier_names
  GTE,

  /// Less than or equal operator (<=)
  // ignore: constant_identifier_names
  LTE,

  /// IN operator for list membership
  // ignore: constant_identifier_names
  IN,

  /// NOT IN operator for list exclusion
  // ignore: constant_identifier_names
  NOT_IN,

  /// LIKE operator for pattern matching
  // ignore: constant_identifier_names
  LIKE,

  /// NOT LIKE operator for pattern exclusion
  // ignore: constant_identifier_names
  NOT_LIKE,

  /// BETWEEN operator for range checks
  // ignore: constant_identifier_names
  BETWEEN,

  /// NOT BETWEEN operator for range exclusion
  // ignore: constant_identifier_names
  NOT_BETWEEN,

  /// IS NULL operator for null checks
  // ignore: constant_identifier_names
  IS_NULL,

  /// IS NOT NULL operator for non-null checks
  // ignore: constant_identifier_names
  IS_NOT_NULL,

  /// EXISTS operator for subquery existence checks
  // ignore: constant_identifier_names
  EXISTS;

  /// Converts the operator enum to its SQL string representation.
  ///
  /// Returns the appropriate SQL operator symbol or keyword.
  ///
  /// Example:
  /// ```dart
  /// QO.EQ.toSQL(); // "="
  /// QO.LIKE.toSQL(); // "LIKE"
  /// QO.IS_NULL.toSQL(); // "IS NULL"
  /// ```
  @override
  String toSQL() {
    switch (this) {
      case QO.EQ:
        return '=';
      case QO.NEQ:
        return '!=';
      case QO.GT:
        return '>';
      case QO.LT:
        return '<';
      case QO.GTE:
        return '>=';
      case QO.LTE:
        return '<=';
      case QO.IN:
        return 'IN';
      case QO.NOT_IN:
        return 'NOT IN';
      case QO.LIKE:
        return 'LIKE';
      case QO.NOT_LIKE:
        return 'NOT LIKE';
      case QO.BETWEEN:
        return 'BETWEEN';
      case QO.NOT_BETWEEN:
        return 'NOT BETWEEN';
      case QO.IS_NULL:
        return 'IS NULL';
      case QO.IS_NOT_NULL:
        return 'IS NOT NULL';
      case QO.EXISTS:
        return 'EXISTS';
    }
  }
}

class And extends WhereBody {
  And(super.conditions) : super(type: WhereType.AND);
}

class Or extends WhereBody {
  Or(super.conditions) : super(type: WhereType.OR);
}

class Limit implements SQL {
  int? offset;
  int? limit;

  Limit([this.offset, this.limit]);

  @override
  String toSQL() {
    if (limit == null && offset == null) {
      return '';
    }
    if (offset == null) {
      return ' LIMIT $limit';
    }

    return ' LIMIT $limit OFFSET $offset';
  }
}

class Join implements SQL {
  String table;
  On on;
  Join(this.table, this.on);

  @override
  String toSQL() {
    if (on._onBodies.isNotEmpty) {
      return 'JOIN ${QField(table).toSQL()} ON ${on.toSQL()}';
    }
    return 'JOIN ${QField(table).toSQL()}';
  }
}

class LeftJoin extends Join {
  LeftJoin(super.table, super.on);

  @override
  String toSQL() {
    if (on._onBodies.isNotEmpty) {
      return 'LEFT JOIN ${QField(table).toSQL()} ON ${on.toSQL()}';
    }
    return 'LEFT JOIN ${QField(table).toSQL()}';
  }
}

class RightJoin extends Join {
  RightJoin(super.table, super.on);

  @override
  String toSQL() {
    if (on._onBodies.isNotEmpty) {
      return 'RIGHT JOIN ${QField(table).toSQL()} ON ${on.toSQL()}';
    }
    return 'RIGHT JOIN ${QField(table).toSQL()}';
  }
}

class Union extends SQL {
  bool uniunAll;
  List<Sqler> queries;
  final List<QOrder> _orderBy = [];
  Union(this.queries, {this.uniunAll = false});

  Union addOrderBy(QOrder orderBy) {
    _orderBy.add(orderBy);
    return this;
  }

  @override
  String toSQL() {
    var sql = queries
        .map((q) => q.toSQL())
        .join(' UNION ${uniunAll ? 'ALL ' : ''}');
    if (_orderBy.isNotEmpty) {
      sql += ' ORDER BY ${_orderBy.map((e) => e.toSQL()).join(', ')}';
    }
    return sql;
  }
}
