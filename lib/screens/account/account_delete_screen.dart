// 刪除帳號：確認頁 → DELETE /api/account → 成功頁（顯示永久刪除日期與復原方式）。
//
// 規格見 Truku_backend 說明文件/前端交接/帳號刪除串接指南.md §3：
// - 確認頁須明列 45 天可反悔，以及「第 0 天即不可逆」的活動取消。
// - 到期提醒信與推播都不可靠，成功頁是唯一可靠的告知管道，須顯示 purge_at。
// - 成功後 token 立即失效：清本地 token、Firebase signOut、導回登入頁。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../services/account_service.dart';
import '../../services/session_service.dart';
import '../../shared/widgets/app_back_button.dart';

class AccountDeleteScreen extends StatefulWidget {
  const AccountDeleteScreen({super.key});

  @override
  State<AccountDeleteScreen> createState() => _AccountDeleteScreenState();
}

class _AccountDeleteScreenState extends State<AccountDeleteScreen> {
  static const int _reasonMaxLength = 200;

  final _reasonController = TextEditingController();
  bool _acknowledged = false;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_acknowledged) return;
    setState(() => _submitting = true);
    try {
      final status = await AccountService.deleteAccount(
        reason: _reasonController.text,
      );
      // token 已被後端撤銷：先清本機登入狀態，再清掉整個 stack，
      // 避免背景畫面拿失效 token 打 API 觸發「登入已過期」導頁蓋掉成功頁。
      await SessionService.signOut(unregisterDevice: false);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AccountDeletedScreen(purgeAt: status.purgeAt),
        ),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      _showError('刪除失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        title: Text(
          '刪除帳號',
          style: AppTypography.titleStyle(color: AppColors.ink),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              '刪除前請先了解',
              style: AppTypography.headlineStyle(color: AppColors.ink),
            ),
            const SizedBox(height: 16),
            const _Point(
              icon: Icons.history_rounded,
              title: '45 天內可以反悔',
              body: '送出後帳號會停用 45 天。期間用原本的 Google／Apple 帳號重新登入，即可選擇重新啟用，資料完整恢復。',
            ),
            const _Point(
              icon: Icons.delete_forever_rounded,
              title: '45 天後永久刪除',
              body: '到期後你的個人資料、好友、貼文、測驗紀錄、小米幣與頭像都會永久刪除，無法復原。之後用同一帳號登入會是全新的空帳號。',
            ),
            const _Point(
              icon: Icons.event_busy_rounded,
              title: '活動會立即取消，重新啟用也不會恢復',
              body: '你主辦中的活動會在送出當下取消並通知參加者；你已報名的他人活動也會取消報名、釋出名額。',
              warning: true,
            ),
            const _Point(
              icon: Icons.mark_email_unread_outlined,
              title: '到期提醒不一定收得到',
              body: '只有已驗證通知信箱的帳號會收到到期提醒信，推播也會在送出時停止。請自行記下刪除日期。',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLength: _reasonMaxLength,
              maxLines: 3,
              minLines: 2,
              style: AppTypography.bodyLargeStyle(color: AppColors.ink),
              decoration: InputDecoration(
                labelText: '想告訴我們離開的原因嗎？（選填）',
                labelStyle: AppTypography.bodyStyle(color: AppColors.fog),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _acknowledged,
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => _acknowledged = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
              title: Text(
                '我已了解以上內容，確定要刪除帳號',
                style: AppTypography.bodyLargeStyle(color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _acknowledged && !_submitting ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.creamLight,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.creamLight,
                        ),
                      )
                    : Text(
                        '刪除帳號',
                        style: AppTypography.titleStyle(
                          color: AppColors.creamLight,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool warning;

  const _Point({
    required this.icon,
    required this.title,
    required this.body,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.primary : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleStyle(color: color)),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTypography.bodyStyle(
                    color: AppColors.ink.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 刪除成功頁。此時已登出，只能回登入頁。
class AccountDeletedScreen extends StatelessWidget {
  final DateTime? purgeAt;

  const AccountDeletedScreen({super.key, this.purgeAt});

  String _formatDate(DateTime d) => '${d.year} 年 ${d.month} 月 ${d.day} 日';

  @override
  Widget build(BuildContext context) {
    final purgeAt = this.purgeAt;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 56,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              Text(
                '已申請刪除帳號',
                textAlign: TextAlign.center,
                style: AppTypography.headlineStyle(color: AppColors.ink),
              ),
              const SizedBox(height: 24),
              if (purgeAt != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.creamDeep,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '永久刪除日期',
                        style: AppTypography.bodyStyle(color: AppColors.fog),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(purgeAt),
                        style: AppTypography.headlineStyle(
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                '在這之前，用原本的 Google／Apple 帳號重新登入，就能選擇重新啟用帳號，資料會完整恢復。\n\n'
                '過了這個日期，帳號與資料會永久刪除，無法復原。到期提醒不一定收得到，請自行記下日期。',
                style: AppTypography.bodyLargeStyle(
                  color: AppColors.ink.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (_) => false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.ink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text('我知道了', style: AppTypography.titleStyle()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
