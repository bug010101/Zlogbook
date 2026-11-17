import 'package:sqflite/sqflite.dart';

/// 记录表 SQL。软删除通过 deleted_at 实现。
class RecordDao {
  RecordDao(this._db);

  final DatabaseExecutor _db;

  static const String table = 'records';

  Future<List<Map<String, Object?>>> findActive() {
    return _db.query(
      table,
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
    );
  }

  Future<List<Map<String, Object?>>> findTrashed() {
    return _db.query(
      table,
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC',
    );
  }

  Future<void> upsert(Map<String, Object?> row) async {
    await _db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> softDelete(String id, String deletedAt) {
    return _db.update(
      table,
      <String, Object?>{'deleted_at': deletedAt},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> restore(String id) {
    return _db.update(
      table,
      <String, Object?>{'deleted_at': null},
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> purge(String id) {
    return _db.delete(table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<int> purgeAllTrashed() {
    return _db.delete(table, where: 'deleted_at IS NOT NULL');
  }

  static String _placeholders(int count) =>
      List<String>.filled(count, '?').join(', ');

  Future<int> updateStatus(List<String> ids, String status, String updatedAt) {
    if (ids.isEmpty) {
      return Future<int>.value(0);
    }
    return _db.update(
      table,
      <String, Object?>{'status': status, 'updated_at': updatedAt},
      where: 'id IN (${_placeholders(ids.length)})',
      whereArgs: ids,
    );
  }

  Future<int> moveToFolder(
    List<String> ids,
    String? folderId,
    String updatedAt,
  ) {
    if (ids.isEmpty) {
      return Future<int>.value(0);
    }
    return _db.update(
      table,
      <String, Object?>{'folder_id': folderId, 'updated_at': updatedAt},
      where: 'id IN (${_placeholders(ids.length)})',
      whereArgs: ids,
    );
  }

  Future<List<Map<String, Object?>>> findByIds(List<String> ids) async {
    if (ids.isEmpty) {
      return <Map<String, Object?>>[];
    }
    return _db.query(
      table,
      where: 'id IN (${_placeholders(ids.length)})',
      whereArgs: ids,
    );
  }

  Future<int> countActive() async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM records WHERE deleted_at IS NULL',
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
