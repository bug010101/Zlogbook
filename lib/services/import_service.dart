import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:zlogbook/data/csv/import_plan.dart';
import 'package:zlogbook/data/csv/import_planner.dart';
import 'package:zlogbook/data/csv/import_writer.dart';
import 'package:zlogbook/data/csv/ledger_parser.dart';
import 'package:zlogbook/data/db/app_database.dart';
import 'package:zlogbook/state/app_state.dart';

/// 导入：选文件 -> 解析 -> 预览 -> 快照 -> 落库。
class ImportService {
  const ImportService._();

  static Future<ParsedImport?> pickAndParse() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['csv', 'zip'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return null;
    }
    final PlatformFile file = picked.files.single;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) {
      throw const FormatException('读不到文件内容，请换一个文件试试');
    }
    return LedgerParser.parseBytes(bytes, file.name);
  }

  static ImportPlan buildPlan(ParsedImport source, AppState state) {
    return ImportPlanner.plan(
      source: source,
      existingRecords: state.records,
      existingFolders: state.folders,
      existingFields: state.fieldDefs,
    );
  }

  /// 落库前先做数据库快照，出问题可以从设置页的回滚点恢复。
  static Future<ImportOutcome> apply({
    required ImportPlan plan,
    required ImportStrategy strategy,
    required ParsedImport source,
  }) async {
    await AppDatabase.instance.createSnapshot(reason: 'import');
    return ImportWriter.apply(
      plan: plan,
      strategy: strategy,
      source: source,
    );
  }
}
