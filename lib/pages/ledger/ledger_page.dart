import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zlogbook/core/app_info.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/folder.dart';
import 'package:zlogbook/models/login_method.dart';
import 'package:zlogbook/models/record.dart';
import 'package:zlogbook/pages/ledger/batch_action_bar.dart';
import 'package:zlogbook/pages/ledger/folder_manage_page.dart';
import 'package:zlogbook/pages/ledger/record_detail_page.dart';
import 'package:zlogbook/pages/ledger/record_edit_page.dart';
import 'package:zlogbook/pages/ledger/record_tile.dart';
import 'package:zlogbook/pages/ledger/timeline_view.dart';
import 'package:zlogbook/services/haptics.dart';
import 'package:zlogbook/state/app_scope.dart';
import 'package:zlogbook/state/app_state.dart';
import 'package:zlogbook/widgets/app_icons.dart';
import 'package:zlogbook/widgets/app_sheet.dart';
import 'package:zlogbook/widgets/common.dart';
import 'package:zlogbook/widgets/dialogs.dart';

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  final TextEditingController _search = TextEditingController();
  final Set<String> _selected = <String>{};
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _search.text = AppScope.read(context).query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  Future<void> _openNew(AppState state) async {
    final String? folderId = state.folderFilter == AppState.uncategorizedFilterId
        ? null
        : state.folderFilter;
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => RecordEditPage(initialFolderId: folderId),
      ),
    );
  }

  Future<void> _openDetail(AssetRecord record) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordDetailPage(recordId: record.id),
      ),
    );
  }

  Future<void> _openEdit(AssetRecord record) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => RecordEditPage(record: record),
      ),
    );
  }

  Future<void> _deleteWithUndo(AppState state, AssetRecord record) async {
    await state.deleteRecord(record.id);
    await Haptics.medium();
    if (!mounted) {
      return;
    }
    showUndoToast(
      context,
      '「${record.name}」已移入回收站',
      onUndo: () => state.restoreRecord(record.id),
    );
  }

  Future<void> _copyText(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    await Haptics.selection();
    if (mounted) {
      showToast(context, '$label已复制');
    }
  }

  Future<void> _showRecordMenu(AppState state, AssetRecord record) async {
    final LoginMethod? primary = record.primaryLogin;
    final String action = (await showChoiceSheet<String>(
      context,
      title: record.name,
      subtitle: '长按快捷操作',
      choices: <SheetChoice<String>>[
        if (primary != null)
          SheetChoice<String>(
            value: 'login',
            label: '复制登录方式',
            icon: Icons.key_outlined,
            description: state.loginSummary(primary),
          ),
        if (primary != null)
          SheetChoice<String>(
            value: 'account',
            label: '复制账号',
            icon: Icons.copy_rounded,
            description: state.accountOf(primary),
          ),
        SheetChoice<String>(
          value: 'all',
          label: '复制整条记录',
          icon: Icons.notes_outlined,
        ),
        SheetChoice<String>(
          value: 'select',
          label: '进入多选',
          icon: Icons.checklist,
        ),
      ],
    )) ??
        '';
    if (!mounted) {
      return;
    }
    switch (action) {
      case 'login':
        if (primary != null) {
          await _copyText(state.loginSummary(primary), '登录方式');
        }
        break;
      case 'account':
        if (primary != null) {
          await _copyText(state.accountOf(primary), '账号');
        }
        break;
      case 'all':
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
        await _copyText(buffer.toString().trimRight(), '整条记录');
        break;
      case 'select':
        setState(() {
          _selecting = true;
          _selected.add(record.id);
        });
        break;
      default:
        break;
    }
  }

  Future<void> _batchStatus(AppState state) async {
    final RecordStatus? status = await showChoiceSheet<RecordStatus>(
      context,
      title: '改为状态',
      choices: RecordStatus.values
          .map(
            (RecordStatus value) => SheetChoice<RecordStatus>(
              value: value,
              label: value.label,
            ),
          )
          .toList(),
    );
    if (status == null) {
      return;
    }
    await state.batchUpdateStatus(_selected.toList(), status);
    if (mounted) {
      _exitSelection();
    }
  }

  Future<void> _batchMove(AppState state) async {
    final String? target = await showChoiceSheet<String>(
      context,
      title: '移动到文件夹',
      choices: <SheetChoice<String>>[
        const SheetChoice<String>(value: '', label: kUncategorizedLabel),
        ...state.folders.map(
          (Folder folder) => SheetChoice<String>(
            value: folder.id,
            label: folder.name,
          ),
        ),
      ],
    );
    if (target == null) {
      return;
    }
    await state.batchMoveToFolder(
      _selected.toList(),
      target.isEmpty ? null : target,
    );
    if (mounted) {
      _exitSelection();
    }
  }

  Future<void> _batchTag(AppState state) async {
    final String? tag = await promptText(
      context,
      title: '批量打标签',
      hint: '例如：常用',
      confirmLabel: '添加',
    );
    if (tag == null) {
      return;
    }
    await state.batchAddTag(_selected.toList(), tag);
    if (mounted) {
      _exitSelection();
    }
  }

  Future<void> _batchDelete(AppState state) async {
    final bool ok = await confirmAction(
      context,
      title: '删除 ${_selected.length} 条记录？',
      message: '会移入回收站，之后可以恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) {
      return;
    }
    await state.batchDelete(_selected.toList());
    await Haptics.medium();
    if (mounted) {
      _exitSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<AssetRecord> records = state.visibleRecords;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selecting ? '已选 ${_selected.length} 条' : '台账'),
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelection,
              )
            : null,
        actions: <Widget>[
          if (!_selecting) ...<Widget>[
            PopupMenuButton<SortMode>(
              tooltip: '排序',
              icon: const Icon(Icons.sort),
              initialValue: state.sortMode,
              onSelected: state.setSortMode,
              itemBuilder: (BuildContext ctx) => SortMode.values
                  .map(
                    (SortMode mode) => PopupMenuItem<SortMode>(
                      value: mode,
                      child: Text(mode.label),
                    ),
                  )
                  .toList(),
            ),
            IconButton(
              tooltip: state.timelineView ? '切换为列表' : '切换为时间轴',
              icon: Icon(
                state.timelineView ? Icons.view_list_outlined : Icons.timeline,
              ),
              onPressed: () => state.setTimelineView(!state.timelineView),
            ),
            IconButton(
              tooltip: '多选',
              icon: const Icon(Icons.checklist),
              onPressed: () => setState(() => _selecting = true),
            ),
          ] else
            IconButton(
              tooltip: '全选',
              icon: const Icon(Icons.select_all),
              onPressed: () => setState(() {
                _selected
                  ..clear()
                  ..addAll(records.map((AssetRecord r) => r.id));
              }),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: state.setQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索名称、账号、标签、备注',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _search.clear();
                          state.setQuery('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          _filterBar(state),
          const SizedBox(height: 4),
          Expanded(
            child: records.isEmpty
                ? EmptyState(
                    icon: state.records.isEmpty
                        ? Icons.inbox_outlined
                        : Icons.search_off,
                    title: state.records.isEmpty ? '还没有记录' : '没有匹配的记录',
                    subtitle: state.records.isEmpty
                        ? '点右下角加号，记下第一个账号'
                        : '试试换个关键词或清空筛选',
                    action: state.records.isEmpty
                        ? FilledButton(
                            onPressed: () => _openNew(state),
                            child: const Text('新建记录'),
                          )
                        : TextButton(
                            onPressed: () {
                              _search.clear();
                              state.clearFilters();
                              setState(() {});
                            },
                            child: const Text('清空筛选'),
                          ),
                  )
                : (state.timelineView
                    ? TimelineView(
                        records: records,
                        tileBuilder: (AssetRecord record) => _tile(state, record),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: records.length,
                        itemBuilder: (BuildContext ctx, int index) =>
                            _tile(state, records[index]),
                      )),
          ),
        ],
      ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
              onPressed: () => _openNew(state),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: _selecting
          ? BatchActionBar(
              selectedCount: _selected.length,
              onStatus: () => _batchStatus(state),
              onMove: () => _batchMove(state),
              onTag: () => _batchTag(state),
              onDelete: () => _batchDelete(state),
              onSelectAll: () => setState(() {
                _selected
                  ..clear()
                  ..addAll(records.map((AssetRecord r) => r.id));
              }),
            )
          : null,
    );
  }

  Widget _tile(AppState state, AssetRecord record) {
    final LoginMethod? primary = record.primaryLogin;
    final bool selected = _selected.contains(record.id);
    return Dismissible(
      key: ValueKey<String>('row-${record.id}'),
      direction: _selecting ? DismissDirection.none : DismissDirection.horizontal,
      background: _swipeBackground(true),
      secondaryBackground: _swipeBackground(false),
      confirmDismiss: (DismissDirection direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _openEdit(record);
        } else {
          await _deleteWithUndo(state, record);
        }
        return false;
      },
      child: RecordTile(
        record: record,
        folderName: state.folderName(record.folderId),
        folder: state.folderById(record.folderId),
        loginText: primary == null ? '' : state.loginSummary(primary),
        query: state.query,
        selected: selected,
        selectionMode: _selecting,
        onTap: () {
          if (_selecting) {
            setState(() {
              if (!_selected.remove(record.id)) {
                _selected.add(record.id);
              }
            });
            return;
          }
          _openDetail(record);
        },
        onLongPress: () {
          if (_selecting) {
            return;
          }
          Haptics.light();
          _showRecordMenu(state, record);
        },
      ),
    );
  }

  Widget _swipeBackground(bool leftAlign) {
    return Container(
      color: leftAlign
          ? kAccent.withValues(alpha: 0.14)
          : const Color(0xFFA85A50).withValues(alpha: 0.14),
      alignment: leftAlign ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Icon(
        leftAlign ? Icons.edit_outlined : Icons.delete_outline,
        color: leftAlign ? kAccent : const Color(0xFFA85A50),
        size: 20,
      ),
    );
  }

  /// 「全部」在下拉里补成「全部状态」，与收起时的文案保持一致。
  String _statusLabel(StatusFilter filter) {
    return filter == StatusFilter.all ? '全部状态' : filter.label;
  }

  Widget _filterBar(AppState state) {
    final bool folderActive = state.folderFilter != null;
    final String folderLabel;
    if (!folderActive) {
      folderLabel = '全部分类';
    } else if (state.folderFilter == AppState.uncategorizedFilterId) {
      folderLabel = kUncategorizedLabel;
    } else {
      folderLabel = state.folderName(state.folderFilter);
    }
    final RecordStatus? status = state.statusFilter.recordStatus;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 6, 2),
      child: Row(
        children: <Widget>[
          Flexible(
            child: _FilterDropdown<String>(
              leading: Icon(
                Icons.folder_outlined,
                size: 16,
                color: folderActive ? kAccent : kInkSoft,
              ),
              label: folderLabel,
              active: folderActive,
              onSelected: (String value) =>
                  state.setFolderFilter(value.isEmpty ? null : value),
              items: <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: '',
                  child: Text('全部分类'),
                ),
                for (final Folder folder in state.folders)
                  PopupMenuItem<String>(
                    value: folder.id,
                    child: Row(
                      children: <Widget>[
                        Icon(AppIcons.folder(folder.icon), size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            folder.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const PopupMenuItem<String>(
                  value: AppState.uncategorizedFilterId,
                  child: Text(kUncategorizedLabel),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _FilterDropdown<StatusFilter>(
              leading: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: status == null ? kInkSoft : AppIcons.statusColor(status),
                ),
              ),
              label: _statusLabel(state.statusFilter),
              active: state.statusFilter != StatusFilter.all,
              onSelected: state.setStatusFilter,
              items: StatusFilter.values
                  .map(
                    (StatusFilter filter) => PopupMenuItem<StatusFilter>(
                      value: filter,
                      child: Text(_statusLabel(filter)),
                    ),
                  )
                  .toList(),
            ),
          ),
          IconButton(
            tooltip: '管理文件夹',
            icon: const Icon(Icons.create_new_folder_outlined, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const FolderManagePage(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部筛选用的下拉胶囊：收起时只占一个标签宽度，点开再选。
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.leading,
    required this.label,
    required this.active,
    required this.items,
    required this.onSelected,
  });

  final Widget leading;
  final String label;
  final bool active;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: '',
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (BuildContext ctx) => items,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active ? kAccent.withValues(alpha: 0.10) : kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? kAccent : kLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            leading,
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: active ? kAccent : kInk,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.expand_more,
              size: 16,
              color: active ? kAccent : kInkSoft,
            ),
          ],
        ),
      ),
    );
  }
}
