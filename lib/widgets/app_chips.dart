import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';

/// 统一的单选标签。
///
/// Material 3 的 ChoiceChip 在选中时会把 avatar 换成对勾，状态圆点、类型图标
/// 因此被盖掉；默认选中底色也偏淡。这里固定：不显示对勾、选中换底色 + 描边 +
/// 加粗文字，保证「选中」一眼可见且 avatar 不丢。
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    this.avatar,
    this.onSelected,
  });

  final Widget label;
  final bool selected;
  final Widget? avatar;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: label,
      avatar: avatar,
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected,
      backgroundColor: kSurface,
      selectedColor: kAccent.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected ? kAccent : kLine,
        width: selected ? 1.4 : 1,
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        color: selected ? kAccent : kInk,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

/// 统一的多选标签，外观与 [AppChip] 一致。
class AppTagChip extends StatelessWidget {
  const AppTagChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
  });

  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: label,
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected,
      backgroundColor: kSurface,
      selectedColor: kAccent.withValues(alpha: 0.14),
      side: BorderSide(
        color: selected ? kAccent : kLine,
        width: selected ? 1.4 : 1,
      ),
      labelStyle: TextStyle(
        fontSize: 13,
        color: selected ? kAccent : kInk,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}
