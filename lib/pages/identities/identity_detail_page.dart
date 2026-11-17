import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/identity.dart';
import 'package:zlogbook/models/identity_usage.dart';
import 'package:zlogbook/pages/identities/identity_editor_sheet.dart';
import 'package:zlogbook/pages/ledger/record_detail_page.dart';
import 'package:zlogbook/services/haptics.dart';
import 'package:zlogbook/state/app_scope.dart';
import 'package:zlogbook/state/app_state.dart';
import 'package:zlogbook/widgets/app_icons.dart';
import 'package:zlogbook/widgets/app_sheet.dart';
import 'package:zlogbook/widgets/common.dart';
import 'package:zlogbook/widgets/dialogs.dart';

class IdentityDetailPage extends StatelessWidget {
  const IdentityDetailPage({super.key, required this.identityId});

  final String identityId;

  Identity? _find(AppState state) => state.identityById(identityId);

  Future<void> _edit(BuildContext context, Identity identity) async {
    final Identity? updated = await showAppSheet<Identity>(
      context,
      IdentityEditorSheet(existing: identity),
    );
    if (updated == null) {
      return;
    }
    await AppScope.read(context).saveIdentity(updated);
  }

  Future<void> _delete(BuildContext context, Identity identity) async {
    final AppState state = AppScope.read(context);
    final int count = state.usageCount(identity.id);
    final bool ok = await confirmAction(
      context,
      title: '删除这个身份？',
      message: count == 0
          ? '删除后不可恢复。'
          : '有 $count 处登录方式引用了它。删除后这些记录会保留最后一次的号码，'
              '但不再跟随身份池同步。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    await state.deleteIdentity(identity);
    await Haptics.medium();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Identity? identity = _find(state);
    if (identity == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: '身份不存在',
          subtitle: '可能已经被删除',
        ),
      );
    }

    final List<IdentityUsage> usages = List<IdentityUsage>.from(
      state.usagesOf(identity.id),
    );
    usages.sort((IdentityUsage a, IdentityUsage b) {
      if (a.recordStatus == b.recordStatus) {
        return a.recordName.compareTo(b.recordName);
      }
      // 已注销排最前，其余按状态枚举顺序
      if (a.recordStatus == RecordStatus.deactivated) {
        return -1;
      }
      if (b.recordStatus == RecordStatus.deactivated) {
        return 1;
      }
      return a.recordStatus.index.compareTo(b.recordStatus.index);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('身份详情'),
        actions: <Widget>[
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context, identity),
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, identity),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppIcons.identityStatusColor(identity.status)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          AppIcons.login(identity.kind),
                          color: AppIcons.identityStatusColor(identity.status),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              identity.value,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              <String>[
                                identity.kind.label,
                                identity.status.label,
                                if (identity.label != null) identity.label!,
                              ].join(' · '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: kInkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '被 ${usages.length} 处登录方式引用',
                    style: const TextStyle(fontSize: 13, color: kInkSoft),
                  ),
                  if (identity.notes != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      identity.notes!,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '创建于 ${formatDateTime(identity.createdAt)}',
                    style: const TextStyle(fontSize: 11, color: kInkSoft),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (usages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(
                icon: Icons.link_off,
                title: '还没有记录引用它',
                subtitle: '在记录里添加登录方式时，可以从身份池选择这个号码',
              ),
            )
          else
            SectionCard(
              title: '引用它的记录',
              children: <Widget>[
                for (final IdentityUsage usage in usages)
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RecordDetailPage(
                          recordId: usage.recordId,
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: <Widget>[
                          StatusDot(status: usage.recordStatus),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  usage.recordName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  <String>[
                                    usage.recordStatus.label,
                                    usage.loginKind.label,
                                    if (usage.isPrimary) '主登录',
                                    if (!usage.loginUsable) '不可用',
                                  ].join(' · '),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kInkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: kLine,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            '提示：直接修改这个号码，所有引用它的记录都会同步更新。'
            '记录里直接填写、没有引用身份池的账号不受影响。',
            style: TextStyle(
              fontSize: 12,
              color: kInkSoft.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
