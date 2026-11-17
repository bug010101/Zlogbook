import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/core/utils/ids.dart';

/// 自定义分类，只有一层。
class Folder {
  const Folder({
    required this.id,
    required this.name,
    this.icon = 'folder',
    this.color = 'slate',
    this.sortOrder = 0,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// 图标标识，由表现层映射为 IconData。
  final String icon;

  /// 颜色标识，由表现层映射为 Color。
  final String color;
  final int sortOrder;
  final DateTime createdAt;

  factory Folder.fromMap(Map<String, Object?> map) {
    return Folder(
      id: (map['id'] as String?) ?? newId(),
      name: (map['name'] as String?) ?? '',
      icon: (map['icon'] as String?) ?? 'folder',
      color: (map['color'] as String?) ?? 'slate',
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: parseLooseDateTime(map['created_at'] as String?) ?? DateTime.now(),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'created_at': isoDateTime(createdAt),
    };
  }

  Folder copyWith({
    String? name,
    String? icon,
    String? color,
    int? sortOrder,
  }) {
    return Folder(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
    );
  }
}
