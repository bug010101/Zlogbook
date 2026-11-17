import 'package:sqflite/sqflite.dart';
import 'package:zlogbook/data/dao/field_def_dao.dart';
import 'package:zlogbook/data/db/app_database.dart';
import 'package:zlogbook/models/field_def.dart';
import 'package:zlogbook/repositories/ledger_repositories.dart';

class SqliteFieldDefRepository implements FieldDefRepository {
  SqliteFieldDefRepository({Future<Database> Function()? open})
      : _open = open ?? AppDatabase.instance.open;

  final Future<Database> Function() _open;

  Future<FieldDefDao> _dao() async => FieldDefDao(await _open());

  @override
  Future<List<FieldDef>> all() async {
    final FieldDefDao dao = await _dao();
    final List<Map<String, Object?>> rows = await dao.findAll();
    return rows.map(FieldDef.fromMap).toList();
  }

  @override
  Future<void> save(FieldDef def) async {
    final FieldDefDao dao = await _dao();
    await dao.upsert(def.toMap());
  }

  @override
  Future<void> delete(String id) async {
    final FieldDefDao dao = await _dao();
    await dao.delete(id);
  }

  @override
  Future<void> reorder(List<String> orderedIds) async {
    final FieldDefDao dao = await _dao();
    final Map<String, int> orders = <String, int>{};
    for (int i = 0; i < orderedIds.length; i++) {
      orders[orderedIds[i]] = i;
    }
    await dao.applySortOrders(orders);
  }
}
