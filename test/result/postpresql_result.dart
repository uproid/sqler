import 'package:postgres/postgres.dart';

class PostgresResult {
  static const String _countRecordsField = 'count_records';
  final Result? _result;

  String errorMsg;
  PostgresResult(this._result, {this.errorMsg = ''});

  bool get success => errorMsg.isEmpty;
  bool get error => !success;

  List<ResultRow> get rows => _result?.toList() ?? [];
  int get affectedRows => _result?.affectedRows ?? 0;
  List<String> get cols =>
      _result?.schema.columns
          .map((c) => c.columnName ?? '')
          .where((n) => n.isNotEmpty)
          .toList() ??
      [];

  List<Map<String, String?>> get assoc {
    return rows.map((row) {
      final map = row.toColumnMap();
      return map.map((k, v) => MapEntry(k, v?.toString()));
    }).toList();
  }

  Map<String, String?>? get assocFirst {
    if (rows.isEmpty) return null;
    return assoc.first;
  }

  Map<String, String?>? get assocLast {
    if (rows.isEmpty) return null;
    return assoc.last;
  }

  int get countRecords {
    return int.tryParse((assocFirst?[_countRecordsField] ?? 0).toString()) ?? 0;
  }
}
