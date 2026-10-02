// 分級測驗已做過時的畫面（單字/聽力共用）。每個帳號只能做一次，後端不保留可重看的
// 逐題結果，所以這裡只顯示已完成與目前的建議等級。
//
// 兩種進入方式：學習頁已知做過就直接推這頁；或測驗頁開始時後端回 ALREADY_PLACED
// （學習頁資料過時），由 QuizFlowView 的 errorBuilder 換成 [PlacementDoneView]。
// 版面比照分級結果頁：酒紅頂部 + 左上返回鍵 + 主要按鈕。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/user_model.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/app_back_button.dart';

class PlacementDoneScreen extends StatelessWidget {
  final String title; // '單字分級測驗' | '聽力分級測驗'
  final String? suggestedLevel;
  final String? Function(UserModel user) levelOf;

  const PlacementDoneScreen({
    super.key,
    required this.title,
    required this.levelOf,
    this.suggestedLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        bottom: false,
        child: PlacementDoneView(
          title: title,
          levelOf: levelOf,
          suggestedLevel: suggestedLevel,
        ),
      ),
    );
  }
}

/// 不含 Scaffold 的本體，讓測驗頁的錯誤狀態也能直接嵌入。
class PlacementDoneView extends StatefulWidget {
  final String title;

  /// 已知的建議等級；null 時向後端重抓 /me，再用 [levelOf] 取出對應欄位。
  final String? suggestedLevel;
  final String? Function(UserModel user) levelOf;

  const PlacementDoneView({
    super.key,
    required this.title,
    required this.levelOf,
    this.suggestedLevel,
  });

  static const backLabel = '返回';

  @override
  State<PlacementDoneView> createState() => _PlacementDoneViewState();
}

class _PlacementDoneViewState extends State<PlacementDoneView> {
  String? _level;

  @override
  void initState() {
    super.initState();
    _level = widget.suggestedLevel;
    if (_level == null) _loadLevel();
  }

  Future<void> _loadLevel() async {
    try {
      final user = await UserService.fetchMe(forceRefresh: true);
      if (!mounted) return;
      setState(() => _level = widget.levelOf(user));
    } catch (_) {
      // 抓不到就不顯示等級，仍可返回。
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) {
        final seniorMode = seniorModeController.enabled;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(context, seniorMode),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: _buildButton(context, seniorMode),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool seniorMode) {
    final dim = AppColors.creamLight.withValues(alpha: 0.7);
    final level = _level;
    return ColoredBox(
      color: AppColors.primary,
      child: Stack(
        children: [
          Padding(
            // 讓出返回鍵的高度，與分級結果頁一致。
            padding: const EdgeInsets.fromLTRB(24, 36 + 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: AppTypography.latin(
                    fontSize: AppTypography.size(
                      AppTypography.caption,
                      seniorMode: seniorMode,
                    ),
                    fontStyle: FontStyle.italic,
                    color: AppColors.gold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '已完成',
                  style: AppTypography.serif(
                    fontSize: AppTypography.display36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.creamLight,
                  ),
                ),
                if (level != null && level.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '建議起始等級',
                    style: AppTypography.bodyStyle(
                      seniorMode: seniorMode,
                      color: dim,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level,
                    style: AppTypography.serif(
                      fontSize: AppTypography.size(
                        AppTypography.headline,
                        seniorMode: seniorMode,
                      ),
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '分級測驗每個帳號只做一次。建議等級只是參考，你隨時可以手動選擇其他等級開始測驗。',
                  style: AppTypography.bodyStyle(
                    seniorMode: seniorMode,
                    color: dim,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: AppBackButton(
              onDark: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext context, bool seniorMode) {
    return FilledButton(
      onPressed: () => Navigator.of(context).maybePop(),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.creamLight,
        minimumSize: Size.fromHeight(seniorMode ? 56 : 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        PlacementDoneView.backLabel,
        style: AppTypography.titleStyle(
          seniorMode: seniorMode,
          color: AppColors.creamLight,
        ),
      ),
    );
  }
}
