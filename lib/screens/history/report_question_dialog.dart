// 測驗紀錄詳解頁「回報問題」輸入框（issue #20）。
import 'package:flutter/material.dart';
import '../../shared/utils/utf16_length_limit.dart';

class ReportQuestionDialog extends StatefulWidget {
  const ReportQuestionDialog({super.key});

  @override
  State<ReportQuestionDialog> createState() => _ReportQuestionDialogState();
}

class _ReportQuestionDialogState extends State<ReportQuestionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('回報問題'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        inputFormatters: const [Utf16LengthLimitingTextInputFormatter(1000)],
        buildCounter: utf16CounterBuilder(_controller, 1000),
        decoration: const InputDecoration(
          labelText: '請說明題目或答案的問題',
          alignLabelWithHint: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('送出'),
        ),
      ],
    );
  }
}
