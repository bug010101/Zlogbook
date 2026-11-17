import 'package:sqflite/sqflite.dart';

class FieldDefDao {
  FieldDefDao(this._db);

  final DatabaseExecutor _db;

  static const String table = 'field_defs';

  Future<List<Map<String, Object?>>> findAll() {
    return _db.query(table, orderBy: 'sort_order ASC, label ASC');
  }

  Future<void> upsert(Map<String, Object?> row) async {
    await _db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> delete(String id) {
    return _db.delete(table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<Map<String, Object?>?> findByLabel(String label) async {
    final List<Map<String, Object?>> rows = await _db.query(
      table,
      where: 'label = ?',
      whereArgs: <Object?>[label],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
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
}
