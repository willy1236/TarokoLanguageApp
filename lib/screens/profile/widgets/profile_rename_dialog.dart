// 個人頁欄位編輯用的單行輸入對話框。

import 'package:flutter/material.dart';

class ProfileRenameDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;
  const ProfileRenameDialog({
    super.key,
    required this.title,
    required this.label,
    required this.initialValue,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('儲存'),
        ),
      ],
    );
  }
}
