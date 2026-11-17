import 'package:flutter/material.dart';
import 'package:zlogbook/core/app_info.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/widgets/app_icons.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 44, color: kInkSoft.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: kInk,
              ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: kInkSoft),
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.status, this.size = 8});

  final RecordStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppIcons.statusColor(status),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 白底圆角分块，标题 + 内容。
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (title != null) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kInkSoft,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 10),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 到期提示：剩余天数 / 已过期天数。只有设了到期日的记录才显示。
class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.expiresAt});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    final int days = daysFromToday(expiresAt);
    final bool expired = days < 0;
    final bool soon = !expired && days <= kExpiringSoonDays;

    final Color color = expired
        ? kInkSoft
        : soon
            ? const Color(0xFFB5842E)
            : kInkSoft;
    final String label = expired ? '已过期 ${-days} 天' : '剩 ${days} 天';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          expired ? Icons.event_busy_outlined : Icons.event_available_outlined,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.onTap, this.dense = true});

  final String label;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 10,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: kAccent),
      ),
    );
    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: content,
    );
  }
}

/// 详情页的「标签：值」一行。
class InfoLine extends StatelessWidget {
  const InfoLine({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: kInkSoft),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: kInk, height: 1.4),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
