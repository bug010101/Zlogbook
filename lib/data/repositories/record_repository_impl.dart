import 'package:sqflite/sqflite.dart';
import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/data/dao/record_dao.dart';
import 'package:zlogbook/data/db/app_database.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/record.dart';
import 'package:zlogbook/repositories/ledger_repositories.dart';

class SqliteRecordRepository implements RecordRepository {
  SqliteRecordRepository({Future<Database> Function()? open})
      : _open = open ?? AppDatabase.instance.open;

  final Future<Database> Function() _open;

  Future<RecordDao> _dao() async => RecordDao(await _open());

  @override
  Future<List<AssetRecord>> activeRecords() async {
    final RecordDao dao = await _dao();
    final List<Map<String, Object?>> rows = await dao.findActive();
    return rows.map(AssetRecord.fromMap).toList();
  }

  @override
  Future<List<AssetRecord>> trashedRecords() async {
    final RecordDao dao = await _dao();
    final List<Map<String, Object?>> rows = await dao.findTrashed();
    return rows.map(AssetRecord.fromMap).toList();
  }

  @override
  Future<void> save(AssetRecord record) async {
    final RecordDao dao = await _dao();
    await dao.upsert(record.toMap());
  }

  @override
  Future<void> softDelete(String id) async {
    final RecordDao dao = await _dao();
    await dao.softDelete(id, isoDateTime(DateTime.now()));
  }

  @override
  Future<void> restore(String id) async {
    final RecordDao dao = await _dao();
    await dao.restore(id);
  }

  @override
  Future<void> purge(String id) async {
    final RecordDao dao = await _dao();
    await dao.purge(id);
  }

  @override
  Future<void> purgeTrash() async {
    final RecordDao dao = await _dao();
    await dao.purgeAllTrashed();
  }

  @override
  Future<void> updateStatuses(List<String> ids, RecordStatus status) async {
    final RecordDao dao = await _dao();
    await dao.updateStatus(ids, status.code, isoDateTime(DateTime.now()));
  }

  @override
  Future<void> moveToFolder(List<String> ids, String? folderId) async {
    final RecordDao dao = await _dao();
    await dao.moveToFolder(ids, folderId, isoDateTime(DateTime.now()));
  }

  @override
  Future<void> addTag(List<String> ids, String tag) async {
    final String cleaned = tag.trim();
    if (cleaned.isEmpty) {
      return;
    }
    final RecordDao dao = await _dao();
    final List<Map<String, Object?>> rows = await dao.findByIds(ids);
    for (final Map<String, Object?> row in rows) {
      final AssetRecord record = AssetRecord.fromMap(row);
      if (record.tags.contains(cleaned)) {
        continue;
      }
      final AssetRecord updated = record.copyWith(
        tags: <String>[...record.tags, cleaned],
        updatedAt: DateTime.now(),
      );
      await dao.upsert(updated.toMap());
    }
  }

  @override
  Future<int> count() async {
    final RecordDao dao = await _dao();
    return dao.countActive();
  }
}
