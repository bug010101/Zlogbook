import 'package:flutter/material.dart';
import 'package:zlogbook/core/app_info.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/pages/settings/about_page.dart';
import 'package:zlogbook/pages/settings/field_manage_page.dart';
import 'package:zlogbook/pages/settings/features_page.dart';
import 'package:zlogbook/pages/settings/import_page.dart';
import 'package:zlogbook/pages/settings/recycle_bin_page.dart';
import 'package:zlogbook/pages/settings/snapshot_page.dart';
import 'package:zlogbook/services/export_service.dart';
import 'package:zlogbook/state/app_scope.dart';
import 'package:zlogbook/state/app_state.dart';
import 'package:zlogbook/widgets/dialogs.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _export(BuildContext context) async {
    final AppState state = AppScope.read(context);
    if (state.records.isEmpty) {
      showToast(context, '还没有记录可以导出');
      return;
    }
    try {
      final bundle = await ExportService.exportAndShare(state);
      if (context.mounted) {
        showToast(context, '已生成 ${bundle.fileName}');
      }
    } catch (error) {
      if (context.mounted) {
        showToast(context, '导出失败：$error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: <Widget>[
          _label('数据'),
          _group(<Widget>[
            _tile(
              icon: Icons.ios_share,
              title: '导出',
              subtitle: '打包成 zip，含 4 个 CSV 与 meta.json',
              onTap: () => _export(context),
            ),
            _tile(
              icon: Icons.file_download_outlined,
              title: '导入',
              subtitle: '支持 CSV 与导出包，带预览与冲突策略',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ImportPage()),
              ),
            ),
            _tile(
              icon: Icons.history,
              title: '回滚点',
              subtitle: '导入前自动生成的数据库快照',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SnapshotPage()),
              ),
            ),
            _tile(
              icon: Icons.delete_outline,
              title: '回收站',
              subtitle: state.trashedCount == 0
                  ? '空'
                  : '${state.trashedCount} 条待处理',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RecycleBinPage(),
                ),
              ),
            ),
          ]),
          _label('字段'),
          _group(<Widget>[
            _tile(
              icon: Icons.playlist_add,
              title: '自定义字段',
              subtitle: state.fieldDefs.isEmpty
                  ? '还没有字段'
                  : '${state.fieldDefs.length} 个字段',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FieldManagePage(),
                ),
              ),
            ),
          ]),
          _label('其他'),
          _group(<Widget>[
            _tile(
              icon: Icons.new_releases_outlined,
              title: '功能清单',
              subtitle: '每个版本新增了什么',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const FeaturesPage()),
              ),
            ),
            _tile(
              icon: Icons.info_outline,
              title: '关于',
              subtitle: '${AppInfo.name} v${AppInfo.version}',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutPage()),
              ),
            ),
          ]),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 24, 4, 0),
            child: Text(
              '数据只保存在本机，不联网、不上传。\n删除应用即彻底消失，重要数据请定期导出。',
              style: TextStyle(fontSize: 12, color: kInkSoft, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: kInkSoft,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _group(List<Widget> children) {
    return Card(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 21),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: kInkSoft),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: kLine),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
