import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/models/folder.dart';
import 'package:zlogbook/models/record.dart';
import 'package:zlogbook/state/app_scope.dart';
import 'package:zlogbook/state/app_state.dart';
import 'package:zlogbook/widgets/app_icons.dart';
import 'package:zlogbook/widgets/app_sheet.dart';
import 'package:zlogbook/widgets/common.dart';
import 'package:zlogbook/widgets/dialogs.dart';
import 'package:zlogbook/services/haptics.dart';

class FolderDraft {
  const FolderDraft({
    required this.name,
    required this.icon,
    required this.color,
  });

  final String name;
  final String icon;
  final String color;
}

class FolderManagePage extends StatelessWidget {
  const FolderManagePage({super.key});

  Future<void> _add(BuildContext context) async {
    final FolderDraft? draft = await showAppSheet<FolderDraft>(
      context,
      const FolderEditorSheet(),
    );
    if (draft == null) {
      return;
    }
    await AppScope.read(context).createFolder(
      name: draft.name,
      icon: draft.icon,
      color: draft.color,
    );
  }

  Future<void> _edit(BuildContext context, Folder folder) async {
    final FolderDraft? draft = await showAppSheet<FolderDraft>(
      context,
      FolderEditorSheet(existing: folder),
    );
    if (draft == null) {
      return;
    }
    await AppScope.read(context).updateFolder(
      folder.copyWith(name: draft.name, icon: draft.icon, color: draft.color),
    );
  }

  Future<void> _delete(BuildContext context, Folder folder) async {
    final AppState state = AppScope.read(context);
    final bool ok = await confirmAction(
      context,
      title: '删除文件夹「${folder.name}」？',
      message: '里面的记录不会被删除，会变为未分类。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) {
      return;
    }
    await state.deleteFolder(folder.id);
    await Haptics.medium();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<Folder> folders = state.folders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件夹'),
        actions: <Widget>[
          IconButton(
            tooltip: '新建文件夹',
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: folders.isEmpty
          ? EmptyState(
              icon: Icons.folder_outlined,
              title: '还没有文件夹',
              subtitle: '文件夹用来给记录分类，只有一层，拖动可排序',
              action: FilledButton(
                onPressed: () => _add(context),
                child: const Text('新建文件夹'),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              itemCount: folders.length,
              onReorder: (int oldIndex, int newIndex) {
                int target = newIndex;
                if (target > oldIndex) {
                  target -= 1;
                }
                final List<String> ids =
                    folders.map((Folder f) => f.id).toList();
                final String moved = ids.removeAt(oldIndex);
                ids.insert(target, moved);
                Haptics.selection();
                state.reorderFolders(ids);
              },
              itemBuilder: (BuildContext ctx, int index) {
                final Folder folder = folders[index];
                final int count = state.records
                    .where((AssetRecord r) => r.folderId == folder.id)
                    .length;
                return Padding(
                  key: ValueKey<String>(folder.id),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Card(
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppIcons.accent(folder.color)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          AppIcons.folder(folder.icon),
                          size: 19,
                          color: AppIcons.accent(folder.color),
                        ),
                      ),
                      title: Text(
                        folder.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '$count 条记录',
                        style: const TextStyle(fontSize: 12, color: kInkSoft),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: '编辑',
                            icon: const Icon(Icons.edit_outlined, size: 19),
                            onPressed: () => _edit(context, folder),
                          ),
                          IconButton(
                            tooltip: '删除',
                            icon: const Icon(Icons.delete_outline, size: 19),
                            onPressed: () => _delete(context, folder),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 2, right: 6),
                              child: Icon(Icons.drag_handle, size: 20, color: kInkSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class FolderEditorSheet extends StatefulWidget {
  const FolderEditorSheet({super.key, this.existing});

  final Folder? existing;

  @override
  State<FolderEditorSheet> createState() => _FolderEditorSheetState();
}

class _FolderEditorSheetState extends State<FolderEditorSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late String _icon = widget.existing?.icon ?? 'folder';
  late String _color = widget.existing?.color ?? 'slate';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isNew = widget.existing == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isNew ? '新建文件夹' : '编辑文件夹',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            autofocus: isNew,
            maxLength: 20,
            decoration: const InputDecoration(
              hintText: '文件夹名称',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          const Text('图标', style: TextStyle(fontSize: 13, color: kInkSoft)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppIcons.folderIconNames.map((String name) {
              final bool selected = name == _icon;
              return InkWell(
                onTap: () {
                  setState(() => _icon = name);
                  Haptics.selection();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected
                        ? kAccent.withValues(alpha: 0.12)
                        : kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? kAccent : kLine,
                    ),
                  ),
                  child: Icon(
                    AppIcons.folder(name),
                    size: 19,
                    color: selected ? kAccent : kInkSoft,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('颜色', style: TextStyle(fontSize: 13, color: kInkSoft)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: AppIcons.accentColorNames.map((String name) {
              final bool selected = name == _color;
              return InkWell(
                onTap: () {
                  setState(() => _color = name);
                  Haptics.selection();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppIcons.accent(name),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? kInk : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final String name = _name.text.trim();
                if (name.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(
                  FolderDraft(name: name, icon: _icon, color: _color),
                );
              },
              child: Text(isNew ? '创建' : '保存'),
            ),
          ),
        ],
      ),
    );
  }
}
