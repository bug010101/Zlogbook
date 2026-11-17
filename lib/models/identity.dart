import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/core/utils/ids.dart';
import 'package:zlogbook/models/enums.dart';

const Object _noValue = Object();

/// 身份池条目：手机号 / 邮箱 / QQ / 微信 / 其他。
class Identity {
  const Identity({
    required this.id,
    required this.kind,
    required this.value,
    this.label,
    this.status = IdentityStatus.active,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final LoginKind kind;
  final String value;

  /// 归属说明：主号、小号、家人。
  final String? label;
  final IdentityStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Identity.fromMap(Map<String, Object?> map) {
    final DateTime created =
        parseLooseDateTime(map['created_at'] as String?) ?? DateTime.now();
    return Identity(
      id: (map['id'] as String?) ?? newId(),
      kind: loginKindOf(map['kind'] as String?),
      value: (map['value'] as String?) ?? '',
      label: map['label'] as String?,
      status: identityStatusOf(map['status'] as String?),
      notes: map['notes'] as String?,
      createdAt: created,
      updatedAt: parseLooseDateTime(map['updated_at'] as String?) ?? created,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'kind': kind.code,
      'value': value,
      'label': label,
      'status': status.code,
      'notes': notes,
      'created_at': isoDateTime(createdAt),
      'updated_at': isoDateTime(updatedAt),
    };
  }

  Identity copyWith({
    LoginKind? kind,
    String? value,
    Object? label = _noValue,
    IdentityStatus? status,
    Object? notes = _noValue,
    DateTime? updatedAt,
  }) {
    return Identity(
      id: id,
      kind: kind ?? this.kind,
      value: value ?? this.value,
      label: identical(label, _noValue) ? this.label : label as String?,
      status: status ?? this.status,
      notes: identical(notes, _noValue) ? this.notes : notes as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
