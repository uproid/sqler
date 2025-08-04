import 'package:sqler/sqler.dart';

/// Comprehensive demonstration of all features in the Sqler package for MySQL query building.
///
/// This example covers:
///
/// **Table Creation:**
/// - CREATE TABLE statements using MTable class
/// - All MySQL field types (INT, VARCHAR, TEXT, DECIMAL, ENUM, SET, JSON, etc.)
/// - Primary keys and auto-increment fields
/// - Foreign key constraints with various actions
/// - Default values and field comments
/// - Spatial data types (POINT, POLYGON)
/// - Binary and BLOB field types
/// - Table charset and collation settings
///
/// **Basic Operations:**
/// - SELECT queries with various field types
/// - INSERT operations (single and multiple records)
/// - UPDATE operations (simple and complex)
/// - DELETE operations with conditions
///
/// **Advanced Features:**
/// - Complex WHERE conditions (AND/OR combinations)
/// - All SQL operators (EQ, NEQ, GT, LT, GTE, LTE, IN, NOT_IN, LIKE, NOT_LIKE, BETWEEN)
/// - JOIN operations (INNER, LEFT, RIGHT)
/// - Aggregate functions (COUNT, SUM, AVG, MAX, MIN)
/// - GROUP BY and HAVING clauses
/// - ORDER BY with ASC/DESC
/// - LIMIT and OFFSET
/// - Subqueries
/// - UNION and UNION ALL operations
/// - Parameterized queries
///
/// **Data Types Supported:**
/// - Strings (with proper escaping)
/// - Numbers (integers and decimals)
/// - Booleans
/// - DateTime objects
/// - Lists/Arrays
/// - NULL values
///
/// **Query Building Features:**
/// - Fluent interface with method chaining
/// - Field aliases
/// - Custom SQL expressions
/// - Incremental query building
/// - Proper SQL escaping and formatting
///
/// **Real-world Examples:**
/// - Complete database schema creation
/// - Sales reporting queries
/// - Inventory management
/// - User management systems
/// - Complex business logic queries

