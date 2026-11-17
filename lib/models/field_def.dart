import 'package:zlogbook/core/utils/ids.dart';
import 'package:zlogbook/models/enums.dart';

const Object _unset = Object();

/// 自定义字段定义。取值存 records.extra_json，加字段不需要迁移。
class FieldDef {
  const FieldDef({
    required this.id,
    required this.key,
    required this.label,
    this.kind = FieldKind.text,
    this.options = const <String>[],
    this.scope = FieldScope.all,
    this.scopeFolderId,
    this.sortOrder = 0,
  });

  final String id;

  /// 内部标识，也是 extra_json 的键。
  final String key;

  /// 显示名，可直接用中文。
  final String label;
  final FieldKind kind;
  final List<String> options;
  final FieldScope scope;
  final String? scopeFolderId;
  final int sortOrder;

  factory FieldDef.fromMap(Map<String, Object?> map) {
    final List<String> options = (map['options'] as String? ?? '')
        .split('|')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
    return FieldDef(
      id: (map['id'] as String?) ?? newId(),
      key: (map['key'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      kind: fieldKindOf(map['kind'] as String?),
      options: options,
      scope: fieldScopeOf(map['scope_type'] as String?),
      scopeFolderId: map['scope_folder_id'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'key': key,
      'label': label,
      'kind': kind.code,
      'options': options.isEmpty ? null : options.join('|'),
      'scope_type': scope.code,
      'scope_folder_id': scope == FieldScope.folder ? scopeFolderId : null,
      'sort_order': sortOrder,
    };
  }

  /// 该字段是否对指定文件夹的记录可见。
  bool appliesTo(String? folderId) {
    if (scope == FieldScope.all) {
      return true;
    }
    return scopeFolderId != null && scopeFolderId == folderId;
  }

  FieldDef copyWith({
    String? key,
    String? label,
    FieldKind? kind,
    List<String>? options,
    FieldScope? scope,
    Object? scopeFolderId = _unset,
    int? sortOrder,
  }) {
    return FieldDef(
      id: id,
      key: key ?? this.key,
      label: label ?? this.label,
      kind: kind ?? this.kind,
      options: options ?? this.options,
      scope: scope ?? this.scope,
      scopeFolderId: identical(scopeFolderId, _unset)
          ? this.scopeFolderId
          : scopeFolderId as String?,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
