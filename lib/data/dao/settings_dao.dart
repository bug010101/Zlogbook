import 'package:sqflite/sqflite.dart';

/// 键值表，只放界面偏好这类基础设施数据，不参与业务导出。
class SettingsDao {
  SettingsDao(this._db);

  final DatabaseExecutor _db;

  static const String table = 'settings';

  Future<Map<String, String>> loadAll() async {
    final List<Map<String, Object?>> rows = await _db.query(table);
    final Map<String, String> result = <String, String>{};
    for (final Map<String, Object?> row in rows) {
      final String? key = row['key'] as String?;
      final String? value = row['value'] as String?;
      if (key != null && value != null) {
        result[key] = value;
      }
    }
    return result;
  }

  Future<void> put(String key, String? value) async {
    if (value == null) {
      await _db.delete(table, where: 'key = ?', whereArgs: <Object?>[key]);
      return;
    }
    await _db.insert(
      table,
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
