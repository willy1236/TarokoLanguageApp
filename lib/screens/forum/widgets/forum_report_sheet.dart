// 檢舉貼文或留言。同一人對同一目標重複檢舉，後端回 201 不視為錯誤
// （規格 §10），因此成功訊息一律是「已收到檢舉」。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../services/forum_service.dart';

Future<void> showForumReportSheet(
  BuildContext context, {
  required String targetType,
  required int targetId,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.creamLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _ReportSheet(targetType: targetType, targetId: targetId),
    );

class _ReportSheet extends StatefulWidget {
  final String targetType;
  final int targetId;

  const _ReportSheet({required this.targetType, required this.targetId});

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
    setState(() => _sending = true);
    try {
      await ForumService.report(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _controller.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('已收到檢舉')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = _controller.text.trim();
    final valid = reason.isNotEmpty && reason.length <= ForumService.reasonMax;
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
            '檢舉',
            style: GoogleFonts.notoSerifTc(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '請說明檢舉的原因，管理員會再確認。',
            style: TextStyle(fontSize: 13, color: AppColors.fog),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: ForumService.reasonMax,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '例如：廣告、人身攻擊、不實資訊',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: valid && !_sending ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.creamLight,
              ),
              child: Text(_sending ? '送出中…' : '送出檢舉'),
            ),
          ),
        ],
      ),
    );
  }
}
