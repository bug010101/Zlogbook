import 'package:sqflite/sqflite.dart';

class IdentityDao {
  IdentityDao(this._db);

  final DatabaseExecutor _db;

  static const String table = 'identities';

  Future<List<Map<String, Object?>>> findAll() {
    return _db.query(table, orderBy: 'created_at ASC');
  }

  Future<void> upsert(Map<String, Object?> row) async {
    await _db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> delete(String id) {
    return _db.delete(table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<Map<String, Object?>?> findById(String id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> findByKindAndValue(
    String kind,
    String value,
  ) async {
    final List<Map<String, Object?>> rows = await _db.query(
      table,
      where: 'kind = ? AND value = ?',
      whereArgs: <Object?>[kind, value],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}
