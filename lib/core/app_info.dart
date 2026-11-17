/// 应用级常量。
class AppInfo {
  const AppInfo._();

  static const String name = 'Zlogbook';
  static const String tagline = '个人数字资产台账';
  static const String version = '1.0.9';

  /// 数据格式版本，写入导出包 meta.json。
  static const int dataVersion = 1;

  static const String dbFileName = 'zlogbook.db';
  static const String exportFilePrefix = 'asset-ledger';
  static const String featuresAsset = 'assets/features.txt';
}

/// 未归类文案。
const String kUncategorizedLabel = '未分类';

/// 即将到期的判定天数。
const int kExpiringSoonDays = 30;

/// 身份池中可选的身份类型数量上限不限制，但记录内登录方式上限为 5 组（导出列）。
const int kMaxLoginGroups = 5;

/// 偏好设置的持久化键。
class PrefKeys {
  const PrefKeys._();

  static const String sortMode = 'pref.sort_mode';
  static const String timelineView = 'pref.timeline_view';
  static const String lastLoginKind = 'pref.last_login_kind';
}
