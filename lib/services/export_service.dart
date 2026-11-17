import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zlogbook/core/app_info.dart';
import 'package:zlogbook/data/csv/ledger_exporter.dart';
import 'package:zlogbook/state/app_state.dart';

/// 导出：打包内存数据 -> 临时文件 -> 系统分享面板。
class ExportService {
  const ExportService._();

  static Future<ExportBundle> exportAndShare(AppState state) async {
    final ExportBundle bundle = LedgerExporter.build(
      records: state.resolvedRecordsForExport(),
      identities: state.identities,
      folders: state.folders,
      fieldDefs: state.fieldDefs,
    );
    final File file = await _writeTemp(bundle.fileName, bundle.bytes);
    await Share.shareXFiles(
      <XFile>[XFile(file.path)],
      subject: '${AppInfo.name} 数据导出',
      text: '共 ${bundle.recordCount} 条记录',
    );
    return bundle;
  }

  /// 导入模板：表头 + 一行示例。
  static Future<void> shareTemplate() async {
    final File file = await _writeTemp(
      'zlogbook-import-template.csv',
      LedgerExporter.templateBytes(),
    );
    await Share.shareXFiles(
      <XFile>[XFile(file.path)],
      subject: '${AppInfo.name} 导入模板',
      text: '照着这份表头填写即可导入',
    );
  }

  static Future<File> _writeTemp(String name, List<int> bytes) async {
    final Directory dir = await getTemporaryDirectory();
    final File file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
