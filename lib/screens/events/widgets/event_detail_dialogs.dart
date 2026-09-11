// 活動詳情頁的輸入對話框：報名聯絡 email、取消活動理由。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

/// 「取消活動」理由輸入對話框。獨立成 StatefulWidget 讓
/// [TextEditingController] 隨這個 dialog 元件自身的生命週期建立/釋放，
/// 避免在 `showDialog` 的 Future resolve 當下就手動 dispose——
/// 此時 dialog 的關閉動畫可能還沒跑完，仍持有該 controller 的 TextField
/// 尚未真正 unmount，手動提早 dispose 會丟出
/// "A TextEditingController was used after being disposed." 例外。
/// 報名前要求聯絡 email（後端必填，供主辦聯繫）。[initialEmail] 為帳號 email 預填值。
class JoinEmailDialog extends StatefulWidget {
  final String? initialEmail;

  const JoinEmailDialog({super.key, this.initialEmail});

  @override
  State<JoinEmailDialog> createState() => _JoinEmailDialogState();
}

class _JoinEmailDialogState extends State<JoinEmailDialog> {
  late final _controller = TextEditingController(text: widget.initialEmail);
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+$');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _controller.text.trim();
    if (email.isEmpty || !_emailPattern.hasMatch(email) || email.length > 254) {
      setState(() => _error = '請輸入有效的 Email');
      return;
    }
    Navigator.pop(context, email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.creamLight,
      title: Text(
        '填寫聯絡 Email',
        style: GoogleFonts.notoSerifTc(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '報名需提供聯絡 Email，供主辦聯繫使用，可與帳號 Email 不同。',
            style: TextStyle(
              fontSize: AppTypography.body,
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            style: const TextStyle(fontSize: AppTypography.body, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'name@example.com',
              hintStyle: TextStyle(color: AppColors.fog),
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: AppColors.inkSoft)),
        ),
        TextButton(onPressed: _submit, child: const Text('確認報名')),
      ],
    );
  }
}

class CancelReasonDialog extends StatefulWidget {
  const CancelReasonDialog({super.key});

  @override
  State<CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<CancelReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.creamLight,
      title: Text(
        '取消活動',
        style: GoogleFonts.notoSerifTc(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '請填寫取消理由，會一併推播通知所有參加者。',
            style: TextStyle(
              fontSize: AppTypography.body,
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: 500,
            autofocus: true,
            style: const TextStyle(fontSize: AppTypography.body, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: '例如：因天候因素順延…',
              hintStyle: TextStyle(color: AppColors.fog),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('返回', style: TextStyle(color: AppColors.inkSoft)),
        ),
        TextButton(
          onPressed: () {
            final r = _controller.text.trim();
            if (r.isEmpty) return;
            Navigator.pop(context, r);
          },
          child: const Text(
            '確認取消活動',
            style: TextStyle(color: AppColors.dangerDark),
          ),
        ),
      ],
    );
  }
}
