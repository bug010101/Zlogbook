import 'package:flutter/widgets.dart';
import 'package:zlogbook/state/app_state.dart';

/// 状态注入。`of` 会订阅变化，`read` 只取实例不订阅。
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 未注入到 widget 树中');
    return scope!.notifier!;
  }

  static AppState read(BuildContext context) {
    final AppScope? scope =
        context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 未注入到 widget 树中');
    return scope!.notifier!;
  }
}
