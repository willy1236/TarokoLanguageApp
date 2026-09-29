// 個人頁欄位編輯用的單行輸入對話框。

import 'package:flutter/material.dart';

import '../../../shared/utils/utf16_length_limit.dart';

class ProfileRenameDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;

  /// 後端的長度上限（UTF-16 單位），見 ProfileFieldLimits。
  final int maxLength;

  /// 給了就由對話框自己送出：回傳 null 代表成功並關閉，回傳字串則留在對話框、
  /// 顯示在欄位下方。沒給時維持把輸入內容 pop 回呼叫端。
  final Future<String?> Function(String value)? onSave;

  const ProfileRenameDialog({
    super.key,
    required this.title,
    required this.label,
    required this.initialValue,
    required this.maxLength,
    this.onSave,
  });

  @override
  State<ProfileRenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<ProfileRenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (!withinUtf16Limit(
      context,
      text,
      widget.maxLength,
      label: widget.label,
    )) {
      return;
    }
    final onSave = widget.onSave;
    if (onSave == null) {
      Navigator.pop(context, text);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await onSave(text);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, text);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
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
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: _error,
          errorMaxLines: 3,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('儲存'),
        ),
      ],
    );
  }
}
