import 'dart:convert';

import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/core/utils/ids.dart';
import 'package:zlogbook/core/utils/text_utils.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/login_method.dart';

const Object _unset = Object();

/// 一条资产记录。名称是唯一必填项。
class AssetRecord {
  const AssetRecord({
    required this.id,
    required this.name,
    this.folderId,
    this.status = RecordStatus.active,
    this.importance = 3,
    this.notes,
    this.url,
    this.value,
    this.expiresAt,
    this.tags = const <String>[],
    this.logins = const <LoginMethod>[],
    this.extra = const <String, Object?>{},
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String? folderId;
  final RecordStatus status;
  final int importance;
  final String? notes;
  final String? url;
  final double? value;
  final DateTime? expiresAt;
  final List<String> tags;
  final List<LoginMethod> logins;

  /// 自定义字段取值：key -> 值。
  final Map<String, Object?> extra;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 软删除时间，非空即在回收站。
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  LoginMethod? get primaryLogin {
    for (final LoginMethod login in logins) {
      if (login.isPrimary) {
        return login;
      }
    }
    return logins.isEmpty ? null : logins.first;
  }

  factory AssetRecord.fromMap(Map<String, Object?> map) {
    final DateTime created =
        parseLooseDateTime(map['created_at'] as String?) ?? DateTime.now();
    return AssetRecord(
      id: (map['id'] as String?) ?? newId(),
      name: (map['name'] as String?) ?? '',
      folderId: map['folder_id'] as String?,
      status: recordStatusOf(map['status'] as String?),
      importance: clampImportance((map['importance'] as int?) ?? 3),
      notes: map['notes'] as String?,
      url: map['url'] as String?,
      value: (map['value'] as num?)?.toDouble(),
      expiresAt: parseLooseDate(map['expires_at'] as String?),
      tags: splitPipe(map['tags'] as String?),
      logins: decodeLogins(map['logins_json'] as String?),
      extra: decodeExtra(map['extra_json'] as String?),
      createdAt: created,
      updatedAt: parseLooseDateTime(map['updated_at'] as String?) ?? created,
      deletedAt: parseLooseDateTime(map['deleted_at'] as String?),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'folder_id': folderId,
      'status': status.code,
      'importance': importance,
      'notes': notes,
      'url': url,
      'value': value,
      'expires_at': expiresAt == null ? null : formatDate(expiresAt!),
      'tags': joinPipe(tags),
      'logins_json': jsonEncode(
        logins.map((LoginMethod login) => login.toJson()).toList(),
      ),
      'extra_json': jsonEncode(extra),
      'created_at': isoDateTime(createdAt),
      'updated_at': isoDateTime(updatedAt),
      'deleted_at': deletedAt == null ? null : isoDateTime(deletedAt!),
    };
  }

  AssetRecord copyWith({
    String? name,
    Object? folderId = _unset,
    RecordStatus? status,
    int? importance,
    Object? notes = _unset,
    Object? url = _unset,
    Object? value = _unset,
    Object? expiresAt = _unset,
    List<String>? tags,
    List<LoginMethod>? logins,
    Map<String, Object?>? extra,
    DateTime? updatedAt,
    Object? deletedAt = _unset,
  }) {
    return AssetRecord(
      id: id,
      name: name ?? this.name,
      folderId:
          identical(folderId, _unset) ? this.folderId : folderId as String?,
      status: status ?? this.status,
      importance: importance ?? this.importance,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      url: identical(url, _unset) ? this.url : url as String?,
      value: identical(value, _unset) ? this.value : (value as num?)?.toDouble(),
      expiresAt: identical(expiresAt, _unset)
          ? this.expiresAt
          : expiresAt as DateTime?,
      tags: tags ?? this.tags,
      logins: logins ?? this.logins,
      extra: extra ?? this.extra,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt:
          identical(deletedAt, _unset) ? this.deletedAt : deletedAt as DateTime?,
    );
  }
}

/// 重要度收敛到 1–5。刻意不用 clamp，避免 num 与 int 之间的静态类型歧义。
int clampImportance(int value) {
  if (value < 1) {
    return 1;
  }
  if (value > 5) {
    return 5;
  }
  return value;
}

List<LoginMethod> decodeLogins(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const <LoginMethod>[];
  }
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <LoginMethod>[];
    }
    return decoded
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> item) =>
            LoginMethod.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  } catch (_) {
    return const <LoginMethod>[];
  }
}

Map<String, Object?> decodeExtra(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return <String, Object?>{};
  }
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return <String, Object?>{};
    }
    return Map<String, Object?>.from(decoded);
  } catch (_) {
    return <String, Object?>{};
  }
}
