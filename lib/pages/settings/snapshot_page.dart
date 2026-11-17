import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/data/db/app_database.dart';
import 'package:zlogbook/services/haptics.dart';
import 'package:zlogbook/state/app_scope.dart';
import 'package:zlogbook/widgets/common.dart';
import 'package:zlogbook/widgets/dialogs.dart';

/// 回滚点：导入前自动生成的数据库快照，也可手动创建。
class SnapshotPage extends StatefulWidget {
  const SnapshotPage({super.key});

  @override
  State<SnapshotPage> createState() => _SnapshotPageState();
}

class _SnapshotPageState extends State<SnapshotPage> {
  late Future<List<File>> _future = AppDatabase.instance.listSnapshots();

  void _refresh() {
    setState(() {
      _future = AppDatabase.instance.listSnapshots();
    });
  }

  Future<void> _createNow() async {
    await AppDatabase.instance.createSnapshot(reason: 'manual');
    await Haptics.light();
    if (!mounted) {
      return;
    }
    _refresh();
    showToast(context, '快照已创建');
  }

  Future<void> _restore(File file) async {
    final bool ok = await confirmAction(
      context,
      title: '恢复到这份快照？',
      message: '当前数据会被替换掉。恢复前建议先导出一次。',
      confirmLabel: '恢复',
      destructive: true,
    );
    if (!ok) {
      return;
    }
    await AppDatabase.instance.restoreSnapshot(file);
    if (!mounted) {
      return;
    }
    await AppScope.read(context).reloadAll();
    if (!mounted) {
      return;
    }
    _refresh();
    showToast(context, '已恢复');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回滚点'),
        actions: <Widget>[
          IconButton(
            tooltip: '立即创建快照',
            icon: const Icon(Icons.add),
            onPressed: _createNow,
          ),
        ],
      ),
      body: FutureBuilder<List<File>>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<List<File>> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<File> files = snapshot.data ?? const <File>[];
          if (files.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: '还没有快照',
              subtitle: '导入数据前会自动生成一份，也可以点右上角手动创建',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: files.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext ctx, int index) {
              final File file = files[index];
              int size = 0;
              try {
                size = file.lengthSync();
              } catch (_) {
                size = 0;
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.settings_backup_restore,
                          size: 20, color: kInkSoft),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              p.basename(file.path).replaceAll('.db', ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${(size / 1024).toStringAsFixed(0)} KB',
                              style: const TextStyle(
                                fontSize: 11,
                                color: kInkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _restore(file),
                        child: const Text('恢复'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
