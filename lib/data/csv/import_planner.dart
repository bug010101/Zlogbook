import 'dart:convert';

import 'package:zlogbook/core/csv_columns.dart';
import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/core/utils/ids.dart';
import 'package:zlogbook/core/utils/text_utils.dart';
import 'package:zlogbook/data/csv/csv_value.dart';
import 'package:zlogbook/data/csv/import_plan.dart';
import 'package:zlogbook/data/csv/ledger_parser.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/field_def.dart';
import 'package:zlogbook/models/folder.dart';
import 'package:zlogbook/models/login_method.dart';
import 'package:zlogbook/models/record.dart';

/// 把原始表格解析成落库计划。纯函数，不碰数据库，便于校验与预览。
class ImportPlanner {
  const ImportPlanner._();

  static ImportPlan plan({
    required ParsedImport source,
    required List<AssetRecord> existingRecords,
    required List<Folder> existingFolders,
    required List<FieldDef> existingFields,
    DateTime? now,
  }) {
    final DateTime stamp = now ?? DateTime.now();
    final List<String> warnings = <String>[];
    final List<List<String>> table = source.records;

    if (table.isEmpty) {
      return ImportPlan(
        candidates: const <ImportCandidate>[],
        newFieldLabels: const <String>[],
        newFolderNames: const <String>[],
        warnings: const <String>['文件里没有内容'],
        skippedRows: 0,
      );
    }

    final Map<String, int> builtinCols = <String, int>{};
    final Map<int, ({int group, String field})> loginCols =
        <int, ({int group, String field})>{};
    final Map<int, String> customCols = <int, String>{};
    final Set<String> customLabels = <String>{};

    final List<String> header = table.first
        .map((String cell) => cell.trim())
        .toList(growable: false);
    for (int i = 0; i < header.length; i++) {
      final String raw = header[i];
      if (raw.isEmpty) {
        continue;
      }
      final String key = CsvValue.matchKey(raw);
      if (CsvColumns.builtin.contains(key)) {
        builtinCols[key] = i;
        continue;
      }
      final ({int group, String field})? login = CsvColumns.parseLoginColumn(key);
      if (login != null) {
        loginCols[i] = login;
        continue;
      }
      if (customLabels.add(raw)) {
        customCols[i] = raw;
      }
    }

    if (!builtinCols.containsKey(CsvColumns.name)) {
      warnings.add('第一行缺少 name 列，无法导入');
      return ImportPlan(
        candidates: const <ImportCandidate>[],
        newFieldLabels: const <String>[],
        newFolderNames: const <String>[],
        warnings: warnings,
        skippedRows: 0,
      );
    }

    final Map<String, Folder> folderByName = <String, Folder>{
      for (final Folder folder in existingFolders) folder.name.trim(): folder,
    };
    final Map<String, String> folderNameById = <String, String>{
      for (final Folder folder in existingFolders) folder.id: folder.name,
    };
    final Map<String, FieldDef> fieldByLabel = <String, FieldDef>{
      for (final FieldDef field in existingFields) field.label.trim(): field,
    };
    final Map<String, AssetRecord> recordById = <String, AssetRecord>{
      for (final AssetRecord record in existingRecords) record.id: record,
    };

    final Set<String> newFolderNames = <String>{};
    final Set<String> newFieldLabels = <String>{};
    final Set<String> seenIds = <String>{};
    final List<ImportCandidate> candidates = <ImportCandidate>[];
    int skippedRows = 0;

    for (int r = 1; r < table.length; r++) {
      final List<String> row = table[r];
      final int line = r + 1;

      String cellOf(String column) {
        final int? index = builtinCols[column];
        if (index == null || index >= row.length) {
          return '';
        }
        return row[index].trim();
      }

      bool has(String column) => builtinCols.containsKey(column);

      if (row.every((String cell) => cell.trim().isEmpty)) {
        continue;
      }

      final String name = cellOf(CsvColumns.name);
      if (name.isEmpty) {
        skippedRows++;
        warnings.add('第 $line 行没有名称，已跳过');
        continue;
      }

      final String rawId = cellOf(CsvColumns.id);
      final bool duplicatedId = rawId.isNotEmpty && !seenIds.add(rawId);
      final AssetRecord? base = rawId.isEmpty ? null : recordById[rawId];

      String? folderName;
      if (has(CsvColumns.folder)) {
        folderName = nullIfBlank(cellOf(CsvColumns.folder));
        if (folderName != null && !folderByName.containsKey(folderName)) {
          newFolderNames.add(folderName);
        }
      } else if (base != null && base.folderId != null) {
        folderName = folderNameById[base.folderId!];
      }

      final RecordStatus status = has(CsvColumns.status)
          ? recordStatusOf(cellOf(CsvColumns.status))
          : (base?.status ?? RecordStatus.active);

      final int importance = has(CsvColumns.importance)
          ? _parseImportance(cellOf(CsvColumns.importance), base?.importance ?? 3)
          : (base?.importance ?? 3);

      final List<String> tags = has(CsvColumns.tags)
          ? splitPipe(cellOf(CsvColumns.tags))
          : (base?.tags ?? const <String>[]);

      final String? url =
          has(CsvColumns.url) ? nullIfBlank(cellOf(CsvColumns.url)) : base?.url;

      final double? value = has(CsvColumns.value)
          ? parseAmount(cellOf(CsvColumns.value))
          : base?.value;

      DateTime? expiresAt = base?.expiresAt;
      if (has(CsvColumns.expiresAt)) {
        final String raw = cellOf(CsvColumns.expiresAt);
        expiresAt = parseStrictDate(raw);
        if (raw.isNotEmpty && expiresAt == null) {
          warnings.add('第 $line 行到期日 "$raw" 无法识别，已置空');
        }
      }

      final String? notes = has(CsvColumns.notes)
          ? nullIfBlank(cellOf(CsvColumns.notes))
          : base?.notes;

      DateTime createdAt = base?.createdAt ?? stamp;
      if (has(CsvColumns.createdAt)) {
        final DateTime? parsed = parseLooseDateTime(cellOf(CsvColumns.createdAt));
        if (parsed != null) {
          createdAt = parsed;
        }
      }

      final List<LoginMethod> logins = loginCols.isEmpty
          ? (base?.logins ?? const <LoginMethod>[])
          : _buildLogins(row, loginCols);

      final Map<String, Object?> extra = <String, Object?>{
        ...(base?.extra ?? const <String, Object?>{}),
      };
      for (final MapEntry<int, String> entry in customCols.entries) {
        final String label = entry.value;
        final FieldDef? def = fieldByLabel[label];
        final String raw = entry.key < row.length ? row[entry.key] : '';
        final Object? cellValue =
            CsvValue.toExtra(raw, def?.kind ?? FieldKind.text);
        final String key = def?.key ?? label;
        if (cellValue == null) {
          extra.remove(key);
        } else {
          extra[key] = cellValue;
        }
        if (def == null) {
          newFieldLabels.add(label);
        }
      }

      ImportCandidate candidate = ImportCandidate(
        line: line,
        name: name,
        status: status,
        importance: importance,
        tags: tags,
        logins: logins,
        extra: extra,
        createdAt: createdAt,
        targetId: base?.id,
        desiredId: rawId.isEmpty ? null : rawId,
        folderName: folderName,
        notes: notes,
        url: url,
        value: value,
        expiresAt: expiresAt,
      );

      if (duplicatedId) {
        warnings.add('第 $line 行 id 与前面的行重复，已跳过');
        candidates.add(candidate.withState(ImportRowState.duplicate));
        continue;
      }

      if (base == null) {
        candidates.add(candidate.withState(ImportRowState.create));
      } else {
        final AssetRecord draft = candidate.build(
          id: base.id,
          folderId: base.folderId,
          now: base.updatedAt,
        );
        candidate = candidate.withState(
          _sameContent(draft, base)
              ? ImportRowState.unchanged
              : ImportRowState.update,
        );
        candidates.add(candidate);
      }
    }

    final List<String> sortedFolders = newFolderNames.toList()..sort();
    final List<String> sortedFields = newFieldLabels.toList()..sort();
    return ImportPlan(
      candidates: candidates,
      newFieldLabels: sortedFields,
      newFolderNames: sortedFolders,
      warnings: warnings,
      skippedRows: skippedRows,
    );
  }

