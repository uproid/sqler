import 'dart:math';

import 'package:sqler/src/mysql_model.dart';
import 'package:test/test.dart';

void main() {
  group('MTable Fields Validator', () {
    test('validates correct input values', () async {
      MTable table = MTable(
        name: 'books',
        fields: [
          MFieldInt(
            name: 'id',
            isPrimaryKey: true,
            isAutoIncrement: true,
            validators: [
              (value) async =>
                  value is int && value > 0
                      ? ''
                      : 'ID must be a positive integer',
            ],
          ),
          MFieldVarchar(
            name: 'title',
            length: 255,
            validators: [
              (value) async =>
                  value.toString().length < 5
                      ? 'Title must be at least 5 characters long'
                      : '',
            ],
          ),
          MFieldVarchar(name: 'author', length: 255),
          MFieldDate(
            name: 'published_date',
            validators: [
              (value) async =>
                  value is DateTime && value.isBefore(DateTime.now())
                      ? ''
                      : 'Published date must be a date in the past',
            ],
          ),
          MFieldBoolean(
            name: 'published',
            validators: [
              (value) async =>
                  value is bool ? '' : 'Published must be a boolean',
            ],
          ),
          MFieldInt(name: 'pages'),
        ],
      );

      var validInput = {
        'id': 1,
        'title': 'Dart',
        'author': 'John Doe',
        'published_date': DateTime(DateTime.now().year + 1, 10, 1),
        'published': 'true',
        'pages': 300,
        'aaaaa': 'extra field',
      };

      var result = await table.formValidate(validInput);

      expect(result, isMap);
      expect(result['id'], []);
      expect(result['title'], ['Title must be at least 5 characters long']);
      expect(result['published_date'], [
        'Published date must be a date in the past',
      ]);
      expect(result['published'], ['Published must be a boolean']);
    });
  });
}
