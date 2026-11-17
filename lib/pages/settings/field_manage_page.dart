import 'package:flutter/material.dart';
import 'package:zlogbook/core/csv_columns.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/core/utils/ids.dart';
import 'package:zlogbook/core/utils/text_utils.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/field_def.dart';
import 'package:zlogbook/models/folder.dart';
import 'package:zlogbook/services/haptics.dart';
import 'package:zlogbook/state/app_scope.dart';
import 'package:zlogbook/state/app_state.dart';
import 'package:zlogbook/widgets/app_sheet.dart';
import 'package:zlogbook/widgets/common.dart';
import 'package:zlogbook/widgets/dialogs.dart';

class FieldManagePage extends StatelessWidget {
  const FieldManagePage({super.key});

  Future<void> _add(BuildContext context) async {
    final AppState state = AppScope.read(context);
    final FieldDef? created = await showAppSheet<FieldDef>(
      context,
      FieldEditorSheet(folders: state.folders),
    );
    if (created == null) {
      return;
    }
    await state.createFieldDef(created);
  }

  Future<void> _edit(BuildContext context, FieldDef def) async {
    final AppState state = AppScope.read(context);
    final FieldDef? updated = await showAppSheet<FieldDef>(
      context,
      FieldEditorSheet(folders: state.folders, existing: def),
    );
    if (updated == null) {
      return;
    }
    await state.updateFieldDef(updated);
  }