void main() {
  print('=== Sqler Package - Comprehensive Feature Demo ===\n');

  // 0. CREATE TABLE Examples with MTable Class
  print('0. CREATE TABLE Examples:');
  print('');

  // 0a. Simple table with basic field types
  print('0a. Simple Users Table:');
  var usersTable = MTable(
    name: 'users',
    fields: [
      MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
      MFieldVarchar(name: 'username', length: 50),
      MFieldVarchar(name: 'email', length: 255),
      MFieldVarchar(name: 'password_hash', length: 255),
      MFieldBoolean(name: 'is_active', defaultValue: 'TRUE'),
      MFieldTimestamp(name: 'created_at', defaultValue: 'CURRENT_TIMESTAMP'),
      MFieldTimestamp(name: 'updated_at', defaultValue: 'CURRENT_TIMESTAMP'),
    ],
  );
  print(usersTable.toSQL());
  print('');

  // 0b. Complex table with various field types
  print('0b. Products Table with Various Field Types:');
  var productsTable = MTable(
    name: 'products',
    fields: [
      MBigInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
      MFieldVarchar(name: 'name', length: 200),
      MFieldText(name: 'description'),
      MFieldVarchar(name: 'sku', length: 50, comment: 'Stock Keeping Unit'),
      MFieldDecimal(name: 'price', m: 10, d: 2),
      MFieldDecimal(name: 'cost', m: 10, d: 2),
      MFieldFloat(name: 'weight', m: 8, d: 2),
      MFieldInt(name: 'stock_quantity', defaultValue: '0'),
      MFieldEnum(
        name: 'status',
        values: ['active', 'inactive', 'discontinued'],
        defaultValue: 'active',
      ),
      MFieldSet(
        name: 'tags',
        values: ['new', 'featured', 'sale', 'bestseller', 'limited'],
        isNullable: true,
      ),
      MFieldJson(name: 'metadata', isNullable: true),
      MFieldDate(name: 'release_date', isNullable: true),
      MFieldTimestamp(name: 'created_at', defaultValue: 'CURRENT_TIMESTAMP'),
      MFieldTimestamp(name: 'updated_at', defaultValue: 'CURRENT_TIMESTAMP'),
    ],
    charset: 'utf8mb4',
    collation: 'utf8mb4_unicode_ci',
  );
  print(productsTable.toSQL());
  print('');

  // 0c. Table with foreign keys
  print('0c. Orders Table with Foreign Keys:');
  var ordersTable = MTable(
    name: 'orders',
    fields: [
      MBigInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
      MBigInt(name: 'user_id'),
      MFieldVarchar(name: 'order_number', length: 50),
      MFieldDecimal(name: 'subtotal', m: 10, d: 2),
      MFieldDecimal(name: 'tax_amount', m: 10, d: 2),
      MFieldDecimal(name: 'shipping_amount', m: 10, d: 2),
      MFieldDecimal(name: 'total_amount', m: 10, d: 2),
      MFieldEnum(
        name: 'status',
        values: ['pending', 'processing', 'shipped', 'delivered', 'cancelled'],
        defaultValue: 'pending',
      ),
      MFieldText(name: 'shipping_address'),
      MFieldText(name: 'billing_address'),
      MFieldVarchar(name: 'payment_method', length: 50),
      MFieldDateTime(name: 'order_date', defaultValue: 'CURRENT_TIMESTAMP'),
      MFieldDateTime(name: 'shipped_date', isNullable: true),
      MFieldDateTime(name: 'delivered_date', isNullable: true),
      MFieldTimestamp(name: 'created_at', defaultValue: 'CURRENT_TIMESTAMP'),
      MFieldTimestamp(name: 'updated_at', defaultValue: 'CURRENT_TIMESTAMP'),
    ],
    foreignKeys: [
      ForeignKey(
        name: 'user_id',
        refTable: 'users',
        refColumn: 'id',
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      ),
    ],
  );
  print(ordersTable.toSQL());
  print('');

  // 0d. Table with all numeric types
  print('0d. Analytics Table with All Numeric Types:');
  var analyticsTable = MTable(
    name: 'analytics_data',
    fields: [
      MBigInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
      MTinyInt(name: 'event_type', length: 3),
      MSmallInt(name: 'category_id'),
      MMediumInt(name: 'session_id'),
      MFieldInt(name: 'user_id'),
      MBigInt(name: 'timestamp_ms'),
      MFieldFloat(name: 'duration', m: 8, d: 3),
      MFieldDecimal(name: 'value', m: 15, d: 4),
      MFieldBoolean(name: 'is_conversion', defaultValue: 'FALSE'),
      MFieldVarchar(name: 'event_name', length: 100),
      MFieldJson(name: 'properties', isNullable: true),
      MFieldDate(name: 'event_date'),
      MFieldTime(name: 'event_time'),
      MFieldYear(name: 'year_partition', length: 4),
    ],
  );
  print(analyticsTable.toSQL());
  print('');

  // 0e. Table with binary and blob types
  print('0e. Media Files Table with Binary Types:');
  var mediaTable = MTable(
    name: 'media_files',
    fields: [
      MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
      MFieldVarchar(name: 'filename', length: 255),
      MFieldVarchar(name: 'mime_type', length: 100),
      MBigInt(name: 'file_size'),
      MFieldBinary(name: 'file_hash', length: 32),
      MFieldTinyBlob(name: 'thumbnail', isNullable: true),
      MFieldBlob(name: 'small_preview', isNullable: true),
      MFieldMediumBlob(name: 'medium_preview', isNullable: true),
      MFieldLongBlob(name: 'original_file', isNullable: true),
      MFieldVarBinary(name: 'metadata_binary', length: 1000, isNullable: true),
      MFieldBit(name: 'flags', length: 8, defaultValue: '0'),
      MFieldTimestamp(name: 'uploaded_at', defaultValue: 'CURRENT_TIMESTAMP'),
    ],
  );
  print(mediaTable.toSQL());
  print('');

  // 0f. Table with text types and comments
  print('0f. Blog Posts Table with Text Types:');
  var blogTable = MTable(
    name: 'blog_posts',
    fields: [
      MBigInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
      MFieldVarchar(name: 'title', length: 255, comment: 'Post title'),
      MFieldVarchar(name: 'slug', length: 255, comment: 'URL-friendly version'),
      MFieldTinyText(name: 'excerpt', comment: 'Short description'),
      MFieldText(name: 'content', comment: 'Main post content'),
      MFieldMediumText(name: 'content_markdown', isNullable: true),
      MFieldLongText(name: 'content_html_cache', isNullable: true),
      MBigInt(name: 'author_id'),
      MFieldEnum(
        name: 'status',
        values: ['draft', 'published', 'archived'],
        defaultValue: 'draft',
      ),
      MFieldSet(
        name: 'categories',
        values: ['tech', 'business', 'lifestyle', 'news', 'tutorial'],
        isNullable: true,
      ),
      MFieldInt(name: 'view_count', defaultValue: '0'),
      MFieldInt(name: 'like_count', defaultValue: '0'),
      MFieldDateTime(name: 'published_at', isNullable: true),
      MFieldTimestamp(name: 'created_at', defaultValue: 'CURRENT_TIMESTAMP'),
      MFieldTimestamp(name: 'updated_at', defaultValue: 'CURRENT_TIMESTAMP'),
    ],
    foreignKeys: [
      ForeignKey(
        name: 'author_id',
        refTable: 'users',
        refColumn: 'id',
        onDelete: 'SET NULL',
        onUpdate: 'CASCADE',
      ),
    ],
  );
  print(blogTable.toSQL());
  print('');

  // 0g. Spatial data table
  print('0g. Locations Table with Spatial Types:');
  var locationsTable = MTable(
    name: 'locations',
    fields: [
      MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
      MFieldVarchar(name: 'name', length: 255),
      MFieldVarchar(name: 'address', length: 500),
      MFieldPoint(name: 'coordinates', srid: 4326),
      MFieldPolygon(name: 'service_area', isNullable: true, srid: 4326),
      MFieldDecimal(name: 'latitude', m: 10, d: 8),
      MFieldDecimal(name: 'longitude', m: 11, d: 8),
      MFieldVarchar(name: 'city', length: 100),
      MFieldVarchar(name: 'state', length: 50),
      MFieldVarchar(name: 'country', length: 50),
      MFieldVarchar(name: 'postal_code', length: 20),
      MFieldBoolean(name: 'is_active', defaultValue: 'TRUE'),
      MFieldTimestamp(name: 'created_at', defaultValue: 'CURRENT_TIMESTAMP'),
    ],
  );
  print(locationsTable.toSQL());
  print('');

  print('=== End of CREATE TABLE Examples ===\n');

  // 1. Basic SELECT Query
  print('1. Basic SELECT Query:');
  var basicQuery = Sqler()
      .addSelect(QSelect('name'))
      .addSelect(QSelect('email'))
      .addSelect(QSelect('age'))
      .from(QField('users'))
      .where(WhereOne(QField('active'), QO.EQ, QVar(true)))
      .orderBy(QOrder('name'))
      .limit(10);

  print(basicQuery.toSQL());
  print('');

  // 2. SELECT with Aggregate Functions
  print('2. SELECT with Aggregate Functions:');
  var aggregateQuery = Sqler()
      .addSelect(QSelect('department'))
      .addSelect(QSelectCustom(QMath('COUNT(*)')))
      .addSelect(QSelectCustom(QMath('AVG(salary)')))
      .addSelect(QSelectCustom(QMath('MAX(salary)')))
      .addSelect(QSelectCustom(QMath('MIN(salary)')))
      .from(QField('employees'))
      .groupBy(['department'])
      .having(Having([Condition(QField('COUNT(*)'), QO.GT, QVar(5))]))
      .orderBy(QOrder('department'));

  print(aggregateQuery.toSQL());
  print('');

  // 3. Complex WHERE Conditions (AND/OR)
  print('3. Complex WHERE Conditions:');
  var complexWhereQuery = Sqler()
      .addSelect(QSelectAll())
      .from(QField('products'))
      .where(
        AndWhere([
          WhereOne(QField('category'), QO.EQ, QVar('electronics')),
          OrWhere([
            WhereOne(QField('price'), QO.LT, QVar(100)),
            WhereOne(QField('discount'), QO.GT, QVar(0.1)),
          ]),
        ]),
      );

  print(complexWhereQuery.toSQL());
  print('');

  // 4. Various Operators
  print('4. Various SQL Operators:');
  var operatorsQuery = Sqler()
      .addSelect(QSelect('name'))
      .addSelect(QSelect('age'))
      .addSelect(QSelect('salary'))
      .from(QField('employees'))
      .where(
        AndWhere([
          WhereOne(QField('age'), QO.BETWEEN, QVar([25, 45])),
          WhereOne(
            QField('department'),
            QO.IN,
            QVar(['IT', 'Sales', 'Marketing']),
          ),
          WhereOne(QField('name'), QO.LIKE, QVarLike('%john%')),
          WhereOne(QField('status'), QO.NEQ, QVar('inactive')),
        ]),
      );

  print(operatorsQuery.toSQL());
  print('');

  // 5. JOIN Operations
  print('5. JOIN Operations:');
  var joinQuery = Sqler()
      .addSelect(QSelect('u.name'))
      .addSelect(QSelect('u.email'))
      .addSelect(QSelect('p.bio'))
      .addSelect(QSelect('d.name', as: 'department_name'))
      .from(QField('users', as: 'u'))
      .join(
        LeftJoin(
          'profiles',
          On([Condition(QField('u.id'), QO.EQ, QField('profiles.user_id'))]),
        ),
      )
      .join(
        Join(
          'departments',
          On([
            Condition(
              QField('u.department_id'),
              QO.EQ,
              QField('departments.id'),
            ),
          ]),
        ),
      )
      .where(WhereOne(QField('u.active'), QO.EQ, QVar(true)))
      .orderBy(QOrder('u.name'));

  print(joinQuery.toSQL());
  print('');

  // 6. INSERT Operation
  print('6. INSERT Operation:');
  var insertQuery = Sqler().insert(QField('users'), [
    {
      'name': QVar('John Doe'),
      'email': QVar('john@example.com'),
      'age': QVar(30),
      'active': QVar(true),
      'created_at': QVar(DateTime.now()),
    },
    {
      'name': QVar('Jane Smith'),
      'email': QVar('jane@example.com'),
      'age': QVar(28),
      'active': QVar(true),
      'created_at': QVar(DateTime.now()),
    },
  ]);

  print(insertQuery.toSQL());
  print('');

  // 7. UPDATE Operation
  print('7. UPDATE Operation:');
  var updateQuery = Sqler()
      .update(QField('users'))
      .updateSet('email', QVar('newemail@example.com'))
      .updateSet('updated_at', QVar(DateTime.now()))
      .where(WhereOne(QField('id'), QO.EQ, QVar(1)));

  print(updateQuery.toSQL());
  print('');

  // 8. DELETE Operation
  print('8. DELETE Operation:');
  var deleteQuery = Sqler()
      .delete()
      .from(QField('users'))
      .where(
        AndWhere([
          WhereOne(QField('active'), QO.EQ, QVar(false)),
          WhereOne(
            QField('last_login'),
            QO.LT,
            QVar(DateTime.now().subtract(Duration(days: 365))),
          ),
        ]),
      );

  print(deleteQuery.toSQL());
  print('');

  // 9. Parameterized Queries
  print('9. Parameterized Queries:');
  var paramQuery = Sqler()
      .addSelect(QSelect('name'))
      .addSelect(QSelect('email'))
      .from(QField('users'))
      .addParam('min_age', QVar(21))
      .addParam('status', QVar('active'))
      .where(
        AndWhere([
          WhereOne(QField('age'), QO.GTE, QParam('min_age')),
          WhereOne(QField('status'), QO.EQ, QParam('status')),
        ]),
      );

  print(paramQuery.toSQL());
  print('');

  // 10. Subquery Example
  print('10. Subquery Example:');
  var subquery = Sqler()
      .addSelect(QSelectCustom(QMath('AVG(salary)')))
      .from(QField('employees'));

  var mainQuery = Sqler()
      .addSelect(QSelect('name'))
      .addSelect(QSelect('salary'))
      .from(QField('employees'))
      .where(
        WhereOne(QField('salary'), QO.GT, QSelectCustom(SubQuery(subquery))),
      );

  print(mainQuery.toSQL());
  print('');

  // 11. Advanced SELECT with Custom Fields and Aliases
  print('11. Advanced SELECT with Aliases:');
  var advancedQuery = Sqler()
      .addSelect(QSelect('first_name', as: 'fname'))
      .addSelect(QSelect('last_name', as: 'lname'))
      .addSelect(
        QSelectCustom(
          QMath('CONCAT(first_name, " ", last_name)'),
          as: 'full_name',
        ),
      )
      .addSelect(
        QSelectCustom(
          QMath('YEAR(CURDATE()) - YEAR(birth_date)'),
          as: 'calculated_age',
        ),
      )
      .from(QField('users'))
      .where(WhereOne(QField('birth_date'), QO.GT, QVar(DateTime(1990, 1, 1))))
      .orderBy(QOrder('last_name'))
      .orderBy(QOrder('first_name'))
      .limit(20, 10); // LIMIT 20 OFFSET 10

  print(advancedQuery.toSQL());
  print('');

  // 12. Multiple JOINs with Different Types
  print('12. Multiple JOIN Types:');
  var multiJoinQuery = Sqler()
      .addSelect(QSelect('u.username'))
      .addSelect(QSelect('o.order_date'))
      .addSelect(QSelect('p.name', as: 'product_name'))
      .addSelect(QSelect('c.name', as: 'category_name'))
      .from(QField('users', as: 'u'))
      .join(
        Join(
          'orders',
          On([Condition(QField('u.id'), QO.EQ, QField('orders.user_id'))]),
        ),
      )
      .join(
        LeftJoin(
          'order_items',
          On([Condition(QField('o.id'), QO.EQ, QField('oi.order_id'))]),
        ),
      )
      .join(
        RightJoin(
          'products',
          On([Condition(QField('oi.product_id'), QO.EQ, QField('p.id'))]),
        ),
      )
      .join(
        LeftJoin(
          'categories',
          On([Condition(QField('p.category_id'), QO.EQ, QField('c.id'))]),
        ),
      )
      .where(
        WhereOne(
          QField('o.order_date'),
          QO.GT,
          QVar(DateTime.now().subtract(Duration(days: 30))),
        ),
      )
      .orderBy(QOrder('o.order_date', desc: true));

  print(multiJoinQuery.toSQL());
  print('');

  // 13. Query Building Incrementally
  print('13. Incremental Query Building:');
  var incrementalQuery = Sqler()
      .addSelect(QSelect('id'))
      .addSelect(QSelect('name'))
      .from(QField('products'));

  // Add condition based on some logic
  bool includeExpensive = true;
  if (includeExpensive) {
    incrementalQuery.where(WhereOne(QField('price'), QO.GT, QVar(100)));
  }

  // Add category filter
  String? categoryFilter = 'electronics';
  if (incrementalQuery.hasWhere()) {
    incrementalQuery.where(
      WhereOne(QField('category'), QO.EQ, QVar(categoryFilter)),
    );
  }

  print(incrementalQuery.toSQL());
  print('');

  // 14. Field Types and Escaping
  print('14. Field Types and Value Escaping:');
  var escapingQuery = Sqler()
      .addSelect(QSelect('name'))
      .addSelect(QSelect('description'))
      .from(QField('table.with.dots')) // Handles field names with dots
      .where(
        AndWhere([
          WhereOne(
            QField('title'),
            QO.EQ,
            QVar("Product's \"Best\" Item"),
          ), // String with quotes
          WhereOne(QField('price'), QO.EQ, QVar(19.99)), // Decimal
          WhereOne(QField('is_available'), QO.EQ, QVar(true)), // Boolean
          WhereOne(
            QField('created_at'),
            QO.EQ,
            QVar(DateTime.now()),
          ), // DateTime
          WhereOne(
            QField('tags'),
            QO.IN,
            QVar(['electronics', 'gadgets']),
          ), // List
        ]),
      );

  print(escapingQuery.toSQL());
  print('');

  // 15. Advanced INSERT Examples
  print('15. Advanced INSERT Examples:');

  // INSERT with single record
  print('15a. Single INSERT:');
  var singleInsert = Sqler().insert(QField('products'), [
    {
      'name': QVar('Smartphone'),
      'category': QVar('electronics'),
      'price': QVar(599.99),
      'in_stock': QVar(true),
      'created_at': QVar(DateTime.now()),
      'tags': QVar(['mobile', 'phone', 'tech']),
    },
  ]);
  print(singleInsert.toSQL());
  print('');

  // INSERT with multiple records
  print('15b. Multiple INSERT:');
  var multiInsert = Sqler().insert(QField('employees'), [
    {
      'first_name': QVar('Alice'),
      'last_name': QVar('Johnson'),
      'email': QVar('alice@company.com'),
      'department': QVar('Engineering'),
      'salary': QVar(75000),
      'hire_date': QVar(DateTime.now()),
      'is_active': QVar(true),
    },
    {
      'first_name': QVar('Bob'),
      'last_name': QVar('Smith'),
      'email': QVar('bob@company.com'),
      'department': QVar('Marketing'),
      'salary': QVar(65000),
      'hire_date': QVar(DateTime.now()),
      'is_active': QVar(true),
    },
    {
      'first_name': QVar('Carol'),
      'last_name': QVar('Williams'),
      'email': QVar('carol@company.com'),
      'department': QVar('Sales'),
      'salary': QVar(70000),
      'hire_date': QVar(DateTime.now()),
      'is_active': QVar(false),
    },
  ]);
  print(multiInsert.toSQL());
  print('');

  // 16. Advanced UPDATE Examples
  print('16. Advanced UPDATE Examples:');

  // UPDATE with single field
  print('16a. Simple UPDATE:');
  var simpleUpdate = Sqler()
      .update(QField('users'))
      .updateSet('last_login', QVar(DateTime.now()))
      .where(WhereOne(QField('id'), QO.EQ, QVar(123)));
  print(simpleUpdate.toSQL());
  print('');

  // UPDATE with multiple fields and complex WHERE
  print('16b. Complex UPDATE:');
  var complexUpdate = Sqler()
      .update(QField('products'))
      .updateSet('price', QVar(199.99))
      .updateSet('discount_percentage', QVar(15.0))
      .updateSet('updated_at', QVar(DateTime.now()))
      .updateSet('on_sale', QVar(true))
      .where(
        AndWhere([
          WhereOne(QField('category'), QO.EQ, QVar('electronics')),
          WhereOne(QField('in_stock'), QO.EQ, QVar(true)),
          OrWhere([
            WhereOne(QField('price'), QO.GT, QVar(500)),
            WhereOne(
              QField('brand'),
              QO.IN,
              QVar(['Samsung', 'Apple', 'Sony']),
            ),
          ]),
        ]),
      );
  print(complexUpdate.toSQL());
  print('');

  // UPDATE with LIKE and date conditions
  print('16c. UPDATE with Date and Pattern Matching:');
  var dateUpdate = Sqler()
      .update(QField('employees'))
      .updateSet('status', QVar('archived'))
      .updateSet('archived_at', QVar(DateTime.now()))
      .where(
        AndWhere([
          WhereOne(QField('email'), QO.LIKE, QVarLike('%@oldcompany.com')),
          WhereOne(QField('hire_date'), QO.LT, QVar(DateTime(2020, 1, 1))),
          WhereOne(QField('is_active'), QO.EQ, QVar(false)),
        ]),
      );
  print(dateUpdate.toSQL());
  print('');

  // 17. Advanced DELETE Examples
  print('17. Advanced DELETE Examples:');

  // Simple DELETE
  print('17a. Simple DELETE:');
  var simpleDelete = Sqler()
      .delete()
      .from(QField('temporary_data'))
      .where(
        WhereOne(
          QField('created_at'),
          QO.LT,
          QVar(DateTime.now().subtract(Duration(days: 7))),
        ),
      );
  print(simpleDelete.toSQL());
  print('');

  // DELETE with complex conditions
  print('17b. Complex DELETE with Multiple Conditions:');
  var complexDelete = Sqler()
      .delete()
      .from(QField('user_sessions'))
      .where(
        OrWhere([
          AndWhere([
            WhereOne(QField('expires_at'), QO.LT, QVar(DateTime.now())),
            WhereOne(QField('is_active'), QO.EQ, QVar(false)),
          ]),
          AndWhere([
            WhereOne(
              QField('last_activity'),
              QO.LT,
              QVar(DateTime.now().subtract(Duration(hours: 24))),
            ),
            WhereOne(QField('user_id'), QO.IN, QVar([1, 2, 3, 99, 100])),
          ]),
          WhereOne(QField('session_token'), QO.LIKE, QVarLike('temp_%')),
        ]),
      );
  print(complexDelete.toSQL());
  print('');

  // DELETE with NOT conditions
  print('17c. DELETE with NOT conditions:');
  var notDelete = Sqler()
      .delete()
      .from(QField('products'))
      .where(
        AndWhere([
          WhereOne(
            QField('category'),
            QO.NOT_IN,
            QVar(['essential', 'premium']),
          ),
          WhereOne(QField('name'), QO.NOT_LIKE, QVarLike('%special%')),
          WhereOne(QField('price'), QO.BETWEEN, QVar([0.01, 10.00])),
        ]),
      );
  print(notDelete.toSQL());
  print('');

  // 18. Advanced UNION Examples
  print('18. Advanced UNION Examples:');

  // Simple UNION
  print('18a. Basic UNION:');
  var currentEmployees = Sqler()
      .addSelect(QSelect('first_name'))
      .addSelect(QSelect('last_name'))
      .addSelect(QSelect('email'))
      .addSelect(QSelectCustom(QMath("'current'"), as: 'employment_status'))
      .from(QField('employees'))
      .where(WhereOne(QField('is_active'), QO.EQ, QVar(true)));

  var formerEmployees = Sqler()
      .addSelect(QSelect('first_name'))
      .addSelect(QSelect('last_name'))
      .addSelect(QSelect('email'))
      .addSelect(QSelectCustom(QMath("'former'"), as: 'employment_status'))
      .from(QField('employees'))
      .where(WhereOne(QField('is_active'), QO.EQ, QVar(false)));

  var employeeUnion = Union([
    currentEmployees,
    formerEmployees,
  ]).addOrderBy(QOrder('last_name')).addOrderBy(QOrder('first_name'));

  print(employeeUnion.toSQL());
  print('');

  // UNION ALL example
  print('18b. UNION ALL (allows duplicates):');
  var highValueOrders = Sqler()
      .addSelect(QSelect('order_id'))
      .addSelect(QSelect('customer_id'))
      .addSelect(QSelect('total_amount'))
      .addSelect(QSelectCustom(QMath("'high_value'"), as: 'order_type'))
      .from(QField('orders'))
      .where(WhereOne(QField('total_amount'), QO.GT, QVar(1000)));

  var recentOrders = Sqler()
      .addSelect(QSelect('order_id'))
      .addSelect(QSelect('customer_id'))
      .addSelect(QSelect('total_amount'))
      .addSelect(QSelectCustom(QMath("'recent'"), as: 'order_type'))
      .from(QField('orders'))
      .where(
        WhereOne(
          QField('order_date'),
          QO.GT,
          QVar(DateTime.now().subtract(Duration(days: 7))),
        ),
      );

  var ordersUnionAll = Union([
    highValueOrders,
    recentOrders,
  ], uniunAll: true).addOrderBy(QOrder('total_amount', desc: true));

  print(ordersUnionAll.toSQL());
  print('');

  // Complex UNION with multiple queries
  print('18c. Complex UNION with Multiple Queries:');
  var activeCustomers = Sqler()
      .addSelect(QSelect('id'))
      .addSelect(QSelect('name'))
      .addSelect(QSelect('email'))
      .addSelect(QSelectCustom(QMath("'active_customer'"), as: 'type'))
      .addSelect(QSelectCustom(QMath('NULL'), as: 'department'))
      .from(QField('customers'))
      .where(
        WhereOne(
          QField('last_order_date'),
          QO.GT,
          QVar(DateTime.now().subtract(Duration(days: 30))),
        ),
      );

  var activeEmployees = Sqler()
      .addSelect(QSelect('id'))
      .addSelect(
        QSelectCustom(QMath('CONCAT(first_name, " ", last_name)'), as: 'name'),
      )
      .addSelect(QSelect('email'))
      .addSelect(QSelectCustom(QMath("'employee'"), as: 'type'))
      .addSelect(QSelect('department'))
      .from(QField('employees'))
      .where(WhereOne(QField('is_active'), QO.EQ, QVar(true)));

  var activeSuppliers = Sqler()
      .addSelect(QSelect('id'))
      .addSelect(QSelect('company_name', as: 'name'))
      .addSelect(QSelect('contact_email', as: 'email'))
      .addSelect(QSelectCustom(QMath("'supplier'"), as: 'type'))
      .addSelect(QSelectCustom(QMath('NULL'), as: 'department'))
      .from(QField('suppliers'))
      .where(WhereOne(QField('is_active'), QO.EQ, QVar(true)));

  var allContactsUnion = Union([
    activeCustomers,
    activeEmployees,
    activeSuppliers,
  ]).addOrderBy(QOrder('type')).addOrderBy(QOrder('name'));

  print(allContactsUnion.toSQL());
  print('');

  // 19. Combining Operations Examples
  print('19. Real-world Complex Query Examples:');

  // Complex reporting query
  print('19a. Sales Report with JOINs and Aggregates:');
  var salesReport = Sqler()
      .addSelect(QSelect('e.first_name', as: 'sales_person'))
      .addSelect(QSelect('e.last_name', as: 'sales_person_last'))
      .addSelect(QSelectCustom(QMath('COUNT(o.id)'), as: 'total_orders'))
      .addSelect(QSelectCustom(QMath('SUM(o.total_amount)'), as: 'total_sales'))
      .addSelect(
        QSelectCustom(QMath('AVG(o.total_amount)'), as: 'avg_order_value'),
      )
      .addSelect(
        QSelectCustom(QMath('MAX(o.total_amount)'), as: 'highest_order'),
      )
      .from(QField('employees', as: 'e'))
      .join(
        LeftJoin(
          'orders o',
          On([Condition(QField('e.id'), QO.EQ, QField('o.sales_person_id'))]),
        ),
      )
      .where(
        AndWhere([
          WhereOne(QField('e.department'), QO.EQ, QVar('Sales')),
          WhereOne(QField('e.is_active'), QO.EQ, QVar(true)),
          WhereOne(
            QField('o.order_date'),
            QO.BETWEEN,
            QVar([DateTime.now().subtract(Duration(days: 30)), DateTime.now()]),
          ),
        ]),
      )
      .groupBy(['e.id', 'e.first_name', 'e.last_name'])
      .having(Having([Condition(QField('COUNT(o.id)'), QO.GT, QVar(0))]))
      .orderBy(QOrder('total_sales', desc: true))
      .limit(10);

  print(salesReport.toSQL());
  print('');

  // Inventory management query
  print('19b. Low Stock Alert Query:');
  var lowStockAlert = Sqler()
      .addSelect(QSelect('p.name', as: 'product_name'))
      .addSelect(QSelect('p.sku'))
      .addSelect(QSelect('c.name', as: 'category'))
      .addSelect(QSelect('i.current_stock'))
      .addSelect(QSelect('i.minimum_stock'))
      .addSelect(
        QSelectCustom(
          QMath('(i.minimum_stock - i.current_stock)'),
          as: 'shortage',
        ),
      )
      .addSelect(QSelect('s.company_name', as: 'supplier'))
      .from(QField('products', as: 'p'))
      .join(
        Join(
          'inventory i',
          On([Condition(QField('p.id'), QO.EQ, QField('i.product_id'))]),
        ),
      )
      .join(
        LeftJoin(
          'categories c',
          On([Condition(QField('p.category_id'), QO.EQ, QField('c.id'))]),
        ),
      )
      .join(
        LeftJoin(
          'suppliers s',
          On([Condition(QField('p.supplier_id'), QO.EQ, QField('s.id'))]),
        ),
      )
      .where(
        AndWhere([
          WhereOne(QField('i.current_stock'), QO.LT, QField('i.minimum_stock')),
          WhereOne(QField('p.is_active'), QO.EQ, QVar(true)),
          WhereOne(
            QField('c.name'),
            QO.NOT_IN,
            QVar(['discontinued', 'seasonal']),
          ),
        ]),
      )
      .orderBy(QOrder('shortage', desc: true))
      .orderBy(QOrder('p.name'));

  print(lowStockAlert.toSQL());
  print('');

  print('=== All comprehensive examples completed! ===');
}
