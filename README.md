# Sqler

A powerful and flexible SQL query builder for Dart, focusing on MySQL support with a fluent interface design.

[![Pub Version](https://img.shields.io/pub/v/sqler)](https://pub.dev/packages/sqler)



## Features

- **Fluent Interface**: Build SQL queries using method chaining for better readability
- **Type-Safe**: Construct queries with compile-time safety
- **Comprehensive Support**: SELECT, INSERT, UPDATE, DELETE operations
- **Advanced Clauses**: WHERE, JOIN, GROUP BY, HAVING, ORDER BY, LIMIT
- **Parameterized Queries**: Support for named parameters to prevent SQL injection
- **Proper Escaping**: Automatic field quoting and value escaping
- **Complex Operations**: Subqueries, CASE statements, aggregate functions
- **MySQL Optimized**: Specifically designed for MySQL syntax and features

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  sqler: ^1.0.0
```

Then run:

```bash
dart pub get
```

## Quick Start

```dart
import 'package:sqler/sqler.dart';

void main() {
  // Create Table
  var books = MTable(
    name: 'books',
    fields: [
      MFieldInt(name: 'id', isPrimaryKey: true, isAutoIncrement: true),
      MFieldVarchar(name: 'name', length: 255),
      MFieldVarchar(name: 'author', length: 255),
      MFieldInt(name: 'publication_year'),
      MFieldDate(name: 'published_date'),
      MFieldText(name: 'content'),
    ],
  );

  // Simple SELECT query
  var query = Sqler()
    .addSelect(QSelect('name'))
    .addSelect(QSelect('published_date'))
    .from(QField('books'))
    .where(WhereOne(QField('publication_year'), QO.EQ, QVar(1980)))
    .orderBy(QOrder('name'))
    .limit(10);

  print(query.toSQL());
}
```

## Core Classes

### Sqler
The main query builder class that provides a fluent interface for constructing SQL queries.

### QField
Represents database fields with proper quoting:
```dart
QField('users.name')     // users.`name`
QField('table_name')     // `table_name`
```

### QVar
Represents values with proper escaping:
```dart
QVar('string value')     // 'string value'
QVar(123)               // 123
QVar(true)              // true
QVar(null)              // NULL
```

### QSelect
Represents SELECT fields with optional aliases:
```dart
QSelect('name')                    // `name`
QSelect('users.name', 'user_name') // users.`name` AS `user_name`
```

## Usage Examples

### Basic SELECT Query

```dart
var query = Sqler()
  .addSelect(QSelect('id'))
  .addSelect(QSelect('name'))
  .addSelect(QSelect('email'))
  .from(QField('users'));

print(query.toSQL());
// SELECT `id`, `name`, `email` FROM `users`
```

### SELECT with WHERE Conditions

```dart
var query = Sqler()
  .addSelect(QSelect('*'))
  .from(QField('users'))
  .where(AndWhere([
    WhereOne(QField('active'), QO.EQ, QVar(true)),
    WhereOne(QField('age'), QO.GT, QVar(18))
  ]));

print(query.toSQL());
// SELECT * FROM `users` WHERE ( ( `active` = true ) ) AND ( ( `age` > 18 ) )
```

### SELECT with JOINs

```dart
var query = Sqler()
  .addSelect(QSelect('users.name'))
  .addSelect(QSelect('profiles.bio'))
  .from(QField('users'))
  .join(LeftJoin('profiles', On([
    Condition(QField('users.id'), QO.EQ, QField('profiles.user_id'))
  ])))
  .where(WhereOne(QField('users.active'), QO.EQ, QVar(true)));

print(query.toSQL());
// SELECT `users`.`name`, `profiles`.`bio` FROM `users` 
// LEFT JOIN `profiles` ON ( ( `users`.`id` = `profiles`.`user_id` ) ) 
// WHERE ( `users`.`active` = true )
```

### INSERT Operations

```dart
// Single record insert
var query = Sqler()
  .insert(QField('users'), [
    {
      'name': QVar('John Doe'),
      'email': QVar('john@example.com'),
      'active': QVar(true),
      'age': QVar(30)
    }
  ]);

print(query.toSQL());
// INSERT INTO `users` (`name`, `email`, `active`, `age`) 
// VALUES ('John Doe', 'john@example.com', true, 30)
```

```dart
// Multiple records insert
var query = Sqler()
  .insert(QField('users'), [
    {
      'name': QVar('John Doe'),
      'email': QVar('john@example.com')
    },
    {
      'name': QVar('Jane Smith'),
      'email': QVar('jane@example.com')
    }
  ]);

print(query.toSQL());
// INSERT INTO `users` (`name`, `email`) 
// VALUES ('John Doe', 'john@example.com'), ('Jane Smith', 'jane@example.com')
```

### UPDATE Operations

```dart
var query = Sqler()
  .update(QField('users'), {
    'name': QVar('Updated Name'),
    'email': QVar('updated@example.com')
  })
  .where(WhereOne(QField('id'), QO.EQ, QVar(1)));

print(query.toSQL());
// UPDATE `users` SET `name` = 'Updated Name', `email` = 'updated@example.com' 
// WHERE ( `id` = 1 )
```

### DELETE Operations

```dart
var query = Sqler()
  .delete()
  .from(QField('users'))
  .where(WhereOne(QField('active'), QO.EQ, QVar(false)));

print(query.toSQL());
// DELETE FROM `users` WHERE ( `active` = false )
```

### Complex Queries with GROUP BY and HAVING

```dart
var query = Sqler()
  .addSelect(QSelect('department'))
  .addSelect(QSelectFunc('COUNT', [QField('id')], 'employee_count'))
  .from(QField('employees'))
  .where(WhereOne(QField('active'), QO.EQ, QVar(true)))
  .groupBy(QField('department'))
  .having(HavingOne(QSelectFunc('COUNT', [QField('id')]), QO.GT, QVar(5)))
  .orderBy(QOrder('employee_count', OrderDirection.DESC));

print(query.toSQL());
// SELECT `department`, COUNT(`id`) AS `employee_count` FROM `employees` 
// WHERE ( `active` = true ) GROUP BY `department` 
// HAVING ( COUNT(`id`) > 5 ) ORDER BY `employee_count` DESC
```

### Parameterized Queries

```dart
var query = Sqler()
  .addSelect(QSelect('*'))
  .from(QField('users'))
  .where(WhereOne(QField('name'), QO.EQ, QParam('user_name')))
  .param('user_name', QVar('John Doe'));

print(query.toSQL());
// SELECT * FROM `users` WHERE ( `name` = :user_name )

var params = query.getParams();
// {'user_name': QVar('John Doe')}
```

## Operators

The `QO` class provides various comparison operators:

- `QO.EQ` - Equal (=)
- `QO.NE` - Not Equal (!=)
- `QO.GT` - Greater Than (>)
- `QO.GTE` - Greater Than or Equal (>=)
- `QO.LT` - Less Than (<)
- `QO.LTE` - Less Than or Equal (<=)
- `QO.LIKE` - LIKE pattern matching
- `QO.NOT_LIKE` - NOT LIKE pattern matching
- `QO.IN` - IN list
- `QO.NOT_IN` - NOT IN list
- `QO.IS_NULL` - IS NULL
- `QO.IS_NOT_NULL` - IS NOT NULL

## WHERE Conditions

### Basic Conditions
```dart
WhereOne(QField('status'), QO.EQ, QVar('active'))
```

### Combined Conditions
```dart
AndWhere([
  WhereOne(QField('active'), QO.EQ, QVar(true)),
  WhereOne(QField('age'), QO.GTE, QVar(18))
])

OrWhere([
  WhereOne(QField('role'), QO.EQ, QVar('admin')),
  WhereOne(QField('role'), QO.EQ, QVar('moderator'))
])
```

## JOIN Types

- `InnerJoin` - INNER JOIN
- `LeftJoin` - LEFT JOIN  
- `RightJoin` - RIGHT JOIN

```dart
.join(InnerJoin('table2', On([
  Condition(QField('table1.id'), QO.EQ, QField('table2.table1_id'))
])))
```

## 🚀 Beta Release - Your Contribution Matters!

**Sqler is currently in beta!** We're excited to share this powerful SQL query builder with the Dart community, and we'd love your help to make it even better.

### How You Can Help

This beta release means we're actively looking for feedback and contributions from developers like you! Here are some ways you can get involved:

- 🐛 **Bug Reports**: Found something that doesn't work as expected? Please open an issue!
- 📝 **Documentation**: Help us improve our documentation, examples, and guides
- 💡 **Feature Requests**: Have ideas for new features? We'd love to hear them!
- 🔧 **Code Contributions**: Submit pull requests to help improve the codebase
- 🧪 **Testing**: Use Sqler in your projects and share your experience

### Show Your Support

Since we use **stars and ratings as our main metric** to gauge community interest and guide our development priorities, we'd really appreciate it if you could:

- ⭐ **Star us on GitHub**: Help others discover Sqler!
- 👍 **Like this package**: Your support motivates us to keep improving
- 📢 **Share with others**: Tell your fellow developers about Sqler

Your feedback and contributions are invaluable in helping us build the best SQL query builder for Dart. Thank you for being part of our journey! 🙏

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Repository

[https://github.com/uproid/sqler](https://github.com/uproid/sqler)