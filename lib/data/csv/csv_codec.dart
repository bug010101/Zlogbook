import 'dart:convert';
import 'dart:typed_data';

/// RFC4180 CSV 读写。自己实现是为了不引入额外依赖，并统一处理 BOM。
class CsvCodec {
  const CsvCodec._();

  static const String bom = '\uFEFF';

  static String stripBom(String text) {
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      return text.substring(1);
    }
    return text;
  }

  /// 解析为二维表，完全空白的行会被丢弃。
  static List<List<String>> decode(String input) {
    final String text = stripBom(input);
    final List<List<String>> rows = <List<String>>[];
    List<String> row = <String>[];
    final StringBuffer cell = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < text.length; i++) {
      final String ch = text[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(ch);
        }
        continue;
      }
      switch (ch) {
        case '"':
          inQuotes = true;
          break;
        case ',':
          row.add(cell.toString());
          cell.clear();
          break;
        case '\r':
          break;
        case '\n':
          row.add(cell.toString());
          cell.clear();
          if (row.any((String item) => item.trim().isNotEmpty)) {
            rows.add(row);
          }
          row = <String>[];
          break;
        default:
          cell.write(ch);
      }
    }

    if (cell.isNotEmpty || row.any((String item) => item.trim().isNotEmpty)) {
      row.add(cell.toString());
      if (row.any((String item) => item.trim().isNotEmpty)) {
        rows.add(row);
      }
    }
    return rows;
  }

  static String encode(List<List<String>> rows) {
    final StringBuffer buffer = StringBuffer();
    for (final List<String> row in rows) {
      buffer.write(row.map(_escape).join(','));
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  /// UTF-8 带 BOM，Excel / WPS 双击不乱码。
  static Uint8List encodeBytes(List<List<String>> rows) {
    final List<int> bytes = utf8.encode('$bom${encode(rows)}');
    return Uint8List.fromList(bytes);
  }

  static String _escape(String value) {
    final bool needsQuote = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final String escaped = value.replaceAll('"', '""');
    return needsQuote ? '"$escaped"' : escaped;
  }
}
