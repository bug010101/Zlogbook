import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/models/record.dart';
import 'package:zlogbook/services/haptics.dart';
import 'package:zlogbook/state/app_scope.dart';
import 'package:zlogbook/state/app_state.dart';
import 'package:zlogbook/widgets/common.dart';
import 'package:zlogbook/widgets/dialogs.dart';

/// 回收站：软删除的记录在这里，可恢复，也可手动清空。
class RecycleBinPage extends StatelessWidget {
  const RecycleBinPage({super.key});

  Future<void> _empty(BuildContext context) async {
    final AppState state = AppScope.read(context);
    final bool ok = await confirmAction(
      context,
      title: '清空回收站？',
      message: '里面的 ${state.trashedCount} 条记录会被永久删除，无法恢复。'
          '建议先导出一份备份。',
      confirmLabel: '永久删除',
      destructive: true,
    );
    if (!ok) {
      return;
    }
    await state.purgeTrash();
    await Haptics.medium();
    if (context.mounted) {
      showToast(context, '回收站已清空');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<AssetRecord> trashed = state.trashedRecords;

    return Scaffold(
      appBar: AppBar(
        title: Text(trashed.isEmpty ? '回收站' : '回收站（${trashed.length}）'),
        actions: <Widget>[
          if (trashed.isNotEmpty)
            IconButton(
              tooltip: '清空',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _empty(context),
            ),
        ],
      ),
      body: trashed.isEmpty
          ? const EmptyState(
              icon: Icons.delete_outline,
              title: '回收站是空的',
              subtitle: '删除的记录会先放在这里，五秒内还能撤销',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: trashed.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (BuildContext ctx, int index) {
                final AssetRecord record = trashed[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                record.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${state.folderName(record.folderId)}'
                                '${record.deletedAt == null ? '' : ' · 删除于 ${formatDateTime(record.deletedAt!)}'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kInkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await state.restoreRecord(record.id);
                            if (context.mounted) {
                              showToast(context, '已恢复「${record.name}」');
                            }
                          },
                          child: const Text('恢复'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
