// 管理員下架、重設個人檔案等「必填理由」操作的共用流程：
// 先填理由（預設 1～500 字，UTF-16 長度檢查沿用 withinUtf16Limit），再二次確認。
// 申訴回覆也走這裡，只是欄位名稱換成「給申訴人的回覆」。
// 任一步取消都回 null，呼叫端只要在拿到結果時才送出請求。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/utils/utf16_length_limit.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'admin_profile_field_picker.dart';

class AdminReasonInput {
  final String reason;

  /// 勾選的個人檔案欄位；沒有 [promptAdminReason] 的 `profileFields` 時為空。
  final Set<String> fields;

  const AdminReasonInput({required this.reason, this.fields = const {}});
}

/// 顯示「填理由」對話框，再接一次確認。[confirmMessage] 是確認框的說明。
Future<AdminReasonInput?> promptAdminReason(
  BuildContext context, {
  required String title,
  required String description,
  required String confirmMessage,
  required String confirmText,
  int maxLength = 500,
  bool profileFields = false,

  /// false 時理由改為選填（例如解鎖帳號的備註），可以留空直接下一步。
  bool required = true,

  /// 輸入框的欄位名稱；不給時必填為「理由」、選填為「備註」。
  String? label,
}) async {
  final input = await showDialog<AdminReasonInput>(
    context: context,
    builder: (_) => _ReasonDialog(
      title: title,
      description: description,
      maxLength: maxLength,
      profileFields: profileFields,
      required: required,
      label: label ?? (required ? '理由' : '備註'),
    ),
  );
  if (input == null || !context.mounted) return null;
  final confirmed = await showConfirmDialog(
    context,
    title: title,
    message: confirmMessage,
    confirmText: confirmText,
  );
  return confirmed ? input : null;
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String description;
  final int maxLength;
  final bool profileFields;
  final bool required;
  final String label;

  const _ReasonDialog({
    required this.title,
    required this.description,
    required this.maxLength,
    required this.profileFields,
    required this.required,
    required this.label,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  late final Set<String> _fields = AdminProfileFieldPicker.allFields;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      (!widget.required || _controller.text.trim().isNotEmpty) &&
      (!widget.profileFields || _fields.isNotEmpty);

  void _submit() {
    final reason = _controller.text.trim();
    if (!withinUtf16Limit(
      context,
      reason,
      widget.maxLength,
      label: widget.label,
    )) {
      return;
    }
    Navigator.pop(
      context,
      AdminReasonInput(
        reason: reason,
        fields: widget.profileFields ? {..._fields} : const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.creamLight,
    title: Text(
      widget.title,
      style: AppTypography.serif(
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.description,
            style: AppTypography.bodyLargeStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          if (widget.profileFields) ...[
            AdminProfileFieldPicker(
              selected: _fields,
              onChanged: (fields) => setState(() {
                _fields
                  ..clear()
                  ..addAll(fields);
              }),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _controller,
            maxLines: 3,
            autofocus: true,
            inputFormatters: [
              Utf16LengthLimitingTextInputFormatter(widget.maxLength),
            ],
            buildCounter: utf16CounterBuilder(_controller, widget.maxLength),
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              fontSize: AppTypography.body,
              color: AppColors.ink,
            ),
            decoration: InputDecoration(
              labelText: '${widget.label}（${widget.required ? '必填' : '選填'}）',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('返回', style: TextStyle(color: AppColors.inkSoft)),
      ),
      TextButton(
        onPressed: _canSubmit ? _submit : null,
        child: const Text('下一步'),
      ),
    ],
  );
}
