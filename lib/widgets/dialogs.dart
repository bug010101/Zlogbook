import 'package:flutter/material.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/widgets/app_sheet.dart';

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool destructive = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      content: message == null
          ? null
          : Text(
              message,
              style: const TextStyle(fontSize: 14, height: 1.5, color: kInkSoft),
            ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: const Color(0xFFA85A50))
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? initial,
  String? hint,
  String? helper,
  String confirmLabel = '保存',
  int maxLength = 40,
  TextInputType keyboardType = TextInputType.text,
}) {
  return showAppSheet<String>(
    context,
    _PromptSheet(
      title: title,
      initial: initial,
      hint: hint,
      helper: helper,
      confirmLabel: confirmLabel,
      maxLength: maxLength,
      keyboardType: keyboardType,
    ),
    tall: false,
  );
}

class _PromptSheet extends StatefulWidget {
  const _PromptSheet({
    required this.title,
    required this.initial,
    required this.hint,
    required this.helper,
    required this.confirmLabel,
    required this.maxLength,
    required this.keyboardType,
  });

  final String title;
  final String? initial;
  final String? hint;
  final String? helper;
  final String confirmLabel;
  final int maxLength;
  final TextInputType keyboardType;

  @override
  State<_PromptSheet> createState() => _PromptSheetState();
}

class _PromptSheetState extends State<_PromptSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.helper,
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
        ],
      ),
    );
  }
}

void showToast(
  BuildContext context,
  String message, {
  int seconds = 2,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message), duration: Duration(seconds: seconds)),
  );
}

/// 删除后五秒可撤销。
void showUndoToast(
  BuildContext context,
  String message, {
  required VoidCallback onUndo,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: '撤销',
        textColor: const Color(0xFF8FD3B5),
        onPressed: onUndo,
      ),
    ),
  );
}
