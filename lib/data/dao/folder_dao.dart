import 'package:sqflite/sqflite.dart';

/// 只做 SQL，不做模型映射：返回原始行。
class FolderDao {
  FolderDao(this._db);

  final DatabaseExecutor _db;

  static const String table = 'folders';

  Future<List<Map<String, Object?>>> findAll() {
    return _db.query(table, orderBy: 'sort_order ASC, created_at ASC');
  }

  Future<void> upsert(Map<String, Object?> row) async {
    await _db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> delete(String id) {
    return _db.delete(table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<String?> findIdByName(String name) async {
    final List<Map<String, Object?>> rows = await _db.query(
      table,
      columns: <String>['id'],
      where: 'name = ?',
      whereArgs: <Object?>[name],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as String?;
  }

  Future<void> applySortOrders(Map<String, int> orders) async {
    final Batch batch = _db.batch();
    orders.forEach((String id, int order) {
      batch.update(
        table,
        <String, Object?>{'sort_order': order},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
    await batch.commit(noResult: true);
  }

  /// 删除文件夹不删记录：记录转为未分类。
  Future<void> detachRecords(String folderId) {
    return _db.update(
      'records',
      <String, Object?>{'folder_id': null},
      where: 'folder_id = ?',
      whereArgs: <Object?>[folderId],
    );
  }

  Future<int> countRecords(String folderId) async {
    final List<Map<String, Object?>> rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM records WHERE folder_id = ? AND deleted_at IS NULL',
      <Object?>[folderId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
