import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:zlogbook/core/app_info.dart';
import 'package:zlogbook/core/csv_columns.dart';
import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/core/utils/text_utils.dart';
import 'package:zlogbook/data/csv/csv_codec.dart';
import 'package:zlogbook/data/csv/csv_value.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/field_def.dart';
import 'package:zlogbook/models/folder.dart';
import 'package:zlogbook/models/identity.dart';
import 'package:zlogbook/models/login_method.dart';
import 'package:zlogbook/models/record.dart';

class ExportBundle {
  const ExportBundle({
    required this.bytes,
    required this.fileName,
    required this.recordCount,
  });

  final Uint8List bytes;
  final String fileName;
  final int recordCount;
}

/// 把当前数据打包成 zip：4 个 CSV + meta.json。
class LedgerExporter {
  const LedgerExporter._();

  static ExportBundle build({
    required List<AssetRecord> records,
    required List<Identity> identities,
    required List<Folder> folders,
    required List<FieldDef> fieldDefs,
    DateTime? now,
  }) {
    final DateTime stamp = now ?? DateTime.now();
    final List<FieldDef> fields = List<FieldDef>.from(fieldDefs)
      ..sort((FieldDef a, FieldDef b) => a.sortOrder.compareTo(b.sortOrder));
    final Map<String, String> folderNames = <String, String>{
      for (final Folder folder in folders) folder.id: folder.name,
    };
    final int groups =
        CsvColumns.groupCountFor(records.map((AssetRecord r) => r.logins.length));
    final List<String> labels = _uniqueLabels(fields);

    final List<List<String>> recordRows = <List<String>>[
      _recordHeader(labels, groups),
    ];
    for (final AssetRecord record in records) {
      recordRows.add(_recordRow(record, fields, labels, folderNames, groups));
    }

    final Archive archive = Archive();
    _add(archive, 'records.csv', CsvCodec.encode(recordRows));
    _add(archive, 'identities.csv', CsvCodec.encode(_identityRows(identities)));
    _add(archive, 'folders.csv', CsvCodec.encode(_folderRows(folders)));
    _add(archive, 'field_defs.csv', CsvCodec.encode(_fieldRows(fields)));
    _add(
      archive,
      'meta.json',
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'app': AppInfo.name,
        'data_version': AppInfo.dataVersion,
        'exported_at': isoDateTime(stamp),
        'counts': <String, int>{
          'records': records.length,
          'identities': identities.length,
          'folders': folders.length,
          'fields': fields.length,
        },
      }),
    );

    final List<int>? encoded = ZipEncoder().encode(archive);
    return ExportBundle(
      bytes: Uint8List.fromList(encoded ?? const <int>[]),
      fileName: '${AppInfo.exportFilePrefix}-${_stamp(stamp)}.zip',
      recordCount: records.length,
    );
  }

  /// 只含表头 + 一行示例的模板。
  static Uint8List templateBytes() {
    final List<List<String>> rows = <List<String>>[
      <String>[
        CsvColumns.name,
        CsvColumns.folder,
        CsvColumns.status,
        CsvColumns.importance,
        CsvColumns.tags,
        CsvColumns.url,
        CsvColumns.value,
        CsvColumns.expiresAt,
        CsvColumns.notes,
        CsvColumns.loginKind(1),
        CsvColumns.loginAccount(1),
        CsvColumns.loginPrimary(1),
      ],
      <String>[
        '抖音',
        '社交',
        'active',
        '3',
        '常用|有余额',
        'https://www.douyin.com',
        '0',
        '2026-12-01',
        '手机号注册',
        'phone',
        '13800138000',
        '是',
      ],
    ];
    return CsvCodec.encodeBytes(rows);
  }

  static List<String> _recordHeader(List<String> labels, int groups) {
    final List<String> header = <String>[
      CsvColumns.id,
      CsvColumns.name,
      CsvColumns.folder,
      CsvColumns.status,
      CsvColumns.importance,
      CsvColumns.tags,
      CsvColumns.url,
      CsvColumns.value,
      CsvColumns.expiresAt,
      CsvColumns.notes,
    ];
    for (int group = 1; group <= groups; group++) {
      header.add(CsvColumns.loginKind(group));
      header.add(CsvColumns.loginAccount(group));
      header.add(CsvColumns.loginPrimary(group));
    }
    header.addAll(labels);
    header.add(CsvColumns.createdAt);
    header.add(CsvColumns.updatedAt);
    return header;
  }

  static List<String> _recordRow(
    AssetRecord record,
    List<FieldDef> fields,
    List<String> labels,
    Map<String, String> folderNames,
    int groups,
  ) {
    final List<String> row = <String>[
      record.id,
      record.name,
      record.folderId == null ? '' : (folderNames[record.folderId] ?? ''),
      record.status.code,
      '${record.importance}',
      record.tags.join(kTagSeparator),
      textOrEmpty(record.url),
      record.value == null ? '' : formatAmount(record.value),
      record.expiresAt == null ? '' : formatDate(record.expiresAt!),
      textOrEmpty(record.notes),
    ];
    for (int group = 0; group < groups; group++) {
      final LoginMethod? login =
          group < record.logins.length ? record.logins[group] : null;
      row.add(login?.kind.code ?? '');
      row.add(login?.account ?? '');
      row.add(login == null ? '' : CsvValue.boolCell(login.isPrimary));
    }
    for (int i = 0; i < fields.length; i++) {
      row.add(CsvValue.fromExtra(record.extra[fields[i].key], fields[i].kind));
    }
    row.add(formatDateTime(record.createdAt));
    row.add(formatDateTime(record.updatedAt));
    // labels 仅用于表头，行数据与 fields 一一对应，保持长度一致。
    assert(labels.length == fields.length);
    return row;
  }

  static List<List<String>> _identityRows(List<Identity> identities) {
    final List<List<String>> rows = <List<String>>[
      List<String>.from(IdentityCsvColumns.header),
    ];
    for (final Identity identity in identities) {
      rows.add(<String>[
        identity.id,
        identity.kind.code,
        identity.value,
        textOrEmpty(identity.label),
        identity.status.code,
        textOrEmpty(identity.notes),
        formatDateTime(identity.createdAt),
        formatDateTime(identity.updatedAt),
      ]);
    }
    return rows;
  }

  static List<List<String>> _folderRows(List<Folder> folders) {
    final List<List<String>> rows = <List<String>>[
      List<String>.from(FolderCsvColumns.header),
    ];
    for (final Folder folder in folders) {
      rows.add(<String>[
        folder.id,
        folder.name,
        folder.icon,
        folder.color,
        '${folder.sortOrder}',
        formatDateTime(folder.createdAt),
      ]);
    }
    return rows;
  }

  static List<List<String>> _fieldRows(List<FieldDef> fields) {
    final List<List<String>> rows = <List<String>>[
      List<String>.from(FieldDefCsvColumns.header),
    ];
    for (final FieldDef field in fields) {
      rows.add(<String>[
        field.id,
        field.key,
        field.label,
        field.kind.code,
        field.options.join(kTagSeparator),
        field.scope.code,
        textOrEmpty(field.scopeFolderId),
        '${field.sortOrder}',
      ]);
    }
    return rows;
  }

  /// 自定义字段用中文显示名做表头；与内置列重名时加后缀，避免导入歧义。
  static List<String> _uniqueLabels(List<FieldDef> fields) {
    final Set<String> used = CsvColumns.builtin.toSet();
    final List<String> labels = <String>[];
    for (final FieldDef field in fields) {
      String label = field.label.trim().isEmpty ? field.key : field.label.trim();
      if (used.contains(CsvValue.matchKey(label))) {
        label = '$label（字段）';
      }
      String candidate = label;
      int index = 2;
      while (used.contains(CsvValue.matchKey(candidate))) {
        candidate = '$label $index';
        index++;
      }
      used.add(CsvValue.matchKey(candidate));
      labels.add(candidate);
    }
    return labels;
  }

  static void _add(Archive archive, String name, String content) {
    final List<int> bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  static String _stamp(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}-'
        '${two(time.hour)}${two(time.minute)}';
  }
}
