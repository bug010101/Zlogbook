import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';

/// 多选时浮出的底部操作条。
class BatchActionBar extends StatelessWidget {
  const BatchActionBar({
    super.key,
    required this.selectedCount,
    required this.onStatus,
    required this.onMove,
    required this.onTag,
    required this.onDelete,
    required this.onSelectAll,
  });

  final int selectedCount;
  final VoidCallback onStatus;
  final VoidCallback onMove;
  final VoidCallback onTag;
  final VoidCallback onDelete;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    final bool enabled = selectedCount > 0;
    return Material(
      color: kSurface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              _action(Icons.circle_outlined, '状态', enabled ? onStatus : null),
              _action(Icons.drive_file_move_outline, '移动', enabled ? onMove : null),
              _action(Icons.sell_outlined, '标签', enabled ? onTag : null),
              _action(Icons.delete_outline, '删除', enabled ? onDelete : null),
              _action(Icons.select_all, '全选', onSelectAll),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 20,
              color: onTap == null ? kLine : kInk,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: onTap == null ? kLine : kInkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
