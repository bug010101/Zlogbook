import 'package:flutter/services.dart';

/// 触感反馈统一入口，方便以后整体关掉。
class Haptics {
  const Haptics._();

  static Future<void> selection() => HapticFeedback.selectionClick();

  static Future<void> light() => HapticFeedback.lightImpact();

  static Future<void> medium() => HapticFeedback.mediumImpact();
}
