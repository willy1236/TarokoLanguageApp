// 「帳號刪除中」畫面：帳號在 45 天刪除緩衝期內時的唯一入口。
//
// 進入點（見 Truku_backend 說明文件/前端交接/帳號刪除串接指南.md §4、§5）：
// - 登入回應 account_state == 'pending_deletion'（login_screen 帶 purgeAt 過來）
// - 任一 API 回 403 ACCOUNT_PENDING_DELETION（ApiClient 全域導來，沒有 purgeAt）
//
// 刪除中帳號只能呼叫 /api/account/*，其他 API 會被狀態閘擋下，因此這裡不可返回、
// 也不可進主畫面；使用者只能「重新啟用」或「維持刪除並登出」。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../services/account_lock_controller.dart';
import '../../services/account_service.dart';
import '../../services/session_service.dart';
import '../../services/user_service.dart';

class AccountPendingScreen extends StatefulWidget {
  /// 登入回應帶來的永久刪除時間；null 時進畫面後向後端查。
  final DateTime? purgeAt;

  const AccountPendingScreen({super.key, this.purgeAt});

  @override
  State<AccountPendingScreen> createState() => _AccountPendingScreenState();
}

class _AccountPendingScreenState extends State<AccountPendingScreen> {
  DateTime? _purgeAt;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _purgeAt = widget.purgeAt;
    // 登入帶來的值是當下的；全域導來的沒有值。兩者都向後端刷新一次。
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    try {
      final status = await AccountService.fetchStatus();
      if (!mounted) return;
      if (!status.isPendingDeletion) {
        // 另一台裝置已重新啟用：直接回主畫面（鎖定帳號還原後為唯讀）。
        accountLockController.setLocked(status.isLocked);
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
        return;
      }
      setState(() => _purgeAt = status.purgeAt ?? _purgeAt);
    } catch (e) {
      // 查不到就沿用登入帶來的值；410 由 ApiClient 全域處理。
      debugPrint('AccountPendingScreen: fetchStatus 失敗：$e');
    }
  }

  Future<void> _reactivate() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      // 刪除前被鎖的帳號會還原成 locked，不能假設一定是 active。
      final status = await AccountService.reactivate();
      accountLockController.setLocked(status.isLocked);
      UserService.clearCache();
      final user = await UserService.fetchMe(forceRefresh: true);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        user.profileCompleted ? '/home' : '/complete-profile',
        (_) => false,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            status.isLocked ? '帳號已重新啟用，目前為唯讀狀態' : '帳號已重新啟用，歡迎回來',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted || e.isAccountPurged) return;
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showError('重新啟用失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _keepDeletedAndSignOut() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await SessionService.signOut(unregisterDevice: false);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final purgeAt = _purgeAt;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            '帳號刪除中',
            style: AppTypography.titleStyle(color: AppColors.ink),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            children: [
              Icon(
                Icons.hourglass_bottom_rounded,
                size: 56,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              Text(
                purgeAt == null
                    ? '你的帳號已排定永久刪除'
                    : '還有 ${daysUntilPurge(purgeAt)} 天永久刪除',
                textAlign: TextAlign.center,
                style: AppTypography.headlineStyle(color: AppColors.ink),
              ),
              if (purgeAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  '預定刪除日期：${_formatDate(purgeAt)}',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyStyle(color: AppColors.fog),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                '重新啟用後，你的好友、貼文、測驗紀錄、小米幣與頭像都會完整恢復。\n\n'
                '申請刪除時已取消的活動（你主辦的活動、你已報名的活動）不會恢復，需要的話請重新報名。\n\n'
                '若不重新啟用，帳號會在到期日永久刪除，之後無法復原。',
                style: AppTypography.bodyLargeStyle(
                  color: AppColors.ink.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _reactivate,
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
                      : Text('重新啟用帳號', style: AppTypography.titleStyle()),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _submitting ? null : _keepDeletedAndSignOut,
                child: Text(
                  '維持刪除並登出',
                  style: AppTypography.bodyLargeStyle(color: AppColors.fog),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