  static int _parseImportance(String raw, int fallback) {
    final int? parsed = int.tryParse(raw.trim());
    if (parsed == null) {
      return fallback;
    }
    if (parsed < 1) {
      return 1;
    }
    if (parsed > 5) {
      return 5;
    }
    return parsed;
  }

  static List<LoginMethod> _buildLogins(
    List<String> row,
    Map<int, ({int group, String field})> loginCols,
  ) {
    final Map<int, Map<String, String>> groups = <int, Map<String, String>>{};
    loginCols.forEach((int index, ({int group, String field}) column) {
      final String raw = index < row.length ? row[index].trim() : '';
      groups.putIfAbsent(column.group, () => <String, String>{})[column.field] =
          raw;
    });

    final List<int> order = groups.keys.toList()..sort();
    final List<LoginMethod> collected = <LoginMethod>[];
    for (final int group in order) {
      final Map<String, String> cells = groups[group]!;
      final String account = (cells['account'] ?? '').trim();
      if (account.isEmpty) {
        continue;
      }
      collected.add(
        LoginMethod(
          id: newId(),
          kind: loginKindOf(cells['kind']),
          account: account,
          isPrimary: CsvValue.parseBool(cells['primary'] ?? ''),
          usable: true,
        ),
      );
    }

    int primaryIndex = -1;
    for (int i = 0; i < collected.length; i++) {
      if (collected[i].isPrimary) {
        primaryIndex = i;
        break;
      }
    }
    if (primaryIndex < 0 && collected.isNotEmpty) {
      primaryIndex = 0;
    }
    final List<LoginMethod> result = <LoginMethod>[];
    for (int i = 0; i < collected.length; i++) {
      result.add(collected[i].copyWith(isPrimary: i == primaryIndex));
    }
    return result;
  }

  static bool _sameContent(AssetRecord a, AssetRecord b) {
    final Map<String, Object?> left = a.toMap()..remove('updated_at');
    final Map<String, Object?> right = b.toMap()..remove('updated_at');
    return jsonEncode(left) == jsonEncode(right);
  }
}
