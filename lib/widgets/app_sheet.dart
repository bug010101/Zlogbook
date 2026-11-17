import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';

const double _kHandleHeight = 26;

/// 统一的底部弹层：顶部拖拽条 + 最大高度限制 + 键盘避让。
Future<T?> showAppSheet<T>(
  BuildContext context,
  Widget child, {
  bool tall = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kPaper,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (BuildContext ctx) {
      final MediaQueryData media = MediaQuery.of(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: media.size.height * (tall ? 0.92 : 0.82),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: _kHandleHeight,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      );
    },
  );
}

class SheetChoice<T> {
  const SheetChoice({
    required this.value,
    required this.label,
    this.icon,
    this.description,
    this.trailing,
    this.selected = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? description;
  final Widget? trailing;
  final bool selected;
}

/// 选项列表弹层。
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetChoice<T>> choices,
  String? subtitle,
}) {
  return showAppSheet<T>(
    context,
    _ChoiceSheet<T>(title: title, subtitle: subtitle, choices: choices),
  );
}

class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.choices,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<SheetChoice<T>> choices;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: kInkSoft),
                ),
              ],
            ],
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: choices.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
            itemBuilder: (BuildContext ctx, int index) {
              final SheetChoice<T> choice = choices[index];
              return ListTile(
                leading: choice.icon == null
                    ? null
                    : Icon(choice.icon, size: 20, color: kInkSoft),
                title: Text(choice.label, style: const TextStyle(fontSize: 15)),
                subtitle: choice.description == null
                    ? null
                    : Text(
                        choice.description!,
                        style: const TextStyle(fontSize: 12, color: kInkSoft),
                      ),
                trailing: choice.trailing ??
                    (choice.selected
                        ? const Icon(Icons.check, size: 18, color: kAccent)
                        : null),
                onTap: () => Navigator.of(ctx).pop(choice.value),
              );
            },
          ),
        ),
      ],
    );
  }
}
