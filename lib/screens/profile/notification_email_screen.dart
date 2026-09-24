// 通知信箱設定與 6 碼驗證（見 Truku_backend 說明文件/前端交接/帳號刪除串接指南.md §7）。
//
// 兩段式：填信箱 → POST /api/me/email 寄碼（60 秒後才可重寄）→ 填 6 碼 →
// POST /api/me/email/verify。未驗證的信箱收不到帳號刪除到期等通知信。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/app_back_button.dart';

class NotificationEmailScreen extends StatefulWidget {
  final UserModel user;

  const NotificationEmailScreen({super.key, required this.user});

  @override
  State<NotificationEmailScreen> createState() =>
      _NotificationEmailScreenState();
}

class _NotificationEmailScreenState extends State<NotificationEmailScreen> {
  static const int _resendCooldownSeconds = 60;
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  late final TextEditingController _emailController;
  final _codeController = TextEditingController();

  /// 已寄出驗證碼的信箱；null 代表還在第一段（填信箱）。
  String? _sentTo;
  bool _submitting = false;
  String? _error;

  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = '請輸入有效的電子信箱');
      return;
    }
    if (_submitting || _cooldown > 0) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await UserService.requestEmailVerification(email);
      if (!mounted) return;
      _codeController.clear();
      setState(() => _sentTo = email);
      _startCooldown(_resendCooldownSeconds);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      if (e.retryAfter != null) _startCooldown(e.retryAfter!);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '寄送失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = '請輸入 6 位數驗證碼');
      return;
    }
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await UserService.verifyEmail(code);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('通知信箱已驗證')));
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = _verifyErrorMessage(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '驗證失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _verifyErrorMessage(ApiException e) => switch (e.code) {
    'CODE_INVALID' => e.message.isNotEmpty ? e.message : '驗證碼不正確',
    'CODE_EXPIRED' => '驗證碼已過期，請重新寄送',
    'CODE_ATTEMPTS_EXCEEDED' => '錯誤次數過多，請重新寄送驗證碼',
    _ => e.message,
  };

  void _editEmail() {
    setState(() {
      _sentTo = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.cream,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('通知信箱', style: AppTypography.titleStyle(color: AppColors.ink)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _buildStatus(),
            const SizedBox(height: 16),
            Text(
              '帳號刪除到期提醒等重要通知會寄到這個信箱。未填寫或未驗證的信箱收不到這些通知。',
              style: AppTypography.bodyStyle(
                color: AppColors.ink.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            if (_sentTo == null) ..._buildEmailStep() else ..._buildCodeStep(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: AppTypography.bodyStyle(color: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatus() {
    final user = widget.user;
    final hasEmail = user.email.isNotEmpty;
    final verified = hasEmail && user.emailVerified;
    return Row(
      children: [
        Expanded(
          child: Text(
            hasEmail ? user.email : '尚未設定',
            style: AppTypography.bodyLargeStyle(color: AppColors.ink),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasEmail) EmailVerifiedBadge(verified: verified),
      ],
    );
  }

  List<Widget> _buildEmailStep() => [
    TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      style: AppTypography.bodyLargeStyle(color: AppColors.ink),
      decoration: InputDecoration(
        labelText: '電子信箱',
        labelStyle: AppTypography.bodyStyle(color: AppColors.fog),
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) => _sendCode(),
    ),
    const SizedBox(height: 16),
    _primaryButton(
      label: _cooldown > 0 ? '$_cooldown 秒後可再寄送' : '寄送驗證碼',
      onPressed: _cooldown > 0 ? null : _sendCode,
    ),
  ];

  List<Widget> _buildCodeStep() => [
    Text(
      '驗證碼已寄到 $_sentTo，10 分鐘內有效。沒收到的話請檢查垃圾郵件匣。',
      style: AppTypography.bodyStyle(color: AppColors.ink),
    ),
    const SizedBox(height: 16),
    TextField(
      controller: _codeController,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      autofillHints: const [AutofillHints.oneTimeCode],
      textAlign: TextAlign.center,
      style: AppTypography.headlineStyle(color: AppColors.ink),
      decoration: InputDecoration(
        labelText: '6 位數驗證碼',
        labelStyle: AppTypography.bodyStyle(color: AppColors.fog),
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) => _verify(),
    ),
    const SizedBox(height: 8),
    _primaryButton(label: '驗證', onPressed: _verify),
    const SizedBox(height: 8),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _submitting ? null : _editEmail,
          child: Text(
            '修改信箱',
            style: AppTypography.bodyStyle(color: AppColors.fog),
          ),
        ),
        TextButton(
          onPressed: _submitting || _cooldown > 0 ? null : _sendCode,
          child: Text(
            _cooldown > 0 ? '$_cooldown 秒後可重寄' : '重新寄送',
            style: AppTypography.bodyStyle(
              color: _cooldown > 0 ? AppColors.fog : AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  ];

  Widget _primaryButton({required String label, VoidCallback? onPressed}) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _submitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label, style: AppTypography.titleStyle()),
      ),
    );
  }
}

/// 「已驗證／未驗證」小標籤，個人頁與通知信箱頁共用。
class EmailVerifiedBadge extends StatelessWidget {
  final bool verified;

  const EmailVerifiedBadge({super.key, required this.verified});

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.moss : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        verified ? '已驗證' : '未驗證',
        style: AppTypography.captionStyle(color: color),
      ),
    );
  }
}
