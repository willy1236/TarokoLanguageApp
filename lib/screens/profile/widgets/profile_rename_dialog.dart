// 個人頁欄位編輯用的單行輸入對話框。

import 'package:flutter/material.dart';

import '../../../shared/utils/utf16_length_limit.dart';

class ProfileRenameDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;

  /// 後端的長度上限（UTF-16 單位），見 ProfileFieldLimits。
  final int maxLength;

  const ProfileRenameDialog({
    super.key,
    required this.title,
    required this.label,
    required this.initialValue,
    required this.maxLength,
  });

  @override
  State<ProfileRenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<ProfileRenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (!withinUtf16Limit(
      context,
      text,
      widget.maxLength,
      label: widget.label,
    )) {
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        inputFormatters: [
          Utf16LengthLimitingTextInputFormatter(widget.maxLength),
        ],
        buildCounter: utf16CounterBuilder(_controller, widget.maxLength),
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _save, child: const Text('儲存')),
      ],
    );
  }
}
