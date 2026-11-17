import 'package:sqflite/sqflite.dart';
import 'package:zlogbook/data/dao/settings_dao.dart';
import 'package:zlogbook/data/db/app_database.dart';
import 'package:zlogbook/repositories/ledger_repositories.dart';

class SqliteSettingsRepository implements SettingsRepository {
  SqliteSettingsRepository({Future<Database> Function()? open})
      : _open = open ?? AppDatabase.instance.open;

  final Future<Database> Function() _open;

  Future<SettingsDao> _dao() async => SettingsDao(await _open());

  @override
  Future<Map<String, String>> loadAll() async {
    final SettingsDao dao = await _dao();
    return dao.loadAll();
  }

  @override
  Future<void> put(String key, String? value) async {
    final SettingsDao dao = await _dao();
    await dao.put(key, value);
  }
}
