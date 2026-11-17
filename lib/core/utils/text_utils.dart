/// 文本与解析小工具。
library;

const String kTagSeparator = '|';

List<String> splitPipe(String? raw) {
  if (raw == null) {
    return const <String>[];
  }
  return raw
      .split(kTagSeparator)
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList();
}

String? joinPipe(List<String> values) {
  final List<String> cleaned = values
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList();
  if (cleaned.isEmpty) {
    return null;
  }
  return cleaned.join(kTagSeparator);
}

/// 空值规范：未填的可选项一律存 null，不存空字符串。
String? nullIfBlank(String? raw) {
  final String text = (raw ?? '').trim();
  return text.isEmpty ? null : text;
}

String textOrEmpty(String? raw) => raw ?? '';

/// 去掉货币符号、千分位后解析数字。
double? parseAmount(String? raw) {
  final String text = (raw ?? '').trim();
  if (text.isEmpty) {
    return null;
  }
  final String cleaned =
      text.replaceAll(RegExp(r'[¥$,\s]'), '').replaceAll('元', '');
  return double.tryParse(cleaned);
}

/// 数字展示：整数不带小数点，小数最多两位。
String formatAmount(double? value) {
  if (value == null) {
    return '';
  }
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// 手机号识别，用于粘贴自动选中类型。
final RegExp kPhonePattern = RegExp(r'^1[3-9]\d{9}$');

final RegExp kEmailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

/// 6 位以上纯数字，视为 QQ 号候选。
final RegExp kQqPattern = RegExp(r'^\d{5,12}$');

bool looksLikePhone(String value) => kPhonePattern.hasMatch(value.trim());

bool looksLikeEmail(String value) => kEmailPattern.hasMatch(value.trim());

/// 脱敏展示：138****1234
String maskPhone(String value) {
  final String text = value.trim();
  if (text.length < 7) {
    return text;
  }
  return '${text.substring(0, 3)}****${text.substring(text.length - 4)}';
}

/// 搜索关键词按空白切分，全部命中才算命中。
List<String> splitKeywords(String query) => query
    .trim()
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((String item) => item.isNotEmpty)
    .toList();
