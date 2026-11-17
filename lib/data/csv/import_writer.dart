import 'package:sqflite/sqflite.dart';
import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/core/utils/ids.dart';
import 'package:zlogbook/core/utils/text_utils.dart';
import 'package:zlogbook/data/csv/import_plan.dart';
import 'package:zlogbook/data/csv/ledger_parser.dart';
import 'package:zlogbook/data/dao/field_def_dao.dart';
import 'package:zlogbook/data/dao/folder_dao.dart';
import 'package:zlogbook/data/dao/identity_dao.dart';
import 'package:zlogbook/data/dao/record_dao.dart';
import 'package:zlogbook/data/db/app_database.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/field_def.dart';
import 'package:zlogbook/models/folder.dart';
import 'package:zlogbook/models/identity.dart';

class ImportOutcome {
  const ImportOutcome({
    required this.created,
    required this.updated,
    required this.skipped,
    required this.createdFolders,
    required this.createdFields,
  });

  final int created;
  final int updated;
  final int skipped;
  final int createdFolders;
  final int createdFields;

  String get summary {
    final List<String> parts = <String>['新增 $created 条', '更新 $updated 条'];
    if (skipped > 0) {
      parts.add('跳过 $skipped 条');
    }
    if (createdFolders > 0) {
      parts.add('新建文件夹 $createdFolders 个');
    }
    if (createdFields > 0) {
      parts.add('新建字段 $createdFields 个');
    }
    return parts.join('，');
  }
}

/// 落库。整个过程在一个事务里，失败即回滚；调用前必须先做快照。
class ImportWriter {
  const ImportWriter._();

  static Future<ImportOutcome> apply({
    required ImportPlan plan,
    required ImportStrategy strategy,
    required ParsedImport source,
  }) async {
    final Database db = await AppDatabase.instance.open();
    int created = 0;
    int updated = 0;
    int skipped = 0;
    int createdFolders = 0;
    int createdFields = 0;

    await db.transaction((Transaction txn) async {
      final FolderDao folderDao = FolderDao(txn);
      final FieldDefDao fieldDao = FieldDefDao(txn);
      final RecordDao recordDao = RecordDao(txn);

      // 1. 导出包里的附属表先按 id upsert，保留图标、颜色、字段类型等元信息。
      await _upsertIdentities(txn, source);
      await _upsertFolders(folderDao, source);
      await _upsertFieldDefs(fieldDao, source);

      // 2. 文件夹名 -> id，缺的补建。
      final Map<String, String> folderIdByName = <String, String>{};
      int folderOrder = 0;
      final List<Map<String, Object?>> folderRows = await folderDao.findAll();
      for (final Map<String, Object?> row in folderRows) {
        final String? id = row['id'] as String?;
        final String name = (row['name'] as String? ?? '').trim();
        if (id != null && name.isNotEmpty) {
          folderIdByName[name] = id;
        }
        folderOrder++;
      }
      for (final String name in plan.newFolderNames) {
        if (folderIdByName.containsKey(name)) {
          continue;
        }
        final String id = newId();
        await folderDao.upsert(
          Folder(
            id: id,
            name: name,
            sortOrder: folderOrder++,
            createdAt: DateTime.now(),
          ).toMap(),
        );
        folderIdByName[name] = id;
        createdFolders++;
      }

      // 3. 未识别的列建为文本型自定义字段。
      int fieldOrder = (await fieldDao.findAll()).length;
      for (final String label in plan.newFieldLabels) {
        final Map<String, Object?>? existing = await fieldDao.findByLabel(label);
        if (existing != null) {
          continue;
        }
        await fieldDao.upsert(
          FieldDef(
            id: newId(),
            key: label,
            label: label,
            kind: FieldKind.text,
            sortOrder: fieldOrder++,
          ).toMap(),
        );
        createdFields++;
      }

      // 4. 记录本体。
      final DateTime now = DateTime.now();
      for (final ImportCandidate candidate in plan.candidates) {
        final String? folderId = candidate.folderName == null
            ? null
            : folderIdByName[candidate.folderName];

        switch (candidate.state) {
          case ImportRowState.duplicate:
            skipped++;
            break;
          case ImportRowState.unchanged:
            skipped++;
            break;
          case ImportRowState.create:
            {
              final String id = candidate.desiredId ?? newId();
              await recordDao.upsert(
                candidate.build(id: id, folderId: folderId, now: now).toMap(),
              );
              created++;
              break;
            }
          case ImportRowState.update:
            if (strategy == ImportStrategy.skip) {
              skipped++;
              break;
            }
            if (strategy == ImportStrategy.createNew) {
              await recordDao.upsert(
                candidate
                    .build(id: newId(), folderId: folderId, now: now)
                    .toMap(),
              );
              created++;
            } else {
              await recordDao.upsert(
                candidate.build(
                  id: candidate.targetId ?? newId(),
                  folderId: folderId,
                  now: now,
                ).toMap(),
              );
              updated++;
            }
            break;
        }
      }
    });

    return ImportOutcome(
      created: created,
      updated: updated,
      skipped: skipped,
      createdFolders: createdFolders,
      createdFields: createdFields,
    );
  }