  Future<void> _delete(BuildContext context, FieldDef def) async {
    final AppState state = AppScope.read(context);
    final bool ok = await confirmAction(
      context,
      title: '删除字段「${def.label}」？',
      message: '字段会从编辑页消失。记录里已填的值不会删除，重新建同名字段可以再看到。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!ok) {
      return;
    }
    await state.deleteFieldDef(def.id);
    await Haptics.medium();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<FieldDef> defs = state.fieldDefs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义字段'),
        actions: <Widget>[
          IconButton(
            tooltip: '新建字段',
            icon: const Icon(Icons.add),
            onPressed: () => _add(context),
          ),
        ],
      ),
      body: defs.isEmpty
          ? EmptyState(
              icon: Icons.playlist_add,
              title: '还没有自定义字段',
              subtitle: '比如游戏段位、月租、注册渠道，\n建好后会出现在记录的编辑页',
              action: FilledButton(
                onPressed: () => _add(context),
                child: const Text('新建字段'),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 32),
              itemCount: defs.length,
              onReorder: (int oldIndex, int newIndex) {
                int target = newIndex;
                if (target > oldIndex) {
                  target -= 1;
                }
                final List<String> ids =
                    defs.map((FieldDef def) => def.id).toList();
                final String moved = ids.removeAt(oldIndex);
                ids.insert(target, moved);
                Haptics.selection();
                state.reorderFieldDefs(ids);
              },
              itemBuilder: (BuildContext ctx, int index) {
                final FieldDef def = defs[index];
                return Padding(
                  key: ValueKey<String>(def.id),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Card(
                    child: ListTile(
                      title: Text(
                        def.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        <String>[
                          def.kind.label,
                          if (def.kind.hasOptions)
                            '${def.options.length} 个选项',
                          if (def.scope == FieldScope.folder)
                            '仅「${state.folderName(def.scopeFolderId)}」'
                          else
                            '全部记录',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12, color: kInkSoft),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: '编辑',
                            icon: const Icon(Icons.edit_outlined, size: 19),
                            onPressed: () => _edit(context, def),
                          ),
                          IconButton(
                            tooltip: '删除',
                            icon: const Icon(Icons.delete_outline, size: 19),
                            onPressed: () => _delete(context, def),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.only(left: 2, right: 6),
                              child: Icon(
                                Icons.drag_handle,
                                size: 20,
                                color: kInkSoft,
                              ),
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

class FieldEditorSheet extends StatefulWidget {
  const FieldEditorSheet({super.key, required this.folders, this.existing});

  final List<Folder> folders;
  final FieldDef? existing;

  @override
  State<FieldEditorSheet> createState() => _FieldEditorSheetState();
}

class _FieldEditorSheetState extends State<FieldEditorSheet> {
  late final TextEditingController _label =
      TextEditingController(text: widget.existing?.label ?? '');
  late final TextEditingController _options = TextEditingController(
    text: widget.existing?.options.join(kTagSeparator) ?? '',
  );
  late FieldKind _kind = widget.existing?.kind ?? FieldKind.text;
  late FieldScope _scope = widget.existing?.scope ?? FieldScope.all;
  late String? _scopeFolderId = widget.existing?.scopeFolderId;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _options.dispose();
    super.dispose();
  }

  List<String> _parsedOptions() {
    return _options.text
        .split(RegExp(r'[|,，]'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  void _submit() {
    final String label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = '字段名不能为空');
      return;
    }
    if (CsvColumns.builtin.contains(label.toLowerCase())) {
      setState(() => _error = '「$label」是导入用的内置列名，换一个');
      return;
    }
    final List<String> options = _parsedOptions();
    if (_kind.hasOptions && options.isEmpty) {
      setState(() => _error = '单选/多选至少要有一个选项');
      return;
    }
    if (_scope == FieldScope.folder && _scopeFolderId == null) {
      setState(() => _error = '请选择生效的文件夹');
      return;
    }
    final DateTime now = DateTime.now();
    final String key = widget.existing?.key ??
        (label + now.microsecondsSinceEpoch.toString().substring(8));
    Navigator.of(context).pop(
      FieldDef(
        id: widget.existing?.id ?? newId(),
        key: key,
        label: label,
        kind: _kind,
        options: _kind.hasOptions ? options : const <String>[],
        scope: _scope,
        scopeFolderId: _scope == FieldScope.folder ? _scopeFolderId : null,
        sortOrder: widget.existing?.sortOrder ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isNew = widget.existing == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              isNew ? '新建字段' : '编辑字段',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _label,
              maxLength: 20,
              decoration: InputDecoration(
                hintText: '字段名，例如 游戏段位',
                counterText: '',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            const Text('类型', style: TextStyle(fontSize: 13, color: kInkSoft)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FieldKind.values.map((FieldKind kind) {
                return ChoiceChip(
                  label: Text(kind.label),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() {
                    _kind = kind;
                    _error = null;
                  }),
                );
              }).toList(),
            ),
            if (_kind.hasOptions) ...<Widget>[
              const SizedBox(height: 12),
              TextField(
                controller: _options,
                decoration: const InputDecoration(
                  hintText: '选项，用竖线分隔：王者|大师|青铜',
                  helperText: '导入时也可以自动生成',
                ),
                maxLines: 2,
                minLines: 1,
              ),
            ],
            const SizedBox(height: 12),
            const Text('作用范围', style: TextStyle(fontSize: 13, color: kInkSoft)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: FieldScope.values.map((FieldScope scope) {
                return ChoiceChip(
                  label: Text(scope == FieldScope.all ? '全部记录' : '指定文件夹'),
                  selected: _scope == scope,
                  onSelected: (_) => setState(() => _scope = scope),
                );
              }).toList(),
            ),
            if (_scope == FieldScope.folder) ...<Widget>[
              const SizedBox(height: 10),
              if (widget.folders.isEmpty)
                const Text(
                  '还没有文件夹，先去台账建一个',
                  style: TextStyle(fontSize: 12, color: kInkSoft),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.folders.map((Folder folder) {
                    return ChoiceChip(
                      label: Text(folder.name),
                      selected: _scopeFolderId == folder.id,
                      onSelected: (_) =>
                          setState(() => _scopeFolderId = folder.id),
                    );
                  }).toList(),
                ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(isNew ? '创建' : '保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
