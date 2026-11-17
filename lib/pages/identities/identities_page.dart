import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/core/utils/text_utils.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/identity.dart';
import 'package:zlogbook/pages/identities/identity_detail_page.dart';
import 'package:zlogbook/pages/identities/identity_editor_sheet.dart';
import 'package:zlogbook/services/haptics.dart';
import 'package:zlogbook/state/app_scope.dart';
import 'package:zlogbook/state/app_state.dart';
import 'package:zlogbook/widgets/app_icons.dart';
import 'package:zlogbook/widgets/app_sheet.dart';
import 'package:zlogbook/widgets/common.dart';
import 'package:zlogbook/widgets/dialogs.dart';

/// 身份池：按状态分组，显示号码、状态与被引用条数。
class IdentitiesPage extends StatelessWidget {
  const IdentitiesPage({super.key});

  Future<void> _add(BuildContext context) async {
    final AppState state = AppScope.read(context);
    final Identity? created = await showAppSheet<Identity>(
      context,
      const IdentityEditorSheet(),
    );
    if (created == null || !context.mounted) {
      return;
    }
    final Identity? existing =
        await state.findIdentity(created.kind, created.value);
    if (existing != null) {
      if (context.mounted) {
        showToast(context, '身份池里已经存在这个号码');
      }
      return;
    }
    await state.saveIdentity(created);
  }

  Future<void> _menu(BuildContext context, Identity identity) async {
    final AppState state = AppScope.read(context);
    final String action = (await showChoiceSheet<String>(
      context,
      title: identity.value,
      choices: const <SheetChoice<String>>[
        SheetChoice<String>(value: 'edit', label: '编辑', icon: Icons.edit_outlined),
        SheetChoice<String>(
          value: 'delete',
          label: '删除',
          icon: Icons.delete_outline,
        ),
      ],
    )) ??
        '';
    if (!context.mounted) {
      return;
    }
    if (action == 'edit') {
      final Identity? updated = await showAppSheet<Identity>(
        context,
        IdentityEditorSheet(existing: identity),
      );
      if (updated != null) {
        await state.saveIdentity(updated);
      }
    } else if (action == 'delete') {
      final int count = state.usageCount(identity.id);
      final bool ok = await confirmAction(
        context,
        title: '删除这个身份？',
        message: count == 0
            ? '删除后不可恢复。'
            : '有 $count 处登录方式引用了它，删除后这些记录会保留最后一次的号码，但不再同步。',
        confirmLabel: '删除',
        destructive: true,
      );
      if (!ok) {
        return;
      }
      await state.deleteIdentity(identity);
      await Haptics.medium();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<Identity> identities = state.identities;

    final Map<IdentityStatus, List<Identity>> grouped =
        <IdentityStatus, List<Identity>>{
      for (final IdentityStatus status in IdentityStatus.values)
        status: <Identity>[],
    };
    for (final Identity identity in identities) {
      grouped[identity.status]!.add(identity);
    }

    int totalReferences = 0;
    for (final Identity identity in identities) {
      totalReferences += state.usageCount(identity.id);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('身份'),
        actions: <Widget>[
          IconButton(
            tooltip: '新建身份',
            icon: const Icon(Icons.add),
            onPressed: () => _add(context),
          ),
        ],
      ),
      body: identities.isEmpty
          ? EmptyState(
              icon: Icons.badge_outlined,
              title: '身份池是空的',
              subtitle: '把手机号、邮箱、QQ、微信集中在这里管理，\n记录里的登录方式可以直接引用',
              action: FilledButton(
                onPressed: () => _add(context),
                child: const Text('新建身份'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Text(
                    '${identities.length} 个身份 · $totalReferences 处引用',
                    style: const TextStyle(fontSize: 12, color: kInkSoft),
                  ),
                ),
                for (final IdentityStatus status in IdentityStatus.values)
                  if (grouped[status]!.isNotEmpty) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: AppIcons.identityStatusColor(status),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kInkSoft,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${grouped[status]!.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: kInkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...grouped[status]!.map(
                      (Identity identity) => _tile(context, state, identity),
                    ),
                  ],
              ],
            ),
      floatingActionButton: identities.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _add(context),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _tile(BuildContext context, AppState state, Identity identity) {
    final int count = state.usageCount(identity.id);
    final String display = identity.kind == LoginKind.phone
        ? maskPhone(identity.value)
        : identity.value;
    return Material(
      color: kSurface,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => IdentityDetailPage(identityId: identity.id),
          ),
        ),
        onLongPress: () {
          Haptics.light();
          _menu(context, identity);
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: kLine, width: 0.6)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  AppIcons.login(identity.kind),
                  size: 18,
                  color: kAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        identity.kind.label,
                        if (identity.label != null) identity.label!,
                        count == 0 ? '未被引用' : '被 $count 处引用',
                      ].join(' · '),
                      style: const TextStyle(fontSize: 12, color: kInkSoft),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: kLine),
            ],
          ),
        ),
      ),
    );
  }
}
