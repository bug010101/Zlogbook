import 'package:flutter/foundation.dart';
import 'package:zlogbook/core/app_info.dart';
import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/core/utils/ids.dart';
import 'package:zlogbook/core/utils/text_utils.dart';
import 'package:zlogbook/data/repositories/field_def_repository_impl.dart';
import 'package:zlogbook/data/repositories/folder_repository_impl.dart';
import 'package:zlogbook/data/repositories/identity_repository_impl.dart';
import 'package:zlogbook/data/repositories/record_repository_impl.dart';
import 'package:zlogbook/data/repositories/settings_repository_impl.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/field_def.dart';
import 'package:zlogbook/models/folder.dart';
import 'package:zlogbook/models/identity.dart';
import 'package:zlogbook/models/identity_usage.dart';
import 'package:zlogbook/models/login_method.dart';
import 'package:zlogbook/models/record.dart';
import 'package:zlogbook/repositories/ledger_repositories.dart';

/// 应用唯一状态源：持有内存数据、筛选条件与偏好，所有写操作走仓储后刷新内存。
class AppState extends ChangeNotifier {
  AppState({
    FolderRepository? folderRepository,
    RecordRepository? recordRepository,
    IdentityRepository? identityRepository,
    FieldDefRepository? fieldDefRepository,
    SettingsRepository? settingsRepository,
  })  : _folderRepo = folderRepository ?? SqliteFolderRepository(),
        _recordRepo = recordRepository ?? SqliteRecordRepository(),
        _identityRepo = identityRepository ?? SqliteIdentityRepository(),
        _fieldRepo = fieldDefRepository ?? SqliteFieldDefRepository(),
        _settingsRepo = settingsRepository ?? SqliteSettingsRepository();

  final FolderRepository _folderRepo;
  final RecordRepository _recordRepo;
  final IdentityRepository _identityRepo;
  final FieldDefRepository _fieldRepo;
  final SettingsRepository _settingsRepo;

  List<Folder> _folders = const <Folder>[];
  List<AssetRecord> _records = const <AssetRecord>[];
  List<AssetRecord> _trashed = const <AssetRecord>[];
  List<Identity> _identities = const <Identity>[];
  List<FieldDef> _fieldDefs = const <FieldDef>[];
  Map<String, String> _folderNames = const <String, String>{};
  Map<String, List<IdentityUsage>> _usageIndex =
      const <String, List<IdentityUsage>>{};

  bool _ready = false;
  String? _error;

  String _query = '';
  String? _folderFilter;
  StatusFilter _statusFilter = StatusFilter.all;
  SortMode _sortMode = SortMode.updatedDesc;
  bool _timeline = false;
  LoginKind _lastLoginKind = LoginKind.phone;

  // ------------------------------------------------------------ 只读访问

  bool get isReady => _ready;

  String? get error => _error;

  List<Folder> get folders => _folders;

  List<AssetRecord> get records => _records;

  List<AssetRecord> get trashedRecords => _trashed;

  List<Identity> get identities => _identities;

  List<FieldDef> get fieldDefs => _fieldDefs;

  String get query => _query;

  String? get folderFilter => _folderFilter;

  StatusFilter get statusFilter => _statusFilter;

  SortMode get sortMode => _sortMode;

  bool get timelineView => _timeline;

  LoginKind get lastLoginKind => _lastLoginKind;

  int get activeCount => _records.length;

  int get trashedCount => _trashed.length;

  Folder? folderById(String? id) {
    if (id == null) {
      return null;
    }
    for (final Folder folder in _folders) {
      if (folder.id == id) {
        return folder;
      }
    }
    return null;
  }

  String folderName(String? id) {
    if (id == null) {
      return kUncategorizedLabel;
    }
    return _folderNames[id] ?? kUncategorizedLabel;
  }