  static Future<void> _upsertIdentities(
    DatabaseExecutor txn,
    ParsedImport source,
  ) async {
    final List<List<String>>? rows = source.identities;
    if (rows == null || rows.length < 2) {
      return;
    }
    final List<String> header =
        rows.first.map((String cell) => cell.trim().toLowerCase()).toList();
    final IdentityDao dao = IdentityDao(txn);
    for (int i = 1; i < rows.length; i++) {
      final List<String> row = rows[i];
      String value(String column) {
        final int index = header.indexOf(column);
        if (index < 0 || index >= row.length) {
          return '';
        }
        return row[index].trim();
      }

      final String account = value('value');
      if (account.isEmpty) {
        continue;
      }
      final DateTime now = DateTime.now();
      final String id = value('id').isEmpty ? newId() : value('id');
      await dao.upsert(
        Identity(
          id: id,
          kind: loginKindOf(value('kind')),
          value: account,
          label: nullIfBlank(value('label')),
          status: identityStatusOf(value('status')),
          notes: nullIfBlank(value('notes')),
          createdAt: parseLooseDateTime(value('created_at')) ?? now,
          updatedAt: now,
        ).toMap(),
      );
    }
  }

  static Future<void> _upsertFolders(
    FolderDao dao,
    ParsedImport source,
  ) async {
    final List<List<String>>? rows = source.folders;
    if (rows == null || rows.length < 2) {
      return;
    }
    final List<String> header =
        rows.first.map((String cell) => cell.trim().toLowerCase()).toList();
    for (int i = 1; i < rows.length; i++) {
      final List<String> row = rows[i];
      String value(String column) {
        final int index = header.indexOf(column);
        if (index < 0 || index >= row.length) {
          return '';
        }
        return row[index].trim();
      }

      final String name = value('name');
      if (name.isEmpty) {
        continue;
      }
      final int? order = int.tryParse(value('sort_order'));
      await dao.upsert(
        Folder(
          id: value('id').isEmpty ? newId() : value('id'),
          name: name,
          icon: value('icon').isEmpty ? 'folder' : value('icon'),
          color: value('color').isEmpty ? 'slate' : value('color'),
          sortOrder: order ?? i,
          createdAt: parseLooseDateTime(value('created_at')) ?? DateTime.now(),
        ).toMap(),
      );
    }
  }

  static Future<void> _upsertFieldDefs(
    FieldDefDao dao,
    ParsedImport source,
  ) async {
    final List<List<String>>? rows = source.fieldDefs;
    if (rows == null || rows.length < 2) {
      return;
    }
    final List<String> header =
        rows.first.map((String cell) => cell.trim().toLowerCase()).toList();
    for (int i = 1; i < rows.length; i++) {
      final List<String> row = rows[i];
      String value(String column) {
        final int index = header.indexOf(column);
        if (index < 0 || index >= row.length) {
          return '';
        }
        return row[index].trim();
      }

      final String label = value('label');
      if (label.isEmpty) {
        continue;
      }
      final int? order = int.tryParse(value('sort_order'));
      await dao.upsert(
        FieldDef(
          id: value('id').isEmpty ? newId() : value('id'),
          key: value('key').isEmpty ? label : value('key'),
          label: label,
          kind: fieldKindOf(value('kind')),
          options: splitPipe(value('options')),
          scope: fieldScopeOf(value('scope_type')),
          scopeFolderId: nullIfBlank(value('scope_folder_id')),
          sortOrder: order ?? i,
        ).toMap(),
      );
    }
  }
}
