import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/models/enums.dart';

/// 图标与颜色的映射表：数据库只存标识字符串，表现层负责翻译成 IconData / Color。
class AppIcons {
  const AppIcons._();

  static const Map<String, IconData> folderIcons = <String, IconData>{
    'folder': Icons.folder_outlined,
    'social': Icons.forum_outlined,
    'game': Icons.sports_esports_outlined,
    'money': Icons.account_balance_wallet_outlined,
    'work': Icons.work_outline,
    'mail': Icons.mail_outline,
    'cloud': Icons.cloud_outlined,
    'shop': Icons.shopping_bag_outlined,
    'video': Icons.play_circle_outline,
    'study': Icons.menu_book_outlined,
    'tool': Icons.build_outlined,
    'key': Icons.key_outlined,
  };

  static const List<String> folderIconNames = <String>[
    'folder',
    'social',
    'game',
    'money',
    'work',
    'mail',
    'cloud',
    'shop',
    'video',
    'study',
    'tool',
    'key',
  ];

  static IconData folder(String? name) =>
      folderIcons[name] ?? Icons.folder_outlined;

  static const Map<String, Color> accentColors = <String, Color>{
    'slate': Color(0xFF6B7269),
    'green': Color(0xFF3E7B5C),
    'teal': Color(0xFF2F6F72),
    'blue': Color(0xFF3A6EA5),
    'violet': Color(0xFF6A5C9E),
    'rose': Color(0xFFA0576B),
    'amber': Color(0xFFB5842E),
    'rust': Color(0xFFA45B45),
  };

  static const List<String> accentColorNames = <String>[
    'slate',
    'green',
    'teal',
    'blue',
    'violet',
    'rose',
    'amber',
    'rust',
  ];

  static Color accent(String? name) =>
      accentColors[name] ?? accentColors['slate']!;

  static IconData login(LoginKind kind) {
    switch (kind) {
      case LoginKind.phone:
        return Icons.smartphone_outlined;
      case LoginKind.email:
        return Icons.alternate_email;
      case LoginKind.qq:
        return Icons.chat_bubble_outline;
      case LoginKind.wechat:
        return Icons.wechat_outlined;
      case LoginKind.password:
        return Icons.password_outlined;
      case LoginKind.other:
        return Icons.more_horiz;
    }
    return Icons.more_horiz;
  }

  static Color statusColor(RecordStatus status) {
    switch (status) {
      case RecordStatus.active:
        return const Color(0xFF3E7B5C);
      case RecordStatus.idle:
        return const Color(0xFFB5842E);
      case RecordStatus.abandoned:
        return const Color(0xFF8A8F98);
      case RecordStatus.deactivated:
        return const Color(0xFFA85A50);
    }
    return const Color(0xFF6B7269);
  }

  static Color identityStatusColor(IdentityStatus status) {
    switch (status) {
      case IdentityStatus.active:
        return const Color(0xFF3E7B5C);
      case IdentityStatus.idle:
        return const Color(0xFFB5842E);
      case IdentityStatus.deactivated:
        return const Color(0xFFA85A50);
    }
    return const Color(0xFF6B7269);
  }

  static const Color expiredColor = kInkSoft;
}