  Identity? identityById(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final Identity identity in _identities) {
      if (identity.id == id) {
        return identity;
      }
    }
    return null;
  }

  Identity? identityByValue(LoginKind kind, String value) {
    final String target = value.trim();
    if (target.isEmpty) {
      return null;
    }
    for (final Identity identity in _identities) {
      if (identity.value.trim() == target &&
          (kind == LoginKind.other || identity.kind == kind)) {
        return identity;
      }
    }
    return null;
  }

  /// 登录方式的真实账号：引用身份池时取池里的最新值。
  String accountOf(LoginMethod login) {
    final Identity? identity = identityById(login.identityId);
    return identity?.value ?? login.account;
  }

  /// 展示用账号，手机号脱敏。
  String accountDisplay(LoginMethod login) {
    final String value = accountOf(login);
    return login.kind == LoginKind.phone ? maskPhone(value) : value;
  }

  String loginSummary(LoginMethod login) =>
      '${login.kind.label} · ${accountDisplay(login)}';

  List<IdentityUsage> usagesOf(String identityId) =>
      _usageIndex[identityId] ?? const <IdentityUsage>[];

  List<FieldDef> fieldDefsFor(String? folderId) =>
      _fieldDefs.where((FieldDef field) => field.appliesTo(folderId)).toList();

  int usageCount(String identityId) => usagesOf(identityId).length;

  // ------------------------------------------------------------ 筛选后的列表

  List<AssetRecord> get visibleRecords {
    final List<String> keywords = splitKeywords(_query);
    Iterable<AssetRecord> result = _records;

    final RecordStatus? status = _statusFilter.recordStatus;
    if (status != null) {
      result = result.where((AssetRecord r) => r.status == status);
    }
    if (_statusFilter == StatusFilter.expiring) {
      result = result.where(_isExpiringSoon);
    }
    if (_folderFilter != null) {
      if (_folderFilter == uncategorizedFilterId) {
        result = result.where((AssetRecord r) => r.folderId == null);
      } else {
        result = result.where((AssetRecord r) => r.folderId == _folderFilter);
      }
    }
    if (keywords.isNotEmpty) {
      result = result.where((AssetRecord r) => _matches(r, keywords));
    }

    final List<AssetRecord> list = result.toList();
    list.sort(_comparator);
    return list;
  }

  /// 「未分类」这个虚拟文件夹的筛选值。
  static const String uncategorizedFilterId = '__none__';

  bool _isExpiringSoon(AssetRecord record) {
    final DateTime? expires = record.expiresAt;
    if (expires == null) {
      return false;
    }
    return daysFromToday(expires) <= kExpiringSoonDays;
  }

  int _compareBy(SortMode mode, AssetRecord a, AssetRecord b) {
    switch (mode) {
      case SortMode.updatedDesc:
        return b.updatedAt.compareTo(a.updatedAt);
      case SortMode.createdDesc:
        return b.createdAt.compareTo(a.createdAt);
      case SortMode.nameAsc:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case SortMode.importanceDesc:
        final int byImportance = b.importance.compareTo(a.importance);
        return byImportance != 0
            ? byImportance
            : b.updatedAt.compareTo(a.updatedAt);
      case SortMode.expiresAsc:
        final DateTime? left = a.expiresAt;
        final DateTime? right = b.expiresAt;
        if (left == null && right == null) {
          return b.updatedAt.compareTo(a.updatedAt);
        }
        if (left == null) {
          return 1;
        }
        if (right == null) {
          return -1;
        }
        return left.compareTo(right);
    }
    return 0;
  }

  int _comparator(AssetRecord a, AssetRecord b) => _compareBy(_sortMode, a, b);

  bool _matches(AssetRecord record, List<String> keywords) {
    final StringBuffer buffer = StringBuffer()
      ..write(record.name)
      ..write(' ')
      ..write(folderName(record.folderId))
      ..write(' ')
      ..write(record.status.label)
      ..write(' ')
      ..write(record.tags.join(' '))
      ..write(' ')
      ..write(record.notes ?? '')
      ..write(' ')
      ..write(record.url ?? '')
      ..write(' ')
      ..write(record.importance)
      ..write(' ');
    for (final LoginMethod login in record.logins) {
      buffer
        ..write(login.kind.label)
        ..write(' ')
        ..write(accountOf(login))
        ..write(' ');
    }
    for (final MapEntry<String, Object?> entry in record.extra.entries) {
      buffer
        ..write(entry.key)
        ..write(' ')
        ..write(_extraText(entry.value))
        ..write(' ');
    }
    final String haystack = buffer.toString().toLowerCase();
    for (final String keyword in keywords) {
      if (!haystack.contains(keyword)) {
        return false;
      }
    }
    return true;
  }

  static String _extraText(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is List) {
      return value.map((Object? item) => '$item').join(' ');
    }
    if (value is DateTime) {
      return formatDate(value);
    }
    return '$value';
  }

  // ------------------------------------------------------------ 启动与刷新

  Future<void> bootstrap() async {
    try {
      await _loadSettings();
      await reloadAll();
    } catch (error) {
      _error = error.toString();
      _ready = true;
      notifyListeners();
    }
  }

  Future<void> reloadAll() async {
    _folders = await _folderRepo.all();
    _records = await _recordRepo.activeRecords();
    _trashed = await _recordRepo.trashedRecords();
    _identities = await _identityRepo.all();
    _fieldDefs = await _fieldRepo.all();
    _rebuildIndexes();
    _ready = true;
    notifyListeners();
  }

  Future<void> _reloadRecords() async {
    _records = await _recordRepo.activeRecords();
    _trashed = await _recordRepo.trashedRecords();
    _rebuildIndexes();
    notifyListeners();
  }

  Future<void> _reloadFolders() async {
    _folders = await _folderRepo.all();
    _rebuildIndexes();
    notifyListeners();
  }

  Future<void> _reloadIdentities() async {
    _identities = await _identityRepo.all();
    notifyListeners();
  }

  void _rebuildIndexes() {
    final Map<String, String> names = <String, String>{};
    for (final Folder folder in _folders) {
      names[folder.id] = folder.name;
    }
    _folderNames = names;

    final Map<String, List<IdentityUsage>> index =
        <String, List<IdentityUsage>>{};
    for (final AssetRecord record in _records) {
      for (final LoginMethod login in record.logins) {
        final String? id = login.identityId;
        if (id == null || id.isEmpty) {
          continue;
        }
        index
            .putIfAbsent(id, () => <IdentityUsage>[])
            .add(IdentityUsage.of(record, login));
      }
    }
    _usageIndex = index;
  }

  // ------------------------------------------------------------ 偏好

  Future<void> _loadSettings() async {
    final Map<String, String> values = await _settingsRepo.loadAll();
    _sortMode = sortModeOf(values[PrefKeys.sortMode]);
    _timeline = values[PrefKeys.timelineView] == 'true';
    final String? kind = values[PrefKeys.lastLoginKind];
    if (kind != null) {
      _lastLoginKind = loginKindOf(kind);
    }
  }

  void setQuery(String value) {
    if (_query == value) {
      return;
    }
    _query = value;
    notifyListeners();
  }

  void setFolderFilter(String? folderId) {
    _folderFilter = folderId;
    notifyListeners();
  }

  void setStatusFilter(StatusFilter filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  Future<void> setSortMode(SortMode mode) async {
    _sortMode = mode;
    notifyListeners();
    await _settingsRepo.put(PrefKeys.sortMode, mode.code);
  }

  Future<void> setTimelineView(bool value) async {
    _timeline = value;
    notifyListeners();
    await _settingsRepo.put(PrefKeys.timelineView, value ? 'true' : 'false');
  }

  Future<void> setLastLoginKind(LoginKind kind) async {
    _lastLoginKind = kind;
    await _settingsRepo.put(PrefKeys.lastLoginKind, kind.code);
  }

  void clearFilters() {
    _query = '';
    _folderFilter = null;
    _statusFilter = StatusFilter.all;
    notifyListeners();
  }

  // ------------------------------------------------------------ 记录写操作

  Future<AssetRecord> saveRecord(AssetRecord record) async {
    final AssetRecord stamped = record.copyWith(updatedAt: DateTime.now());
    await _recordRepo.save(stamped);
    await _reloadRecords();
    return stamped;
  }

  Future<void> deleteRecord(String id) async {
    await _recordRepo.softDelete(id);
    await _reloadRecords();
  }

  Future<void> restoreRecord(String id) async {
    await _recordRepo.restore(id);
    await _reloadRecords();
  }

  Future<void> purgeRecord(String id) async {
    await _recordRepo.purge(id);
    await _reloadRecords();
  }

  Future<void> purgeTrash() async {
    await _recordRepo.purgeTrash();
    await _reloadRecords();
  }

  Future<void> batchUpdateStatus(List<String> ids, RecordStatus status) async {
    await _recordRepo.updateStatuses(ids, status);
    await _reloadRecords();
  }

  Future<void> batchMoveToFolder(List<String> ids, String? folderId) async {
    await _recordRepo.moveToFolder(ids, folderId);
    await _reloadRecords();
  }

  Future<void> batchAddTag(List<String> ids, String tag) async {
    await _recordRepo.addTag(ids, tag);
    await _reloadRecords();
  }

  Future<void> batchDelete(List<String> ids) async {
    for (final String id in ids) {
      await _recordRepo.softDelete(id);
    }
    await _reloadRecords();
  }

  // ------------------------------------------------------------ 文件夹

  Future<Folder> createFolder({
    required String name,
    String icon = 'folder',
    String color = 'slate',
  }) async {
    final Folder folder = Folder(
      id: newId(),
      name: name.trim(),
      icon: icon,
      color: color,
      sortOrder: _folders.length,
      createdAt: DateTime.now(),
    );
    await _folderRepo.save(folder);
    await _reloadFolders();
    return folder;
  }

  Future<void> updateFolder(Folder folder) async {
    await _folderRepo.save(folder);
    await _reloadFolders();
  }

  Future<void> deleteFolder(String id) async {
    await _folderRepo.deleteAndDetach(id);
    if (_folderFilter == id) {
      _folderFilter = null;
    }
    await _reloadFolders();
    await _reloadRecords();
  }

  Future<void> reorderFolders(List<String> orderedIds) async {
    await _folderRepo.reorder(orderedIds);
    await _reloadFolders();
  }

  Future<int> folderRecordCount(String folderId) =>
      _folderRepo.countRecords(folderId);

  // ------------------------------------------------------------ 身份池

  Future<Identity> saveIdentity(Identity identity) async {
    final Identity stamped = identity.copyWith(updatedAt: DateTime.now());
    await _identityRepo.save(stamped);
    await _reloadIdentities();
    return stamped;
  }

  /// 删除身份：引用它的登录方式降级为纯文本，保留最后一次的值。
  Future<void> deleteIdentity(Identity identity) async {
    for (final AssetRecord record in _records) {
      bool touched = false;
      final List<LoginMethod> logins = record.logins.map((LoginMethod login) {
        if (login.identityId != identity.id) {
          return login;
        }
        touched = true;
        return login.copyWith(account: identity.value, identityId: null);
      }).toList();
      if (touched) {
        await _recordRepo.save(
          record.copyWith(logins: logins, updatedAt: DateTime.now()),
        );
      }
    }
    await _identityRepo.delete(identity.id);
    await _reloadRecords();
    await _reloadIdentities();
  }

  Future<Identity?> findIdentity(LoginKind kind, String value) =>
      _identityRepo.findByKindAndValue(kind, value);

  // ------------------------------------------------------------ 自定义字段

  Future<FieldDef> createFieldDef(FieldDef def) async {
    final FieldDef created = def.copyWith(sortOrder: _fieldDefs.length);
    await _fieldRepo.save(created);
    _fieldDefs = await _fieldRepo.all();
    notifyListeners();
    return created;
  }

  Future<void> updateFieldDef(FieldDef def) async {
    await _fieldRepo.save(def);
    _fieldDefs = await _fieldRepo.all();
    notifyListeners();
  }

  Future<void> deleteFieldDef(String id) async {
    await _fieldRepo.delete(id);
    _fieldDefs = await _fieldRepo.all();
    notifyListeners();
  }

  Future<void> reorderFieldDefs(List<String> orderedIds) async {
    await _fieldRepo.reorder(orderedIds);
    _fieldDefs = await _fieldRepo.all();
    notifyListeners();
  }

  /// 导出用的数据副本：登录方式的账号替换成身份池里的最新值。
  List<AssetRecord> resolvedRecordsForExport() {
    return _records
        .map(
          (AssetRecord record) => record.copyWith(
            logins: record.logins
                .map((LoginMethod login) => login.copyWith(account: accountOf(login)))
                .toList(),
          ),
        )
        .toList();
  }

  /// 记录里出现过的标签，供补全提示使用。
  List<String> get allTags {
    final Set<String> tags = <String>{};
    for (final AssetRecord record in _records) {
      tags.addAll(record.tags);
    }
    final List<String> list = tags.toList()..sort();
    return list;
  }
}
