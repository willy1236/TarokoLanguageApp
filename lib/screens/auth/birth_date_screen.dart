// 舊使用者補填出生日期（POL-01）。出生日期上線前就填完基本資料的人
// （profile_completed=true 且 needs_birth_date=true）一律擋在這頁，
// 送出 POST /api/me/birth-date 後才依 entryRouteFor 接續條款或首頁。
// 不能返回、不能跳過，只能登出換帳號。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/user_model.dart';
import '../../services/fcm_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/session_service.dart';
import '../../services/terms_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/birth_date_field.dart';
import '../../shared/widgets/truku_painters.dart';
import 'entry_route.dart';

class BirthDateScreen extends StatefulWidget {
  const BirthDateScreen({super.key});

  @override
  State<BirthDateScreen> createState() => _BirthDateScreenState();
}

class _BirthDateScreenState extends State<BirthDateScreen> {
  DateTime? _birthDate;
  bool _submitting = false;

  // 生日確認框開著：同一幀連點送出時擋住第二次，不疊兩個確認框、不送兩次。
  // 只當守衛用，不必重建畫面（確認框的遮罩已蓋住送出鈕）。
  bool _confirming = false;

  Future<void> _submit() async {
    if (_submitting || _confirming) return;
    final birthDate = _birthDate;
    if (birthDate == null) {
      _showError('請選擇出生日期');
      return;
    }
    _confirming = true;
    final bool confirmed;
    try {
      confirmed = await confirmBirthDate(context, birthDate);
    } finally {
      _confirming = false;
    }
    if (!confirmed || !mounted) return;
    setState(() => _submitting = true);
    try {
      UserModel user;
      try {
        user = await UserService.submitBirthDate(birthDate);
      } on ApiException catch (e) {
        // 別台裝置已填過：以後端為準直接放行。
        if (!e.isBirthDateAlreadySet) rethrow;
        user = await UserService.fetchMe(forceRefresh: true);
      }
      await _continue(user);
    } on ApiException catch (e) {
      // 未同意條款：ApiClient 已導去同意畫面，同意後由該畫面接續導頁。
      if (e.isConsentRequired) return;
      _showError(e.message);
    } catch (_) {
      _showError('送出失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _continue(UserModel user) async {
    // 查不到同意狀態時不擋，未同意由 ApiClient 的 CONSENT_REQUIRED 補救。
    var allConsented = true;
    try {
      allConsented = (await TermsService.fetchStatus()).allConsented;
    } catch (e) {
      debugPrint('BirthDateScreen: fetchStatus 失敗，略過同意條款檢查：$e');
    }
    if (!mounted) return;
    final route = entryRouteFor(user, allConsented: allConsented);
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    // 冷啟動被擋在這頁時，splash 沒處理通知深連結，進首頁後補上。
    if (route == '/home') FcmService.consumePendingInitialMessage();
  }

  Future<void> _signOut() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await SessionService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.midnight,
                      AppColors.primaryDeep,
                      AppColors.primary,
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: TrukuWeavePainter(
                  color: AppColors.gold,
                  opacity: 0.12,
                ),
              ),
            ),
            SafeArea(
              child: ListenableBuilder(
                listenable: seniorModeController,
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 64, // 扣掉上下 padding
                      ),
                      child: _buildForm(seniorModeController.enabled),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool seniorMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '補填出生日期',
          style: AppTypography.titleStyle(
            seniorMode: seniorMode,
            color: AppColors.creamLight,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '隨機配對僅限年滿 18 歲使用，請先補填出生日期再繼續',
          style: AppTypography.captionStyle(
            seniorMode: seniorMode,
            color: AppColors.cream.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),
        BirthDateField(
          value: _birthDate,
          onChanged: (d) => setState(() => _birthDate = d),
          seniorMode: seniorMode,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: seniorMode ? 60 : 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.ink,
                    ),
                  )
                : Text(
                    '送　出',
                    style: AppTypography.bodyLargeStyle(
                      seniorMode: seniorMode,
                      color: AppColors.ink,
                    ).copyWith(fontWeight: FontWeight.w600, letterSpacing: 4),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _submitting ? null : _signOut,
            child: Text(
              '登出，改用其他帳號',
              style: AppTypography.bodyStyle(
                seniorMode: seniorMode,
                color: AppColors.cream.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
