import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/login_method.dart';
import 'package:zlogbook/models/record.dart';

/// 身份被引用的一条明细，引用关系由扫描 logins_json 在内存构建。
class IdentityUsage {
  const IdentityUsage({
    required this.recordId,
    required this.recordName,
    required this.recordStatus,
    required this.loginAccount,
    required this.loginKind,
    required this.isPrimary,
    required this.loginUsable,
  });

  final String recordId;
  final String recordName;
  final RecordStatus recordStatus;
  final String loginAccount;
  final LoginKind loginKind;
  final bool isPrimary;
  final bool loginUsable;

  factory IdentityUsage.of(AssetRecord record, LoginMethod login) {
    return IdentityUsage(
      recordId: record.id,
      recordName: record.name,
      recordStatus: record.status,
      loginAccount: login.account,
      loginKind: login.kind,
      isPrimary: login.isPrimary,
      loginUsable: login.usable,
    );
  }
}
