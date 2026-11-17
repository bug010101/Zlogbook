import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/core/utils/text_utils.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/field_def.dart';
import 'package:zlogbook/models/folder.dart';
import 'package:zlogbook/models/login_method.dart';
import 'package:zlogbook/models/record.dart';
import 'package:zlogbook/pages/ledger/record_edit_page.dart';
import 'package:zlogbook/services/haptics.dart';
import 'package:zlogbook/state/app_scope.dart';
import 'package:zlogbook/state/app_state.dart';
import 'package:zlogbook/widgets/app_icons.dart';
import 'package:zlogbook/widgets/common.dart';
import 'package:zlogbook/widgets/dialogs.dart';

class RecordDetailPage extends StatelessWidget {
  const RecordDetailPage({super.key, required this.recordId});

  final String recordId;

  AssetRecord? _find(AppState state) {
    for (final AssetRecord record in state.records) {
      if (record.id == recordId) {
        return record;
      }
    }
    return null;
  }

  String _plainText(AppState state, AssetRecord record) {
    final StringBuffer buffer = StringBuffer()
      ..writeln(record.name)
      ..writeln('文件夹：${state.folderName(record.folderId)}')
      ..writeln('状态：${record.status.label}');
    for (final LoginMethod login in record.logins) {
      buffer.writeln(
        '登录：${login.kind.label} ${state.accountOf(login)}'
        '${login.isPrimary ? '（主）' : ''}',
      );
    }
    if (record.tags.isNotEmpty) {
      buffer.writeln('标签：${record.tags.join('、')}');
    }
    if (record.url != null) {
      buffer.writeln('网址：${record.url}');
    }
    if (record.value != null) {
      buffer.writeln('估值：${formatAmount(record.value)}');
    }
    if (record.expiresAt != null) {
      buffer.writeln('到期：${formatDate(record.expiresAt!)}');
    }
    if (record.notes != null) {
      buffer.writeln('备注：${record.notes}');
    }
    return buffer.toString().trimRight();
  }

  Future<void> _copy(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    await Haptics.selection();
    if (context.mounted) {
      showToast(context, '$label已复制');
    }
  }

  Future<void> _delete(BuildContext context, AssetRecord record) async {
    final bool ok = await confirmAction(
      context,
      title: '删除「${record.name}」？',
      message: '会移入回收站，之后可以恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) {
      return;
    }
    final AppState state = AppScope.read(context);
    final NavigatorState navigator = Navigator.of(context);
    await state.deleteRecord(record.id);
    await Haptics.medium();
    if (!context.mounted) {
      return;
    }
    showUndoToast(
      context,
      '已移入回收站',
      onUndo: () => state.restoreRecord(record.id),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AssetRecord? record = _find(state);
    if (record == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.inbox_outlined,
          title: '记录不存在',
          subtitle: '可能已经被删除',
        ),
      );
    }

    final Folder? folder = state.folderById(record.folderId);
    final List<FieldDef> fields = state
        .fieldDefsFor(record.folderId)
        .where((FieldDef def) => record.extra[def.key] != null)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('记录详情'),
        actions: <Widget>[
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) => RecordEditPage(record: record),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz),
            onSelected: (String value) {
              if (value == 'copy') {
                _copy(context, _plainText(state, record), '整条记录');
              } else if (value == 'delete') {
                _delete(context, record);
              }
            },
            itemBuilder: (BuildContext ctx) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'copy', child: Text('复制整条记录')),
              PopupMenuItem<String>(value: 'delete', child: Text('删除')),
            ],
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppIcons.accent(folder?.color)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          AppIcons.folder(folder?.icon),
                          color: AppIcons.accent(folder?.color),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              record.name,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                Text(
                                  state.folderName(record.folderId),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: kInkSoft,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    StatusDot(status: record.status),
                                    const SizedBox(width: 4),
                                    Text(
                                      record.status.label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: kInkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                                if (record.expiresAt != null)
                                  ExpiryBadge(expiresAt: record.expiresAt!),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      for (int i = 1; i <= 5; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(
                            i <= record.importance
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 16,
                            color: i <= record.importance
                                ? const Color(0xFFB5842E)
                                : kLine,
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        importanceLabel(record.importance),
                        style: const TextStyle(fontSize: 12, color: kInkSoft),
                      ),
                    ],
                  ),
                  if (record.tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: record.tags
                          .map((String tag) => TagChip(label: tag, dense: false))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (record.logins.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            SectionCard(
              title: '登录方式',
              children: <Widget>[
                for (final LoginMethod login in record.logins)
                  InkWell(
                    onTap: () => _copy(
                      context,
                      state.accountOf(login),
                      '${login.kind.label}账号',
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            AppIcons.login(login.kind),
                            size: 18,
                            color: kInkSoft,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  state.accountOf(login),
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  <String>[
                                    login.kind.label,
                                    if (login.identityId != null) '引用身份池',
                                    if (!login.usable) '不可用',
                                    if (login.note.isNotEmpty) login.note,
                                  ].join(' · '),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kInkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (login.isPrimary)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB5842E)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '主登录',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF8A6420),
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, size: 14, color: kLine),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SectionCard(
            title: '详情',
            children: <Widget>[
              InfoLine(
                label: '文件夹',
                value: state.folderName(record.folderId),
              ),
              InfoLine(
                label: '网址',
                value: record.url ?? '未填写',
              ),
              InfoLine(
                label: '估值',
                value: record.value == null
                    ? '未填写'
                    : formatAmount(record.value),
              ),
              InfoLine(
                label: '到期日',
                value: record.expiresAt == null
                    ? '未设置'
                    : '${formatDate(record.expiresAt!)}（${relativeDayLabel(record.expiresAt!)}）',
              ),
              InfoLine(label: '创建于', value: formatDateTime(record.createdAt)),
              InfoLine(label: '修改于', value: formatDateTime(record.updatedAt)),
            ],
          ),
          if (fields.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            SectionCard(
              title: '自定义字段',
              children: <Widget>[
                for (final FieldDef def in fields)
                  InfoLine(
                    label: def.label,
                    value: _extraText(record.extra[def.key], def),
                  ),
              ],
            ),
          ],
          if (record.notes != null) ...<Widget>[
            const SizedBox(height: 12),
            SectionCard(
              title: '备注',
              children: <Widget>[
                Text(
                  record.notes!,
                  style: const TextStyle(fontSize: 14, height: 1.55),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _extraText(Object? value, FieldDef def) {
    if (value == null) {
      return '';
    }
    if (value is DateTime) {
      return formatDate(value);
    }
    if (value is List) {
      return value.map((Object? item) => '$item').join('、');
    }
    if (value is num) {
      return formatAmount(value.toDouble());
    }
    return '$value';
  }
}
