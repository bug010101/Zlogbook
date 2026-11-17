/// CSV 列名单一事实来源：解析、导出、内置说明面板都从这里取，加列只需要改这里。
library;

class CsvColumns {
  const CsvColumns._();

  static const String id = 'id';
  static const String name = 'name';
  static const String folder = 'folder';
  static const String status = 'status';
  static const String importance = 'importance';
  static const String tags = 'tags';
  static const String url = 'url';
  static const String value = 'value';
  static const String expiresAt = 'expires_at';
  static const String notes = 'notes';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';

  static String loginKind(int group) => 'login${group}_kind';
  static String loginAccount(int group) => 'login${group}_account';
  static String loginPrimary(int group) => 'login${group}_primary';

  static final RegExp loginColumn = RegExp(r'^login(\d+)_(kind|account|primary)$');

  /// 内置列（不含自定义字段与 logins 组列）。
  static const List<String> builtin = <String>[
    id,
    name,
    folder,
    status,
    importance,
    tags,
    url,
    value,
    expiresAt,
    notes,
    createdAt,
    updatedAt,
  ];

  static bool isLoginGroup(String column) => loginColumn.hasMatch(column);

  /// 判断某列是否有内置语义；否则视为自定义字段。
  static bool isBuiltin(String column) =>
      builtin.contains(column) || isLoginGroup(column);

  /// 解析 `login2_account` 这类列，返回 (组号, 字段名)。
  static ({int group, String field})? parseLoginColumn(String column) {
    final RegExpMatch? match = loginColumn.firstMatch(column);
    if (match == null) {
      return null;
    }
    return (group: int.parse(match.group(1)!), field: match.group(2)!);
  }

  /// 导出时登录方式展开的组数：按最长记录动态展开，最少 1 组，最多 5 组。
  static int groupCountFor(Iterable<int> loginCounts) {
    int max = 1;
    for (final int count in loginCounts) {
      if (count > max) {
        max = count;
      }
    }
    return max > kMaxLoginGroupsCsv ? kMaxLoginGroupsCsv : max;
  }
}

/// 导出列的组数上限，与文档口径一致。
const int kMaxLoginGroupsCsv = 5;

/// 内置说明面板中的一行说明。
class CsvColumnSpec {
  const CsvColumnSpec({
    required this.name,
    required this.required,
    required this.type,
    required this.example,
    required this.description,
  });

  final String name;
  final bool required;
  final String type;
  final String example;
  final String description;
}

/// 最小可用示例，面板与模板下载共用。
const List<List<String>> kCsvMinimalExampleRows = <List<String>>[
  <String>['name', 'folder', 'login1_kind', 'login1_account'],
  <String>['抖音', '社交', 'phone', '13800138000'],
  <String>['小红书', '社交', 'qq', '123456789'],
  <String>['Steam', '游戏', 'password', 'my_account'],
];

/// 完整列说明。说明面板直接渲染这张表，保证与解析逻辑一致。
const List<CsvColumnSpec> kRecordCsvColumnSpecs = <CsvColumnSpec>[
  CsvColumnSpec(
    name: CsvColumns.name,
    required: true,
    type: '文本',
    example: '抖音',
    description: '唯一必填，空白行跳过',
  ),
  CsvColumnSpec(
    name: CsvColumns.id,
    required: false,
    type: '文本',
    example: '留空',
    description: '留空自动生成；填了则按它更新',
  ),
  CsvColumnSpec(
    name: CsvColumns.folder,
    required: false,
    type: '文本',
    example: '社交',
    description: '不存在会自动创建',
  ),
  CsvColumnSpec(
    name: CsvColumns.status,
    required: false,
    type: '枚举',
    example: 'active',
    description: 'active / idle / abandoned / deactivated，留空按 active',
  ),
  CsvColumnSpec(
    name: CsvColumns.importance,
    required: false,
    type: '整数',
    example: '3',
    description: '1–5，留空按 3',
  ),
  CsvColumnSpec(
    name: CsvColumns.tags,
    required: false,
    type: '文本',
    example: '常用|有余额',
    description: '多个用竖线分隔',
  ),
  CsvColumnSpec(
    name: CsvColumns.url,
    required: false,
    type: '文本',
    example: 'https://…',
    description: '网址或包名',
  ),
  CsvColumnSpec(
    name: CsvColumns.value,
    required: false,
    type: '数字',
    example: '99.5',
    description: '不带货币符号',
  ),
  CsvColumnSpec(
    name: CsvColumns.expiresAt,
    required: false,
    type: '日期',
    example: '2026-12-01',
    description: '只认年-月-日',
  ),
  CsvColumnSpec(
    name: CsvColumns.notes,
    required: false,
    type: '文本',
    example: '随便写',
    description: '含逗号或换行时整格加双引号',
  ),
  CsvColumnSpec(
    name: 'login1_kind',
    required: false,
    type: '枚举',
    example: 'phone',
    description: 'phone / email / qq / wechat / password / other',
  ),
  CsvColumnSpec(
    name: 'login1_account',
    required: false,
    type: '文本',
    example: '13800138000',
    description: '账号值',
  ),
  CsvColumnSpec(
    name: 'login1_primary',
    required: false,
    type: '是/否',
    example: '是',
    description: '是否主登录',
  ),
  CsvColumnSpec(
    name: 'login2_…',
    required: false,
    type: '',
    example: '',
    description: '从 1 递增，最多 5 组',
  ),
  CsvColumnSpec(
    name: CsvColumns.createdAt,
    required: false,
    type: '时间',
    example: '2026-11-17 19:32',
    description: '留空取当前时间',
  ),
];

/// 其他 CSV 的表头。
class IdentityCsvColumns {
  const IdentityCsvColumns._();

  static const List<String> header = <String>[
    'id',
    'kind',
    'value',
    'label',
    'status',
    'notes',
    'created_at',
    'updated_at',
  ];
}

class FolderCsvColumns {
  const FolderCsvColumns._();

  static const List<String> header = <String>[
    'id',
    'name',
    'icon',
    'color',
    'sort_order',
    'created_at',
  ];
}

class FieldDefCsvColumns {
  const FieldDefCsvColumns._();

  static const List<String> header = <String>[
    'id',
    'key',
    'label',
    'kind',
    'options',
    'scope_type',
    'scope_folder_id',
    'sort_order',
  ];
}
