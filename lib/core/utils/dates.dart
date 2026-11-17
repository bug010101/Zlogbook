/// 时间格式化与解析。不依赖 intl，避免额外依赖与本地化差异。
String _two(int value) => value.toString().padLeft(2, '0');

/// 2026-11-17
String formatDate(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

/// 2026-11-17 19:32
String formatDateTime(DateTime date) =>
    '${formatDate(date)} ${_two(date.hour)}:${_two(date.minute)}';

/// 19:32
String formatTime(DateTime date) => '${_two(date.hour)}:${_two(date.minute)}';

/// 入库统一用 ISO8601。
String isoDateTime(DateTime date) => date.toIso8601String();

/// 严格解析 `YYYY-MM-DD`，用于 CSV 导入。其他格式一律返回 null（跳过该值）。
DateTime? parseStrictDate(String? raw) {
  final String text = (raw ?? '').trim();
  final RegExpMatch? match =
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) {
    return null;
  }
  final int year = int.parse(match.group(1)!);
  final int month = int.parse(match.group(2)!);
  final int day = int.parse(match.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  final DateTime date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// 宽松解析：ISO8601、`YYYY-MM-DD HH:mm`、`YYYY-MM-DD`。
DateTime? parseLooseDateTime(String? raw) {
  final String text = (raw ?? '').trim();
  if (text.isEmpty) {
    return null;
  }
  final DateTime? iso = DateTime.tryParse(text);
  if (iso != null) {
    return iso;
  }
  return parseStrictDate(text.substring(0, text.length < 10 ? text.length : 10));
}

DateTime? parseLooseDate(String? raw) {
  final String text = (raw ?? '').trim();
  if (text.isEmpty) {
    return null;
  }
  final DateTime? strict = parseStrictDate(text);
  if (strict != null) {
    return strict;
  }
  final DateTime? iso = DateTime.tryParse(text);
  if (iso == null) {
    return null;
  }
  return DateTime(iso.year, iso.month, iso.day);
}

DateTime dayOf(DateTime date) => DateTime(date.year, date.month, date.day);

/// 目标日期相对今天的天数差：正数为剩余，负数为已过期。
int daysFromToday(DateTime target, {DateTime? today}) {
  final DateTime now = dayOf(today ?? DateTime.now());
  return dayOf(target).difference(now).inDays;
}

/// 今天 / 昨天 / 3 天前 / 2 个月后
String relativeDayLabel(DateTime target, {DateTime? today}) {
  final int days = daysFromToday(target, today: today);
  if (days == 0) {
    return '今天';
  }
  if (days == -1) {
    return '昨天';
  }
  if (days == 1) {
    return '明天';
  }
  if (days > 0) {
    if (days < 30) {
      return '$days 天后';
    }
    return '${(days / 30).floor()} 个月后';
  }
  final int abs = -days;
  if (abs < 30) {
    return '$abs 天前';
  }
  if (abs < 365) {
    return '${(abs / 30).floor()} 个月前';
  }
  return '${(abs / 365).floor()} 年前';
}
