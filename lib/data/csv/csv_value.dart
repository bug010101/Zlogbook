import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/core/utils/text_utils.dart';
import 'package:zlogbook/models/enums.dart';

/// 单元格与强类型值之间的转换。导出与导入共用，保证口径一致。
class CsvValue {
  const CsvValue._();

  static String fromExtra(Object? value, FieldKind kind) {
    if (value == null) {
      return '';
    }
    switch (kind) {
      case FieldKind.multiselect:
        if (value is List) {
          return value.map((Object? item) => '$item').join(kTagSeparator);
        }
        return '$value';
      case FieldKind.date:
        if (value is DateTime) {
          return formatDate(value);
        }
        return '$value';
      case FieldKind.number:
        if (value is num) {
          return formatAmount(value.toDouble());
        }
        return '$value';
      case FieldKind.select:
      case FieldKind.text:
        return '$value';
    }
  }

  static Object? toExtra(String raw, FieldKind kind) {
    final String text = raw.trim();
    if (text.isEmpty) {
      return null;
    }
    switch (kind) {
      case FieldKind.number:
        return parseAmount(text);
      case FieldKind.date:
        return parseStrictDate(text);
      case FieldKind.multiselect:
        return splitPipe(text);
      case FieldKind.select:
      case FieldKind.text:
        return text;
    }
  }

  static String boolCell(bool value) => value ? '是' : '否';

  static bool parseBool(String raw) {
    final String text = raw.trim().toLowerCase();
    return text == '是' ||
        text == 'true' ||
        text == '1' ||
        text == 'y' ||
        text == 'yes';
  }

  /// 仅用于识别内置列：去空白并转小写。自定义字段的列名保持原样。
  static String matchKey(String raw) => raw.trim().toLowerCase();
}
