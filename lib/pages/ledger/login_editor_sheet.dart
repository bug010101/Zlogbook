import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/core/utils/ids.dart';
import 'package:zlogbook/core/utils/text_utils.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/identity.dart';
import 'package:zlogbook/models/login_method.dart';
import 'package:zlogbook/widgets/app_icons.dart';
import 'package:zlogbook/widgets/app_sheet.dart';

class LoginEditResult {
  const LoginEditResult({required this.login, required this.storeInPool});

  final LoginMethod login;
  final bool storeInPool;
}

/// 加/改一条登录方式：类型化 + 可选引用身份池。
class LoginEditorSheet extends StatefulWidget {
  const LoginEditorSheet({
    super.key,
    this.initial,
    required this.defaultKind,
    required this.identities,
  });

  final LoginMethod? initial;
  final LoginKind defaultKind;
  final List<Identity> identities;

  @override
  State<LoginEditorSheet> createState() => _LoginEditorSheetState();
}

class _LoginEditorSheetState extends State<LoginEditorSheet> {
  late LoginKind _kind = widget.initial?.kind ?? widget.defaultKind;
  late final TextEditingController _account =
      TextEditingController(text: widget.initial?.account ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.initial?.note ?? '');
  late bool _isPrimary = widget.initial?.isPrimary ?? false;
  late bool _usable = widget.initial?.usable ?? true;
  String? _identityId = widget.initial?.identityId;
  bool _storeInPool = false;

  @override
  void dispose() {
    _account.dispose();
    _note.dispose();
    super.dispose();
  }

  Identity? get _linkedIdentity {
    final String? id = _identityId;
    if (id == null) {
      return null;
    }
    for (final Identity identity in widget.identities) {
      if (identity.id == id) {
        return identity;
      }
    }
    return null;
  }

  void _onAccountChanged(String value) {
    setState(() {
      if (_identityId != null) {
        final Identity? linked = _linkedIdentity;
        if (linked == null || linked.value != value.trim()) {
          _identityId = null;
        }
      }
      // 粘贴/输入自动识别类型
      final String text = value.trim();
      if (_kind == LoginKind.other || _kind == LoginKind.password) {
        if (looksLikePhone(text)) {
          _kind = LoginKind.phone;
        } else if (looksLikeEmail(text)) {
          _kind = LoginKind.email;
        }
      }
    });
  }

  Future<void> _pickFromPool() async {
    final List<Identity> candidates = widget.identities
        .where((Identity identity) =>
            _kind == LoginKind.other || identity.kind == _kind)
        .toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('身份池里还没有这个类型的账号')),
      );
      return;
    }
    final Identity? picked = await showChoiceSheet<Identity>(
      context,
      title: '从身份池选择',
      subtitle: '选中后，修改身份池会同步到这条记录',
      choices: candidates
          .map(
            (Identity identity) => SheetChoice<Identity>(
              value: identity,
              label: identity.kind == LoginKind.phone
                  ? maskPhone(identity.value)
                  : identity.value,
              icon: AppIcons.login(identity.kind),
              description: identity.label,
              selected: identity.id == _identityId,
            ),
          )
          .toList(),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _identityId = picked.id;
      _kind = picked.kind;
      _account.text = picked.value;
      _storeInPool = false;
    });
  }

  void _submit() {
    final String account = _account.text.trim();
    if (account.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      LoginEditResult(
        login: LoginMethod(
          id: widget.initial?.id ?? newId(),
          kind: _kind,
          account: account,
          identityId: _identityId,
          isPrimary: _isPrimary,
          usable: _usable,
          note: _note.text.trim(),
        ),
        storeInPool: _storeInPool && _identityId == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool linked = _identityId != null;
    final bool canSubmit = _account.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.initial == null ? '添加登录方式' : '编辑登录方式',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: LoginKind.values.map((LoginKind kind) {
                return ChoiceChip(
                  label: Text(kind.label),
                  avatar: Icon(AppIcons.login(kind), size: 15),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _account,
              onChanged: _onAccountChanged,
              keyboardType: _kind == LoginKind.phone
                  ? TextInputType.phone
                  : TextInputType.text,
              decoration: InputDecoration(
                hintText: '账号 / 号码',
                suffixIcon: linked
                    ? const Tooltip(
                        message: '引用自身份池',
                        child: Icon(Icons.link, size: 18, color: kAccent),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: _pickFromPool,
                  icon: const Icon(Icons.person_search_outlined, size: 18),
                  label: const Text('从身份池选择'),
                ),
                if (linked)
                  TextButton(
                    onPressed: () => setState(() => _identityId = null),
                    child: const Text('取消引用'),
                  ),
              ],
            ),
            if (!linked && _account.text.trim().isNotEmpty)
              CheckboxListTile(
                value: _storeInPool,
                onChanged: (bool? value) =>
                    setState(() => _storeInPool = value ?? false),
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  '同时存入身份池',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            SwitchListTile(
              value: _isPrimary,
              onChanged: (bool value) => setState(() => _isPrimary = value),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('主登录方式', style: TextStyle(fontSize: 13)),
            ),
            SwitchListTile(
              value: _usable,
              onChanged: (bool value) => setState(() => _usable = value),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('当前可用', style: TextStyle(fontSize: 13)),
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(hintText: '备注（可选）'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSubmit ? _submit : null,
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
