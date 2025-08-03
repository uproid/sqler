import 'package:sqler/sqler.dart';
import 'package:test/test.dart';

void main() {
  group('check insert sql', () {
    test('test insert one record', () {
      var query =
          Sqler()..insert(QField('books'), [
            {
              'title': QVar('Dart Programming'),
              'author': QVar('John Doe'),
              'published_date': QVar('2023-10-01'),
              'published': QVar(true),
              'pages': QVar(300),
            },
          ]);

      expect(
        query.toSQL(),
        "INSERT INTO `books` (`title`, `author`, `published_date`, `published`, `pages`) VALUES ('Dart Programming', 'John Doe', '2023-10-01', true, 300)",
      );
    });

    test('test insert many records', () {
      var query =
          Sqler()..insert(QField('books'), [
            {
              'title': QVar('Dart Programming'),
              'author': QVar('John Doe'),
              'published_date': QVar('2023-10-01'),
              'published': QVar(true),
              'pages': QVar(300),
            },
            {
              'title': QVar('Flutter Development'),
              'author': QVar('Jane Smith'),
              'published_date': QVar('2023-11-01'),
              'published': QVar(false),
              'pages': QVar(250),
            },
          ]);

      expect(
        query.toSQL(),
        "INSERT INTO `books` (`title`, `author`, `published_date`, `published`, `pages`) VALUES ('Dart Programming', 'John Doe', '2023-10-01', true, 300), ('Flutter Development', 'Jane Smith', '2023-11-01', false, 250)",
      );
    });
  });
}
