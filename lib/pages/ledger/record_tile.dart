import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/folder.dart';
import 'package:zlogbook/models/login_method.dart';
import 'package:zlogbook/models/record.dart';
import 'package:zlogbook/widgets/app_icons.dart';
import 'package:zlogbook/widgets/common.dart';
import 'package:zlogbook/widgets/highlight_text.dart';

/// 列表行：类型图标 + 名称 + 文件夹 + 登录摘要 + 状态色点。
class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.record,
    required this.folderName,
    required this.loginText,
    required this.query,
    this.folder,
    this.selected = false,
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
  });

  final AssetRecord record;
  final String folderName;
  final String loginText;
  final String query;
  final Folder? folder;
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final LoginMethod? primary = record.primaryLogin;
    final IconData icon =
        primary == null ? AppIcons.folder(folder?.icon) : AppIcons.login(primary.kind);
    final Color tint = AppIcons.accent(folder?.color);
    final DateTime? expires = record.expiresAt;

    return Material(
      color: selected ? kAccent.withValues(alpha: 0.07) : kSurface,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: kLine, width: 0.6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: HighlightText(
                            record.name,
                            query: query,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: record.status == RecordStatus.deactivated
                                  ? kInkSoft
                                  : kInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        StatusDot(status: record.status),
                        if (expires != null) ...<Widget>[
                          const SizedBox(width: 8),
                          ExpiryBadge(expiresAt: expires),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      loginText.isEmpty ? folderName : '$folderName · $loginText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kInkSoft),
                    ),
                    if (record.tags.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: record.tags
                            .take(3)
                            .map((String tag) => TagChip(label: tag))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected ? kAccent : kLine,
                  ),
                )
              else if (record.importance >= 4)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: const Color(0xFFB5842E).withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
