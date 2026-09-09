// 輸入好友碼加好友。成功送出後 pop(true) 讓上一頁刷新。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../services/friend_service.dart';
import '../../services/senior_mode_controller.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = '請輸入好友碼');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final status = await FriendService.sendRequest(friendCode: code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status == 'accepted' ? '你們已成為好友！' : '已送出好友邀請')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.isAlreadyFriends
            ? '你們已經是好友'
            : e.isRequestAlreadySent
            ? '已送出邀請，等待對方回覆'
            : e.isBlocked
            ? '因封鎖關係，無法送出邀請'
            : e.statusCode == 404
            ? '找不到此好友碼對應的使用者'
            : e.message;
      });
    } catch (e, st) {
      debugPrint('Failed to send friend request: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '送出失敗，請稍後再試';
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) => _buildScaffold(seniorModeController.enabled),
  );

  Widget _buildScaffold(bool seniorMode) => Scaffold(
    backgroundColor: AppColors.creamLight,
    body: SafeArea(
      child: Column(
        children: [
          _topBar(seniorMode),
          Expanded(child: _buildBody(seniorMode)),
        ],
      ),
    ),
  );

  Widget _topBar(bool seniorMode) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
        ),
        Expanded(
          child: Text(
            '加好友',
            style: AppTypography.titleStyle(seniorMode: seniorMode, color: AppColors.ink),
          ),
        ),
      ],
    ),
  );

  Widget _buildBody(bool seniorMode) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '輸入對方的好友碼',
          style: AppTypography.bodyLargeStyle(seniorMode: seniorMode, color: AppColors.fog),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          style: AppTypography.headlineStyle(seniorMode: seniorMode, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: '例如 A7C9K2XZ',
            errorText: _error,
            filled: true,
            fillColor: AppColors.cream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.creamDeep),
            ),
          ),
          onSubmitted: (_) => _submitting ? null : _submit(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('送出邀請', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    ),
  );
}
