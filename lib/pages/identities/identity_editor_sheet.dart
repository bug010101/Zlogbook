import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/core/utils/ids.dart';
import 'package:zlogbook/core/utils/text_utils.dart';
import 'package:zlogbook/models/enums.dart';
import 'package:zlogbook/models/identity.dart';
import 'package:zlogbook/widgets/app_icons.dart';

/// 新建 / 编辑身份池条目。
class IdentityEditorSheet extends StatefulWidget {
  const IdentityEditorSheet({super.key, this.existing});

  final Identity? existing;

  @override
  State<IdentityEditorSheet> createState() => _IdentityEditorSheetState();
}

class _IdentityEditorSheetState extends State<IdentityEditorSheet> {
  late LoginKind _kind = widget.existing?.kind ?? LoginKind.phone;
  late final TextEditingController _value =
      TextEditingController(text: widget.existing?.value ?? '');
  late final TextEditingController _label =
      TextEditingController(text: widget.existing?.label ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  late IdentityStatus _status = widget.existing?.status ?? IdentityStatus.active;

  @override
  void dispose() {
    _value.dispose();
    _label.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _value.text.trim();
    if (value.isEmpty) {
      return;
    }
    final DateTime now = DateTime.now();
    Navigator.of(context).pop(
      Identity(
        id: widget.existing?.id ?? newId(),
        kind: _kind,
        value: value,
        label: nullIfBlank(_label.text),
        status: _status,
        notes: nullIfBlank(_notes.text),
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isNew = widget.existing == null;
    final bool canSubmit = _value.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              isNew ? '新建身份' : '编辑身份',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              '身份池里的号码可以被多条记录的登录方式引用，改一次全都同步。',
              style: TextStyle(fontSize: 12, color: kInkSoft, height: 1.4),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: identityKinds.map((LoginKind kind) {
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
              controller: _value,
              autofocus: isNew,
              onChanged: (_) => setState(() {}),
              keyboardType: _kind == LoginKind.phone
                  ? TextInputType.phone
                  : TextInputType.text,
              decoration: const InputDecoration(hintText: '号码 / 账号'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _label,
              maxLength: 20,
              decoration: const InputDecoration(
                hintText: '归属说明：主号 / 小号 / 家人',
                counterText: '',
              ),
            ),
            const SizedBox(height: 6),
            const Text('状态', style: TextStyle(fontSize: 13, color: kInkSoft)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: IdentityStatus.values.map((IdentityStatus status) {
                return ChoiceChip(
                  label: Text(status.label),
                  selected: _status == status,
                  avatar: Icon(
                    Icons.circle,
                    size: 10,
                    color: AppIcons.identityStatusColor(status),
                  ),
                  onSelected: (_) => setState(() => _status = status),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(hintText: '备注（可选）'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSubmit ? _submit : null,
                child: Text(isNew ? '添加' : '保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
