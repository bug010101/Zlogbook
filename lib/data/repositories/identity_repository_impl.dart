import 'package:sqflite/sqflite.dart';
import 'package:zlogbook/data/dao/identity_dao.dart';
import 'package:zlogbook/data/db/app_database.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/identity.dart';
import 'package:zlogbook/repositories/ledger_repositories.dart';

class SqliteIdentityRepository implements IdentityRepository {
  SqliteIdentityRepository({Future<Database> Function()? open})
      : _open = open ?? AppDatabase.instance.open;

  final Future<Database> Function() _open;

  Future<IdentityDao> _dao() async => IdentityDao(await _open());

  @override
  Future<List<Identity>> all() async {
    final IdentityDao dao = await _dao();
    final List<Map<String, Object?>> rows = await dao.findAll();
    return rows.map(Identity.fromMap).toList();
  }

  @override
  Future<void> save(Identity identity) async {
    final IdentityDao dao = await _dao();
    await dao.upsert(identity.toMap());
  }

  @override
  Future<Identity?> find(String id) async {
    final IdentityDao dao = await _dao();
    final Map<String, Object?>? row = await dao.findById(id);
    return row == null ? null : Identity.fromMap(row);
  }

  @override
  Future<Identity?> findByKindAndValue(LoginKind kind, String value) async {
    final IdentityDao dao = await _dao();
    final Map<String, Object?>? row =
        await dao.findByKindAndValue(kind.code, value);
    return row == null ? null : Identity.fromMap(row);
  }

  @override
  Future<void> delete(String id) async {
    final IdentityDao dao = await _dao();
    await dao.delete(id);
  }
}
