import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/field_def.dart';
import 'package:zlogbook/models/folder.dart';
import 'package:zlogbook/models/identity.dart';
import 'package:zlogbook/models/record.dart';

/// 领域层仓储接口。页面与状态层只依赖接口，数据层负责实现。
abstract class FolderRepository {
  Future<List<Folder>> all();

  Future<void> save(Folder folder);

  /// 删除文件夹：记录转为未分类，不删记录。
  Future<void> deleteAndDetach(String id);

  Future<void> reorder(List<String> orderedIds);

  Future<int> countRecords(String folderId);
}

abstract class RecordRepository {
  Future<List<AssetRecord>> activeRecords();

  Future<List<AssetRecord>> trashedRecords();

  Future<void> save(AssetRecord record);

  Future<void> softDelete(String id);

  Future<void> restore(String id);

  Future<void> purge(String id);

  Future<void> purgeTrash();

  Future<void> updateStatuses(List<String> ids, RecordStatus status);

  Future<void> moveToFolder(List<String> ids, String? folderId);

  Future<void> addTag(List<String> ids, String tag);

  Future<int> count();
}

abstract class IdentityRepository {
  Future<List<Identity>> all();

  Future<void> save(Identity identity);

  Future<Identity?> find(String id);

  Future<Identity?> findByKindAndValue(LoginKind kind, String value);

  Future<void> delete(String id);
}

abstract class FieldDefRepository {
  Future<List<FieldDef>> all();

  Future<void> save(FieldDef def);

  Future<void> delete(String id);

  Future<void> reorder(List<String> orderedIds);
}

abstract class SettingsRepository {
  Future<Map<String, String>> loadAll();

  Future<void> put(String key, String? value);
}
