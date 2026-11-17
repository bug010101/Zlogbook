import 'package:flutter/material.dart';
import 'package:zlogbook/core/app_info.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/core/utils/dates.dart';
import 'package:zlogbook/core/utils/ids.dart';
import 'package:zlogbook/core/utils/text_utils.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/field_def.dart';
import 'package:zlogbook/models/folder.dart';
import 'package:zlogbook/models/identity.dart';
import 'package:zlogbook/models/login_method.dart';
import 'package:zlogbook/models/record.dart';
import 'package:zlogbook/pages/ledger/login_editor_sheet.dart';
import 'package:zlogbook/services/haptics.dart';
import 'package:zlogbook/state/app_scope.dart';
import 'package:zlogbook/state/app_state.dart';
import 'package:zlogbook/widgets/app_icons.dart';
import 'package:zlogbook/widgets/app_sheet.dart';
import 'package:zlogbook/widgets/common.dart';
import 'package:zlogbook/widgets/dialogs.dart';

class RecordEditPage extends StatefulWidget {
  const RecordEditPage({super.key, this.record, this.initialFolderId});

  final AssetRecord? record;
  final String? initialFolderId;

  @override
  State<RecordEditPage> createState() => _RecordEditPageState();
}

class _RecordEditPageState extends State<RecordEditPage> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _valueText;
  late final TextEditingController _notes;
  final TextEditingController _tagInput = TextEditingController();

  late String? _folderId;
  late RecordStatus _status;
  late int _importance;
  late DateTime? _expiresAt;
  late List<String> _tags;
  late List<LoginMethod> _logins;
  late Map<String, Object?> _extra;

  bool _dirty = false;
  bool _saving = false;

  AppState get _state => AppScope.read(context);

  @override
  void initState() {
    super.initState();
    final AssetRecord? record = widget.record;
    _name = TextEditingController(text: record?.name ?? '');
    _url = TextEditingController(text: record?.url ?? '');
    _valueText = TextEditingController(
      text: record?.value == null ? '' : formatAmount(record!.value),
    );
    _notes = TextEditingController(text: record?.notes ?? '');
    _folderId = record?.folderId ?? widget.initialFolderId;
    _status = record?.status ?? RecordStatus.active;
    _importance = record?.importance ?? 3;
    _expiresAt = record?.expiresAt;
    _tags = List<String>.from(record?.tags ?? const <String>[]);
    _logins = List<LoginMethod>.from(record?.logins ?? const <LoginMethod>[]);
    _extra = Map<String, Object?>.from(record?.extra ?? const <String, Object?>{});
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _valueText.dispose();
    _notes.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _touch() {
    setState(() => _dirty = true);
  }

  Future<void> _pickExpiry() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 30),
      helpText: '选择到期日',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _expiresAt = picked;
      _dirty = true;
    });
  }

  Future<void> _addLogin() async {
    final LoginEditResult? result = await showAppSheet<LoginEditResult>(
      context,
      LoginEditorSheet(
        defaultKind: _state.lastLoginKind,
        identities: _state.identities,
      ),
    );
    if (result == null) {
      return;
    }
    await _state.setLastLoginKind(result.login.kind);
    await _applyLogin(result, null);
  }

  Future<void> _editLogin(int index) async {
    final LoginEditResult? result = await showAppSheet<LoginEditResult>(
      context,
      LoginEditorSheet(
        initial: _logins[index],
        defaultKind: _logins[index].kind,
        identities: _state.identities,
      ),
    );
    if (result == null) {
      return;
    }
    await _applyLogin(result, index);
  }

  Future<void> _applyLogin(LoginEditResult result, int? index) async {
    setState(() {
      if (index == null) {
        _logins.add(result.login);
      } else {
        _logins[index] = result.login;
      }
      if (result.login.isPrimary) {
        for (int i = 0; i < _logins.length; i++) {
          if (_logins[i].id != result.login.id && _logins[i].isPrimary) {
            _logins[i] = _logins[i].copyWith(isPrimary: false);
          }
        }
      }
      _dirty = true;
    });

    if (!result.storeInPool || !result.login.kind.isIdentityKind) {
      return;
    }
    Identity? found =
        _state.identityByValue(result.login.kind, result.login.account);
    if (found == null) {
      final DateTime now = DateTime.now();
      found = await _state.saveIdentity(
        Identity(
          id: newId(),
          kind: result.login.kind,
          value: result.login.account,
          status: IdentityStatus.active,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    final String identityId = found.id;
    final int position = _logins.indexWhere(
      (LoginMethod login) => login.id == result.login.id,
    );
    if (position >= 0 && mounted) {
      setState(() {
        _logins[position] = _logins[position].copyWith(identityId: identityId);
      });
    }
  }

  void _addTag() {
    final String tag = _tagInput.text.trim();
    if (tag.isEmpty) {
      return;
    }
    if (!_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _dirty = true;
      });
    }
    _tagInput.clear();
  }

  Map<String, Object?> _cleanExtra() {
    final Map<String, Object?> cleaned = <String, Object?>{};
    _extra.forEach((String key, Object? value) {
      if (value == null) {
        return;
      }
      if (value is String && value.trim().isEmpty) {
        return;
      }
      if (value is List && value.isEmpty) {
        return;
      }
      cleaned[key] = value;
    });
    return cleaned;
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);
    final DateTime now = DateTime.now();
    final AssetRecord record = AssetRecord(
      id: widget.record?.id ?? newId(),
      name: name,
      folderId: _folderId,
      status: _status,
      importance: _importance,
      notes: nullIfBlank(_notes.text),
      url: nullIfBlank(_url.text),
      value: parseAmount(_valueText.text),
      expiresAt: _expiresAt,
      tags: _tags,
      logins: _logins,
      extra: _cleanExtra(),
      createdAt: widget.record?.createdAt ?? now,
      updatedAt: now,
    );
    await _state.saveRecord(record);
    await Haptics.light();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _handleBack() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final bool discard = await confirmAction(
      context,
      title: '放弃修改？',
      message: '返回后本次编辑内容不会保存。',
      confirmLabel: '放弃',
      destructive: true,
    );
    if (discard && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<FieldDef> fields = state.fieldDefsFor(_folderId);
    final bool canSave = _name.text.trim().isNotEmpty;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        final bool discard = await confirmAction(
          context,
          title: '放弃修改？',
          message: '返回后本次编辑内容不会保存。',
          confirmLabel: '放弃',
          destructive: true,
        );
        if (discard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.record == null ? '新建记录' : '编辑记录'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleBack,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            SectionCard(
              children: <Widget>[
                TextField(
                  controller: _name,
                  autofocus: widget.record == null,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _touch(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: '名称（必填）',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 6),
                const Divider(),
                const SizedBox(height: 12),
                _label('文件夹'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text(kUncategorizedLabel),
                      selected: _folderId == null,
                      onSelected: (_) {
                        setState(() {
                          _folderId = null;
                          _dirty = true;
                        });
                      },
                    ),
                    ...state.folders.map(
                      (Folder folder) => ChoiceChip(
                        label: Text(folder.name),
                        avatar: Icon(
                          AppIcons.folder(folder.icon),
                          size: 15,
                        ),
                        selected: _folderId == folder.id,
                        onSelected: (_) {
                          setState(() {
                            _folderId = folder.id;
                            _dirty = true;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _label('状态'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: RecordStatus.values.map((RecordStatus status) {
                    return ChoiceChip(
                      label: Text(status.label),
                      selected: _status == status,
                      avatar: Icon(
                        Icons.circle,
                        size: 10,
                        color: AppIcons.statusColor(status),
                      ),
                      onSelected: (_) {
                        setState(() {
                          _status = status;
                          _dirty = true;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _label('重要度'),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    for (int i = 1; i <= 5; i++)
                      InkWell(
                        onTap: () {
                          setState(() {
                            _importance = i;
                            _dirty = true;
                          });
                          Haptics.selection();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            i <= _importance
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 24,
                            color: i <= _importance
                                ? const Color(0xFFB5842E)
                                : kLine,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      importanceLabel(_importance),
                      style: const TextStyle(fontSize: 12, color: kInkSoft),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '登录方式',
              trailing: TextButton.icon(
                onPressed: _addLogin,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('添加'),
              ),
              children: <Widget>[
                if (_logins.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '还没有登录方式，点右上角添加。',
                      style: TextStyle(fontSize: 13, color: kInkSoft),
                    ),
                  ),
                for (int i = 0; i < _logins.length; i++)
                  _loginRow(i, state),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '标签',
              children: <Widget>[
                if (_tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _tags
                        .map(
                          (String tag) => InputChip(
                            label: Text(tag),
                            onDeleted: () {
                              setState(() {
                                _tags.remove(tag);
                                _dirty = true;
                              });
                            },
                            deleteIconColor: kInkSoft,
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tagInput,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addTag(),
                  decoration: InputDecoration(
                    hintText: '输入后回车添加',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: _addTag,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: '详情',
              children: <Widget>[
                TextField(
                  controller: _url,
                  onChanged: (_) => _touch(),
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(hintText: '网址或包名（可选）'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _valueText,
                  onChanged: (_) => _touch(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(hintText: '估值（可选，不带货币符号）'),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickExpiry,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      suffixIcon: Icon(Icons.event_outlined, size: 18),
                    ),
                    child: Text(
                      _expiresAt == null ? '到期日（可选）' : formatDate(_expiresAt!),
                      style: TextStyle(
                        fontSize: 14,
                        color: _expiresAt == null ? kInkSoft : kInk,
                      ),
                    ),
                  ),
                ),
                if (_expiresAt != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _expiresAt = null;
                          _dirty = true;
                        });
                      },
                      child: const Text('清除到期日'),
                    ),
                  ),
              ],
            ),
            if (fields.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              SectionCard(
                title: '自定义字段',
                children: <Widget>[
                  for (int i = 0; i < fields.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: 12),
                    _CustomFieldEditor(
                      def: fields[i],
                      value: _extra[fields[i].key],
                      onChanged: (Object? value) {
                        setState(() {
                          if (value == null) {
                            _extra.remove(fields[i].key);
                          } else {
                            _extra[fields[i].key] = value;
                          }
                          _dirty = true;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 12),
            SectionCard(
              title: '备注',
              children: <Widget>[
                TextField(
                  controller: _notes,
                  onChanged: (_) => _touch(),
                  maxLines: 4,
                  minLines: 3,
                  decoration: const InputDecoration(hintText: '随便写点什么'),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: canSave && !_saving ? _save : null,
                child: Text(_saving ? '保存中…' : '保存'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontSize: 13, color: kInkSoft));

  Widget _loginRow(int index, AppState state) {
    final LoginMethod login = _logins[index];
    final String account = state.identityById(login.identityId)?.value ?? login.account;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Icon(AppIcons.login(login.kind), size: 18, color: kInkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        account,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    if (login.isPrimary) ...<Widget>[
                      const SizedBox(width: 6),
                      const Icon(Icons.star_rounded,
                          size: 14, color: Color(0xFFB5842E)),
                    ],
                  ],
                ),
                Text(
                  '${login.kind.label}${login.identityId != null ? ' · 引用身份池' : ''}${login.usable ? '' : ' · 不可用'}',
                  style: const TextStyle(fontSize: 11, color: kInkSoft),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '编辑',
            icon: const Icon(Icons.edit_outlined, size: 17),
            onPressed: () => _editLogin(index),
          ),
          IconButton(
            tooltip: '移除',
            icon: const Icon(Icons.close, size: 17),
            onPressed: () {
              setState(() {
                _logins.removeAt(index);
                _dirty = true;
              });
            },
          ),
        ],
      ),
    );
  }
}

class _CustomFieldEditor extends StatelessWidget {
  const _CustomFieldEditor({
    required this.def,
    required this.value,
    required this.onChanged,
  });

  final FieldDef def;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  static String _textOf(Object? raw) {
    if (raw == null) {
      return '';
    }
    if (raw is num) {
      return formatAmount(raw.toDouble());
    }
    if (raw is List) {
      return raw.map((Object? item) => '$item').join(kTagSeparator);
    }
    return '$raw';
  }

  static DateTime? _dateOf(Object? raw) {
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      return parseStrictDate(raw);
    }
    return null;
  }

  static List<String> _listOf(Object? raw) {
    if (raw is List) {
      return raw.map((Object? item) => '$item').toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(kTagSeparator)
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  @override
  Widget build(BuildContext context) {
    switch (def.kind) {
      case FieldKind.text:
        return TextFormField(
          key: ValueKey<String>('${def.id}-text'),
          initialValue: _textOf(value),
          onChanged: (String text) =>
              onChanged(text.trim().isEmpty ? null : text),
          decoration: InputDecoration(labelText: def.label),
        );

      case FieldKind.number:
        return TextFormField(
          key: ValueKey<String>('${def.id}-number'),
          initialValue: _textOf(value),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (String text) => onChanged(parseAmount(text)),
          decoration: InputDecoration(labelText: def.label),
        );

      case FieldKind.date:
        final DateTime? date = _dateOf(value);
        return InkWell(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(DateTime.now().year - 20),
              lastDate: DateTime(DateTime.now().year + 40),
              helpText: def.label,
            );
            if (picked != null) {
              onChanged(picked);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: def.label,
              suffixIcon: const Icon(Icons.event_outlined, size: 18),
            ),
            child: Text(
              date == null ? '未设置' : formatDate(date),
              style: TextStyle(
                fontSize: 14,
                color: date == null ? kInkSoft : kInk,
              ),
            ),
          ),
        );

      case FieldKind.select:
        final String current = value == null ? '' : '$value';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              def.label,
              style: const TextStyle(fontSize: 13, color: kInkSoft),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: def.options.map((String option) {
                final bool selected = current == option;
                return ChoiceChip(
                  label: Text(option),
                  selected: selected,
                  onSelected: (_) => onChanged(selected ? null : option),
                );
              }).toList(),
            ),
          ],
        );

      case FieldKind.multiselect:
        final List<String> current = _listOf(value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              def.label,
              style: const TextStyle(fontSize: 13, color: kInkSoft),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: def.options.map((String option) {
                final bool selected = current.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: selected,
                  onSelected: (bool picked) {
                    final List<String> next = List<String>.from(current);
                    if (picked) {
                      next.add(option);
                    } else {
                      next.remove(option);
                    }
                    onChanged(next.isEmpty ? null : next);
                  },
                );
              }).toList(),
            ),
          ],
        );
    }
  }
}
