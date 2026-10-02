// 分級測驗（單字/聽力共用）結果畫面。
// 對應 POST /api/{quiz,listening}/placement/submit 回應，
// 規格參考：Truku_backend docs/superpowers/specs/2026-08-17-quiz-listening-placement-design.md
//
// 版面比照測驗紀錄詳解：酒紅 ScoreHeader + 左上返回鍵 + 逐題卡。
// 測驗頁以 pushReplacement 進來，下面可能還疊著等級選擇頁，所以返回鍵、主要按鈕、
// 系統返回一律 popUntil(isFirst) 回到學習頁，不會退回測驗題目頁。

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/placement_models.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/truku_widgets.dart';
import '../history/history_review_card.dart';

class PlacementResultScreen extends StatelessWidget {
  final PlacementResult result;
  final String title; // '單字分級測驗' | '聽力分級測驗'

  const PlacementResultScreen({
    super.key,
    required this.result,
    required this.title,
  });

  /// 學習頁沒有能帶等級參數的入口，主要按鈕只負責回到學習頁。
  static const backToLearnLabel = '回到學習頁';

  void _backToLearn(BuildContext context) =>
      Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToLearn(context);
      },
      child: ListenableBuilder(
        listenable: seniorModeController,
        builder: (context, _) =>
            _buildScaffold(context, seniorModeController.enabled),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, bool seniorMode) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(context, seniorMode),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPrimaryButton(context, seniorMode),
                  const SizedBox(height: 28),
                  _buildSectionTitle(seniorMode),
                  const SizedBox(height: 12),
                  for (final item in result.results)
                    _ResultItemCard(item: item, seniorMode: seniorMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool seniorMode) {
    // ScoreHeader 往下讓出返回鍵的高度，避免左上返回鍵壓到測驗名稱。
    return ColoredBox(
      color: AppColors.primary,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 36),
            child: ScoreHeader(
              title: title,
              score: result.score,
              total: result.total,
              seniorMode: seniorMode,
              footer: _buildSuggestedLevel(seniorMode),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: AppBackButton(
              onDark: true,
              onPressed: () => _backToLearn(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedLevel(bool seniorMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '建議起始等級',
          style: AppTypography.bodyStyle(
            seniorMode: seniorMode,
            color: AppColors.creamLight.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          result.resultLevel,
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
        const SizedBox(height: 8),
        Text(
          '這只是建議，你隨時可以手動選擇其他等級開始測驗。',
          style: AppTypography.bodyStyle(
            seniorMode: seniorMode,
            color: AppColors.creamLight.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(BuildContext context, bool seniorMode) {
    return FilledButton(
      onPressed: () => _backToLearn(context),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.creamLight,
        minimumSize: Size.fromHeight(seniorMode ? 56 : 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        backToLearnLabel,
        style: AppTypography.titleStyle(
          seniorMode: seniorMode,
          color: AppColors.creamLight,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(bool seniorMode) {
    return Row(
      children: [
        const TrukuDiamond(size: 12, color: AppColors.primary, filled: true),
        const SizedBox(width: 8),
        Text(
          '逐題詳解',
          style: AppTypography.titleStyle(
            seniorMode: seniorMode,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

/// 逐題卡：視覺比照測驗紀錄的 [ReviewCard]（題號、答對/答錯標籤、對錯色條、
/// 你的作答／正確答案）。分級結果沒有 sessionId 對應的紀錄可檢舉，也不另外展開
/// 單字詳解，所以不直接套 ReviewCard。
class _ResultItemCard extends StatelessWidget {
  final PlacementResultItem item;
  final bool seniorMode;

  const _ResultItemCard({required this.item, required this.seniorMode});

  double _size(double base) => AppTypography.size(base, seniorMode: seniorMode);

  @override
  Widget build(BuildContext context) {
    final prompt = item.prompt ?? item.detail?.truku ?? '';
    final tone = item.isCorrect ? AppColors.moss : AppColors.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: tone, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '第 ${item.order} 題',
                style: AppTypography.mono(
                  fontSize: _size(AppTypography.caption),
                  color: AppColors.fog,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.isCorrect ? '答對' : '答錯',
                  style: AppTypography.sans(
                    fontSize: _size(AppTypography.caption),
                    fontWeight: FontWeight.w600,
                    color: tone,
                  ),
                ),
              ),
            ],
          ),
          if (prompt.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              prompt,
              style: AppTypography.serif(
                fontSize: _size(AppTypography.subtitle),
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _answerRow('你的作答', item.yourAnswer?.text ?? '（未作答）', tone),
          if (!item.isCorrect) ...[
            const SizedBox(height: 6),
            _answerRow('正確答案', item.correctAnswer.text, AppColors.moss),
          ],
        ],
      ),
    );
  }

  Widget _answerRow(String label, String value, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: seniorMode ? 76 : 64,
          child: Text(
            label,
            style: AppTypography.bodyStyle(
              seniorMode: seniorMode,
              color: AppColors.fog,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.sans(
              fontSize: _size(AppTypography.body),
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
