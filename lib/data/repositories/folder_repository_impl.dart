import 'package:sqflite/sqflite.dart';
import 'package:zlogbook/data/dao/folder_dao.dart';
import 'package:zlogbook/data/db/app_database.dart';
import 'package:zlogbook/models/folder.dart';
import 'package:zlogbook/repositories/ledger_repositories.dart';

class SqliteFolderRepository implements FolderRepository {
  SqliteFolderRepository({Future<Database> Function()? open})
      : _open = open ?? AppDatabase.instance.open;

  final Future<Database> Function() _open;

  Future<FolderDao> _dao() async => FolderDao(await _open());

  @override
  Future<List<Folder>> all() async {
    final FolderDao dao = await _dao();
    final List<Map<String, Object?>> rows = await dao.findAll();
    return rows.map(Folder.fromMap).toList();
  }

  @override
  Future<void> save(Folder folder) async {
    final FolderDao dao = await _dao();
    await dao.upsert(folder.toMap());
  }

  @override
  Future<void> deleteAndDetach(String id) async {
    final FolderDao dao = await _dao();
    await dao.detachRecords(id);
    await dao.delete(id);
  }

  @override
  Future<void> reorder(List<String> orderedIds) async {
    final FolderDao dao = await _dao();
    final Map<String, int> orders = <String, int>{};
    for (int i = 0; i < orderedIds.length; i++) {
      orders[orderedIds[i]] = i;
    }
    await dao.applySortOrders(orders);
  }

  @override
  Future<int> countRecords(String folderId) async {
    final FolderDao dao = await _dao();
    return dao.countRecords(folderId);
  }
}
