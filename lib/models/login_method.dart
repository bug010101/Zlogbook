import 'package:zlogbook/core/utils/ids.dart';
import 'package:zlogbook/models/enums.dart';

const Object _unset = Object();

/// 一条记录上挂载的登录方式。存于 records.logins_json，不单独建表。
class LoginMethod {
  const LoginMethod({
    required this.id,
    required this.kind,
    this.account = '',
    this.identityId,
    this.isPrimary = false,
    this.usable = true,
    this.note = '',
  });

  final String id;
  final LoginKind kind;

  /// 账号值快照。引用身份池时仍保留最后一次的值，用于身份被删除后的降级。
  final String account;

  /// 为空 = 直接填写；非空 = 引用身份池。
  final String? identityId;
  final bool isPrimary;
  final bool usable;
  final String note;

  bool get isLinked => identityId != null && identityId!.isNotEmpty;

  factory LoginMethod.fromJson(Map<String, dynamic> json) {
    return LoginMethod(
      id: (json['id'] as String?) ?? newId(),
      kind: loginKindOf(json['kind'] as String?),
      account: (json['account'] as String?) ?? '',
      identityId: json['identity_id'] as String?,
      isPrimary: (json['is_primary'] as bool?) ?? false,
      usable: (json['usable'] as bool?) ?? true,
      note: (json['note'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'kind': kind.code,
      'account': account,
      'identity_id': identityId,
      'is_primary': isPrimary,
      'usable': usable,
      'note': note,
    };
  }

  LoginMethod copyWith({
    LoginKind? kind,
    String? account,
    Object? identityId = _unset,
    bool? isPrimary,
    bool? usable,
    String? note,
  }) {
    return LoginMethod(
      id: id,
      kind: kind ?? this.kind,
      account: account ?? this.account,
      identityId:
          identical(identityId, _unset) ? this.identityId : identityId as String?,
      isPrimary: isPrimary ?? this.isPrimary,
      usable: usable ?? this.usable,
      note: note ?? this.note,
    );
  }
}
