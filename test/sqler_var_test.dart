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

  group('Test Password QVar', () {
    test('test password with md5', () {
      var var1 = QVar.password('test', type: HashType.md5);
      expect(var1.toSQL(), "'098f6bcd4621d373cade4e832627b4f6'");
    });

    test('test password with sha1', () {
      var var1 = QVar.password('test', type: HashType.sha1);
      expect(var1.toSQL(), "'a94a8fe5ccb19ba61c4c0873d391e987982fbbd3'");
    });

    test('test password with sha256', () {
      var var1 = QVar.password('test', type: HashType.sha256);
      expect(
        var1.toSQL(),
        "'9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08'",
      );
    });

    test('test password with sha512', () {
      var var1 = QVar.password('test', type: HashType.sha512);
      expect(
        var1.toSQL(),
        "'ee26b0dd4af7e749aa1a8ee3c10ae9923f618980772"
        "e473f8819a5d4940e0db27ac185f8a0e1d5f84f88b"
        "c887fd67b143732c304cc5fa9ad8e6f57f50028a8ff'",
      );
    });

    test('test password with hmac sha256', () {
      var var1 = QVar.password('test', type: HashType.HMAC, hmacKey: 'secret');
      var var2 = QVar.password('test', type: HashType.HMAC, hmacKey: 'secret2');
      expect(
        var1.toSQL(),
        "'0329a06b62cd16b33eb6792be8c60b158d89a2ee3a876fce9a881ebb488c0914'",
      );
      expect(
        var2.toSQL() ==
            "'0329a06b62cd16b33eb6792be8c60b15"
                "8d89a2ee3a876fce9a881ebb488c0914'",
        isFalse,
      );
    });
  });
}
