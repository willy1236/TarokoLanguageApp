// App 內所有回報／檢舉共用的底部面板：標題＋說明＋外框輸入框＋全寬送出鈕。
// 送出中按鈕停用；成功關面板並提示，失敗留在面板、打好的內容還在。
//
// 面板是米色淺底，App 全域主題卻是深色（ColorScheme.dark、近白字），所以面板
// 自帶淺色主題，不靠呼叫端包 forumTheme，各處看起來才會一樣。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../services/senior_mode_controller.dart';
import '../utils/utf16_length_limit.dart';
import 'app_toast.dart';

/// 回傳是否送出成功；直接關掉面板是 false。
/// 呼叫端要在面板關閉後才做的事（例如通話結束後回首頁）等這個 Future 即可。
///
/// [onSubmit] 收到去頭尾空白後的內容，丟例外代表失敗；[errorMessage] 把例外
/// 轉成提示文字，沒給就用後端的 error.message。
Future<bool> showReportSheet(
  BuildContext context, {
  required String title,
  required String description,
  required String hintText,
  required String submitLabel,
  required String successMessage,
  required int maxLength,
  required Future<void> Function(String reason) onSubmit,
  String Function(Object error)? errorMessage,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.creamLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) => Theme(
      data: _sheetTheme(sheetContext),
      child: _ReportSheet(
        title: title,
        description: description,
        hintText: hintText,
        submitLabel: submitLabel,
        successMessage: successMessage,
        maxLength: maxLength,
        onSubmit: onSubmit,
        errorMessage: errorMessage,
      ),
    ),
  );
  return sent ?? false;
}

/// 淺底用的配色：輸入框外框、輸入文字、提示、字數計數、游標都換成深色系。
ThemeData _sheetTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.creamLight,
      secondary: AppColors.moss,
      onSecondary: AppColors.creamLight,
      surface: AppColors.creamLight,
      onSurface: AppColors.ink,
      error: AppColors.danger,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.inkSoft,
      displayColor: AppColors.ink,
    ),
    hintColor: AppColors.fog,
    inputDecorationTheme: const InputDecorationTheme(
      hintStyle: TextStyle(color: AppColors.fog),
      counterStyle: TextStyle(
        color: AppColors.fog,
        fontSize: AppTypography.caption,
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: AppColors.mist,
      selectionHandleColor: AppColors.primary,
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  final String title;
  final String description;
  final String hintText;
  final String submitLabel;
  final String successMessage;
  final int maxLength;
  final Future<void> Function(String reason) onSubmit;
  final String Function(Object error)? errorMessage;

  const _ReportSheet({
    required this.title,
    required this.description,
    required this.hintText,
    required this.submitLabel,
    required this.successMessage,
    required this.maxLength,
    required this.onSubmit,
    required this.errorMessage,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // 面板可能在送出期間被外部關掉（例如通話頁整個被關），先取好 messenger。
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await widget.onSubmit(_controller.text.trim());
    } catch (e) {
      final toMessage = widget.errorMessage;
      messenger.showAppToast(
        toMessage != null
            ? toMessage(e)
            : apiErrorMessage(e, fallback: '送出失敗，請稍後再試'),
      );
      if (mounted) setState(() => _sending = false);
      return;
    }
    if (mounted) Navigator.pop(context, true);
    messenger.showAppToast(widget.successMessage);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _build(context, seniorModeController.enabled),
    );
  }

  Widget _build(BuildContext context, bool seniorMode) {
    final reason = _controller.text.trim();
    final valid = reason.isNotEmpty && reason.length <= widget.maxLength;
    final seniorTextStyle = seniorMode
        ? const TextStyle(
            fontSize: AppTypography.bodyLarge + AppTypography.seniorStep,
          )
        : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: AppTypography.serif(
              fontSize: AppTypography.size(
                AppTypography.subtitle,
                seniorMode: seniorMode,
              ),
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.description,
            style: TextStyle(
              fontSize: AppTypography.size(
                AppTypography.body,
                seniorMode: seniorMode,
              ),
              color: AppColors.fog,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLines: 4,
            inputFormatters: [
              Utf16LengthLimitingTextInputFormatter(widget.maxLength),
            ],
            buildCounter: utf16CounterBuilder(_controller, widget.maxLength),
            onChanged: (_) => setState(() {}),
            style: seniorTextStyle,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: seniorTextStyle,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: seniorMode ? 56 : null,
            child: FilledButton(
              onPressed: valid && !_sending ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.creamLight,
              ),
              child: Text(
                _sending ? '送出中…' : widget.submitLabel,
                style: seniorTextStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
