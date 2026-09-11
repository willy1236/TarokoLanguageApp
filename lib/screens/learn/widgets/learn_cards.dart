// 學習首頁的卡片元件：單字／聽力測驗入口、分級測驗摘要與入口、分級測驗選項。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/truku_painters.dart';
import '../../../shared/widgets/truku_widgets.dart';
import '../../../core/constants/app_typography.dart';

class LearnPlacementOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback onTap;

  const LearnPlacementOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.creamDeep, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: AppTypography.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    done ? '已完成' : subtitle,
                    style: GoogleFonts.notoSansTc(
                      fontSize: AppTypography.caption,
                      color: AppColors.fog,
                    ),
                  ),
                ],
              ),
            ),
            const TrukuChevron(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ── VocabQuizCard ─────────────────────────────────────────────────────────────

class LearnVocabQuizCard extends StatelessWidget {
  final VoidCallback onTap;

  const LearnVocabQuizCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Opacity(
                    opacity: 0.15,
                    child: CustomPaint(
                      painter: TrukuWeavePainter(
                        color: AppColors.gold,
                        opacity: 1.0,
                        scale: 0.7,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: TrukuDiamond(
                  size: 40,
                  color: AppColors.gold.withValues(alpha: 0.4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SLHAYAN · 單字測驗',
                      style: GoogleFonts.crimsonPro(
                        fontSize: AppTypography.caption,
                        fontStyle: FontStyle.italic,
                        color: AppColors.gold,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '單字測驗',
                      style: GoogleFonts.notoSerifTc(
                        fontSize: AppTypography.headline,
                        fontWeight: FontWeight.w600,
                        color: AppColors.creamLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '選級別，測驗詞彙\n單字卡跟讀．答題挑戰',
                      style: GoogleFonts.notoSansTc(
                        fontSize: AppTypography.body,
                        height: 1.5,
                        color: AppColors.mist,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ListeningQuizCard ─────────────────────────────────────────────────────────

class LearnListeningQuizCard extends StatelessWidget {
  final VoidCallback onTap;

  const LearnListeningQuizCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.mossDeep,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Opacity(
                    opacity: 0.15,
                    child: CustomPaint(
                      painter: TrukuWeavePainter(
                        color: AppColors.gold,
                        opacity: 1.0,
                        scale: 0.7,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: TrukuDiamond(
                  size: 40,
                  color: AppColors.gold.withValues(alpha: 0.4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ENDAAN · 聽力測驗',
                      style: GoogleFonts.crimsonPro(
                        fontSize: AppTypography.caption,
                        fontStyle: FontStyle.italic,
                        color: AppColors.gold,
                        letterSpacing: 2.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '聽力測驗',
                      style: GoogleFonts.notoSerifTc(
                        fontSize: AppTypography.headline,
                        fontWeight: FontWeight.w600,
                        color: AppColors.creamLight,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '聽發音，選出正確答案\n練耳朵．練反應',
                      style: GoogleFonts.notoSansTc(
                        fontSize: AppTypography.body,
                        height: 1.5,
                        color: AppColors.mist,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PlacementSummaryCard ──────────────────────────────────────────────────────

class LearnPlacementSummaryCard extends StatelessWidget {
  final String? quizLevel;
  final String? listeningLevel;
  final VoidCallback onTap;

  const LearnPlacementSummaryCard({
    super.key,
    required this.quizLevel,
    required this.listeningLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.creamDeep, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const TrukuDiamond(
              size: 28,
              color: AppColors.primary,
              filled: true,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '你的推薦起始等級',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: AppTypography.body,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '單字 ${quizLevel ?? "尚未測驗"}．聽力 ${listeningLevel ?? "尚未測驗"}',
                    style: GoogleFonts.notoSansTc(
                      fontSize: AppTypography.caption,
                      color: AppColors.fog,
                    ),
                  ),
                ],
              ),
            ),
            const TrukuChevron(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ── PlacementQuizCard ─────────────────────────────────────────────────────────

class LearnPlacementQuizCard extends StatelessWidget {
  final VoidCallback onTap;

  const LearnPlacementQuizCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.creamDeep, width: 1),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 16,
            right: 16,
            child: TrukuDiamond(
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SMRMUN · 分級測驗',
                  style: GoogleFonts.crimsonPro(
                    fontSize: AppTypography.caption,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primary,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '分級測驗',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: AppTypography.headline,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '先做一次測驗，找到最適合你的起始等級',
                  style: GoogleFonts.notoSansTc(
                    fontSize: AppTypography.body,
                    height: 1.5,
                    color: AppColors.fog,
                  ),
                ),
                const SizedBox(height: 18),
                _PillButton(
                  icon: Icons.edit_note,
                  label: '開始測驗',
                  background: AppColors.primary,
                  foreground: AppColors.creamLight,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.notoSerifTc(
                fontSize: AppTypography.body,
                fontWeight: FontWeight.w600,
                color: foreground,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── QuizEntryCard ─────────────────────────────────────────────────────────────

enum LearnCardTone { dark, primary }

class LearnQuizEntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final LearnCardTone tone;

  const LearnQuizEntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone = LearnCardTone.dark,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = tone == LearnCardTone.dark;
    final iconColor = isDark ? AppColors.gold : AppColors.creamLight;
    final titleColor = AppColors.creamLight;
    final subtitleColor = isDark
        ? AppColors.mist
        : AppColors.creamLight.withValues(alpha: 0.75);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.ink : AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: AppTypography.bodyLarge,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                      letterSpacing: 0.85,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppTypography.caption,
                      color: subtitleColor,
                      letterSpacing: 0.55,
                    ),
                  ),
                ],
              ),
            ),
            TrukuChevron(color: iconColor),
          ],
        ),
      ),
    );
  }
}
