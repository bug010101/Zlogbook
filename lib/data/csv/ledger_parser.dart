import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:zlogbook/data/csv/csv_codec.dart';

/// 一次导入读取到的原始表格（含表头行）。
class ParsedImport {
  const ParsedImport({
    required this.sourceName,
    required this.records,
    this.identities,
    this.folders,
    this.fieldDefs,
    this.fromZip = false,
  });

  final String sourceName;
  final List<List<String>> records;
  final List<List<String>>? identities;
  final List<List<String>>? folders;
  final List<List<String>>? fieldDefs;
  final bool fromZip;

  bool get hasRows => records.length >= 2;

  int get dataRowCount => records.isEmpty ? 0 : records.length - 1;
}

/// 支持 .zip（导出包）与 .csv（单表）两种输入。
class LedgerParser {
  const LedgerParser._();

  static ParsedImport parseBytes(Uint8List bytes, String fileName) {
    final String lower = fileName.toLowerCase();
    if (lower.endsWith('.zip') || _looksLikeZip(bytes)) {
      return _parseZip(bytes, fileName);
    }
    return ParsedImport(
      sourceName: fileName,
      records: _decodeCsv(bytes),
    );
  }

  static bool _looksLikeZip(Uint8List bytes) =>
      bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B;

  static ParsedImport _parseZip(Uint8List bytes, String fileName) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('压缩包无法解析，请确认是从本软件导出的 zip');
    }

    List<List<String>>? records;
    List<List<String>>? identities;
    List<List<String>>? folders;
    List<List<String>>? fieldDefs;

    for (final ArchiveFile file in archive.files) {
      if (file.name.endsWith('/')) {
        continue;
      }
      final String base = file.name.split('/').last.toLowerCase();
      if (!base.endsWith('.csv')) {
        continue;
      }
      final List<int>? content = _contentOf(file);
      if (content == null) {
        continue;
      }
      final List<List<String>> rows =
          CsvCodec.decode(utf8.decode(content, allowMalformed: true));
      if (base == 'records.csv') {
        records = rows;
      } else if (base == 'identities.csv') {
        identities = rows;
      } else if (base == 'folders.csv') {
        folders = rows;
      } else if (base == 'field_defs.csv') {
        fieldDefs = rows;
      } else if (records == null) {
        records = rows;
      }
    }

    if (records == null) {
      throw const FormatException('压缩包里没有找到 records.csv');
    }
    return ParsedImport(
      sourceName: fileName,
      records: records,
      identities: identities,
      folders: folders,
      fieldDefs: fieldDefs,
      fromZip: true,
    );
  }

  static List<int>? _contentOf(ArchiveFile file) {
    final dynamic content = file.content;
    if (content is List<int>) {
      return content;
    }
    if (content is List) {
      return List<int>.from(content);
    }
    return null;
  }

  static List<List<String>> _decodeCsv(Uint8List bytes) {
    return CsvCodec.decode(utf8.decode(bytes, allowMalformed: true));
  }
}
