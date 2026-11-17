/// 所有枚举的存储编码与展示文案集中于此，数据库只存 code。
library;

// ---------------------------------------------------------------- 记录状态

enum RecordStatus { active, idle, abandoned, deactivated }

const List<String> _recordStatusCodes = <String>[
  'active',
  'idle',
  'abandoned',
  'deactivated',
];

const List<String> _recordStatusLabels = <String>['在用', '闲置', '废弃', '已注销'];

extension RecordStatusX on RecordStatus {
  String get code => _recordStatusCodes[index];

  String get label => _recordStatusLabels[index];
}

RecordStatus recordStatusOf(String? code) {
  if (code == null) {
    return RecordStatus.active;
  }
  final int index = _recordStatusCodes.indexOf(code.trim().toLowerCase());
  return index < 0 ? RecordStatus.active : RecordStatus.values[index];
}

// ---------------------------------------------------------------- 登录方式类型

enum LoginKind { phone, email, qq, wechat, password, other }

const List<String> _loginKindCodes = <String>[
  'phone',
  'email',
  'qq',
  'wechat',
  'password',
  'other',
];

const List<String> _loginKindLabels = <String>[
  '手机号',
  '邮箱',
  'QQ',
  '微信',
  '账号/密码',
  '其他',
];

extension LoginKindX on LoginKind {
  String get code => _loginKindCodes[index];

  String get label => _loginKindLabels[index];

  /// 身份池只收真实身份，密码类不入池。
  bool get isIdentityKind => this != LoginKind.password;
}

LoginKind loginKindOf(String? code) {
  if (code == null) {
    return LoginKind.other;
  }
  final int index = _loginKindCodes.indexOf(code.trim().toLowerCase());
  return index < 0 ? LoginKind.other : LoginKind.values[index];
}

List<LoginKind> get identityKinds =>
    LoginKind.values.where((LoginKind kind) => kind.isIdentityKind).toList();

// ---------------------------------------------------------------- 身份状态

enum IdentityStatus { active, idle, deactivated }

const List<String> _identityStatusCodes = <String>[
  'active',
  'idle',
  'deactivated',
];

const List<String> _identityStatusLabels = <String>['在用', '闲置', '已注销'];

extension IdentityStatusX on IdentityStatus {
  String get code => _identityStatusCodes[index];

  String get label => _identityStatusLabels[index];
}

IdentityStatus identityStatusOf(String? code) {
  if (code == null) {
    return IdentityStatus.active;
  }
  final int index = _identityStatusCodes.indexOf(code.trim().toLowerCase());
  return index < 0 ? IdentityStatus.active : IdentityStatus.values[index];
}

// ---------------------------------------------------------------- 自定义字段类型

enum FieldKind { text, number, date, select, multiselect }

const List<String> _fieldKindCodes = <String>[
  'text',
  'number',
  'date',
  'select',
  'multiselect',
];

const List<String> _fieldKindLabels = <String>[
  '文本',
  '数字',
  '日期',
  '单选',
  '多选',
];

extension FieldKindX on FieldKind {
  String get code => _fieldKindCodes[index];

  String get label => _fieldKindLabels[index];

  bool get hasOptions =>
      this == FieldKind.select || this == FieldKind.multiselect;
}

FieldKind fieldKindOf(String? code) {
  if (code == null) {
    return FieldKind.text;
  }
  final int index = _fieldKindCodes.indexOf(code.trim().toLowerCase());
  return index < 0 ? FieldKind.text : FieldKind.values[index];
}

// ---------------------------------------------------------------- 字段作用范围

enum FieldScope { all, folder }

const List<String> _fieldScopeCodes = <String>['all', 'folder'];

extension FieldScopeX on FieldScope {
  String get code => _fieldScopeCodes[index];
}

FieldScope fieldScopeOf(String? code) {
  if (code == null) {
    return FieldScope.all;
  }
  final int index = _fieldScopeCodes.indexOf(code.trim().toLowerCase());
  return index < 0 ? FieldScope.all : FieldScope.values[index];
}

// ---------------------------------------------------------------- 筛选与排序

enum StatusFilter { all, active, idle, abandoned, deactivated, expiring }

const List<String> _statusFilterLabels = <String>[
  '全部',
  '在用',
  '闲置',
  '废弃',
  '已注销',
  '即将到期',
];

extension StatusFilterX on StatusFilter {
  String get label => _statusFilterLabels[index];

  RecordStatus? get recordStatus {
    switch (this) {
      case StatusFilter.active:
        return RecordStatus.active;
      case StatusFilter.idle:
        return RecordStatus.idle;
      case StatusFilter.abandoned:
        return RecordStatus.abandoned;
      case StatusFilter.deactivated:
        return RecordStatus.deactivated;
      case StatusFilter.all:
      case StatusFilter.expiring:
        return null;
    }
    return null;
  }
}

enum SortMode { updatedDesc, createdDesc, nameAsc, importanceDesc, expiresAsc }

const List<String> _sortModeCodes = <String>[
  'updated_desc',
  'created_desc',
  'name_asc',
  'importance_desc',
  'expires_asc',
];

const List<String> _sortModeLabels = <String>[
  '最近修改',
  '最近创建',
  '名称',
  '重要度',
  '到期日',
];

extension SortModeX on SortMode {
  String get code => _sortModeCodes[index];

  String get label => _sortModeLabels[index];
}

SortMode sortModeOf(String? code) {
  final int index = _sortModeCodes.indexOf((code ?? '').trim());
  return index < 0 ? SortMode.updatedDesc : SortMode.values[index];
}

/// 重要度文案，1–5。
String importanceLabel(int value) {
  switch (value) {
    case 1:
      return '可弃';
    case 2:
      return '次要';
    case 3:
      return '常规';
    case 4:
      return '重要';
    case 5:
      return '核心';
    default:
      return '常规';
  }
}
