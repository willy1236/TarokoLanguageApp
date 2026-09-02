// 分級測驗（單字/聽力共用）結果畫面。
// 對應 POST /api/{quiz,listening}/placement/submit 回應，
// 規格參考：Truku_backend docs/superpowers/specs/2026-08-17-quiz-listening-placement-design.md

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../models/placement_models.dart';
import '../../shared/widgets/truku_widgets.dart';

class PlacementResultScreen extends StatelessWidget {
  final PlacementResult result;
  final String title; // '單字分級測驗' | '聽力分級測驗'

  const PlacementResultScreen({
    super.key,
    required this.result,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              title,
              style: GoogleFonts.crimsonPro(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.fog,
                letterSpacing: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '完成！',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerifTc(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 20),
            _buildResultCard(),
            const SizedBox(height: 24),
            Row(
              children: [
                const TrukuDiamond(size: 12, color: AppColors.primary, filled: true),
                const SizedBox(width: 8),
                Text(
                  '逐題詳解',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in result.results) ...[
              _ResultItemCard(item: item),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: GestureDetector(
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '返回',
                      style: GoogleFonts.notoSerifTc(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.creamLight,
                        letterSpacing: 1.5,
                      ),
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

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            '${result.score} / ${result.total}',
            style: GoogleFonts.notoSerifTc(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '建議起始等級',
            style: GoogleFonts.notoSansTc(
              fontSize: 11,
              color: AppColors.creamLight.withValues(alpha: 0.7),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.resultLevel,
            style: GoogleFonts.notoSerifTc(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.creamLight,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '這只是建議，你隨時可以手動選擇其他等級開始測驗。',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSansTc(
                fontSize: 12,
                color: AppColors.creamLight.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultItemCard extends StatelessWidget {
  final PlacementResultItem item;

  const _ResultItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final prompt = item.prompt ?? item.detail?.truku ?? '';
    final correctText = item.correctAnswer.text;
    final yourText = item.yourAnswer?.text ?? '（未作答）';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: item.isCorrect ? AppColors.primary : AppColors.danger,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.isCorrect ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: item.isCorrect ? AppColors.primary : AppColors.danger,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  prompt,
                  style: GoogleFonts.crimsonPro(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!item.isCorrect)
            Text(
              '你的答案：$yourText',
              style: GoogleFonts.notoSansTc(fontSize: 12, color: AppColors.fog),
            ),
          Text(
            '正確答案：$correctText',
            style: GoogleFonts.notoSansTc(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
