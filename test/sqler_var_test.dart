import 'package:sqler/sqler.dart';
import 'package:test/test.dart';

void main() {
  group('Test Variables', () {
    test('test variable creation', () {
      var var1 = QVar('test');
      expect(var1.toSQL(), "'test'");
    });

    test('test variable with number', () {
      var var1 = QVar(123);
      expect(var1.toSQL(), '123');
    });

    test('test variable with float', () {
      var var1 = QVar(123.45);
      expect(var1.toSQL(), '123.45');
    });

    test('test variable with boolean - true', () {
      var var1 = QVar(true);
      expect(var1.toSQL(), 'true');
    });

    test('test variable with boolean - false', () {
      var var1 = QVar(false);
      expect(var1.toSQL(), 'false');
    });

    test('test variable with null', () {
      var var1 = QVar(null);
      expect(var1.toSQL(), 'NULL');
    });

    test('test variable with date', () {
      var date = DateTime(2023, 10, 1);
      var var1 = QVar(date);
      expect(
        var1.toSQL(),
        "'${DateTime.parse('2023-10-01 00:00:00').toIso8601String()}'",
      );
    });

    test('test variable with list', () {
      var var1 = QVar(['a', 'b', 'c']);
      expect(var1.toSQL(), "('a', 'b', 'c')");
    });
  });

  group('Test safty with variables', () {
    test('test variable with SQL injection attempt', () {
      var var1 = QVar("'; DROP TABLE users; --");
      expect(var1.toSQL(), "'\\'; DROP TABLE users; --'");
    });

    test('test variable with special characters', () {
      var var1 = QVar("O'Reilly");
      expect(var1.toSQL(), "'O\\'Reilly'");
    });

    test('test variable with empty string', () {
      var var1 = QVar('');
      expect(var1.toSQL(), "''");
    });

    test('test variable with special characters in list', () {
      var var1 = QVar(['O\'Reilly', 'test']);
      expect(var1.toSQL(), "('O\\'Reilly', 'test')");
    });

    test('test variable with empty string', () {
      var var1 = QVar(';');
      expect(var1.toSQL(), "';'");
    });

    test('test variable with unicode characters', () {
      var var1 = QVar('-- '); // "Hello" in Japanese
      expect(var1.toSQL(), "'-- '");
    });
  });
}
