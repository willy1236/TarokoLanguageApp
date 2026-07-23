// 測驗紀錄詳解共用的逐題卡片，供 quiz / listening 詳解畫面共用。
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class ReviewCard extends StatelessWidget {
  final int order;
  final String? promptText;
  final String? promptAudioUrl;
  final bool isCorrect;
  final String yourAnswerText;
  final String correctAnswerText;
  final String detailTitle;
  final String? detailSubtitle;
  final String? explanation;
  final String? detailAudioUrl;
  final AudioPlayer player;

  const ReviewCard({
    super.key,
    required this.order,
    required this.promptText,
    required this.promptAudioUrl,
    required this.isCorrect,
    required this.yourAnswerText,
    required this.correctAnswerText,
    required this.detailTitle,
    required this.detailSubtitle,
    required this.explanation,
    required this.detailAudioUrl,
    required this.player,
  });

  Future<void> _play(String? url) async {
    if (url == null) return;
    await player.stop();
    await player.play(UrlSource(url));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: isCorrect ? AppColors.moss : AppColors.danger,
            width: 4,
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '第 $order 題',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: AppColors.fog,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isCorrect ? AppColors.moss : AppColors.danger)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCorrect ? '答對' : '答錯',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isCorrect ? AppColors.moss : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (promptText != null)
                Expanded(
                  child: Text(
                    promptText!,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              if (promptAudioUrl != null)
                Padding(
                  padding: promptText == null ? EdgeInsets.zero : const EdgeInsets.only(left: 8),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _play(promptAudioUrl),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold,
                          ),
                          child: const Icon(Icons.volume_up, size: 18, color: AppColors.ink),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '原題發音',
                        style: TextStyle(fontSize: 10, color: AppColors.fog),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _answerRow('你的作答', yourAnswerText, isCorrect ? AppColors.moss : AppColors.danger),
          if (!isCorrect) ...[
            const SizedBox(height: 6),
            _answerRow('正確答案', correctAnswerText, AppColors.moss),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.creamDeep),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detailTitle,
                      style: GoogleFonts.crimsonPro(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    if (detailSubtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detailSubtitle!,
                        style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                      ),
                    ],
                    if (explanation != null && explanation!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        explanation!,
                        style: const TextStyle(fontSize: 12, color: AppColors.fog, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              if (detailAudioUrl != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _play(detailAudioUrl),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.gold),
                          ),
                          child: const Icon(Icons.play_arrow, size: 16, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '標準發音',
                        style: TextStyle(fontSize: 10, color: AppColors.fog),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _answerRow(String label, String value, Color valueColor) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.fog)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor),
          ),
        ),
      ],
    );
  }
}

class ScoreHeader extends StatelessWidget {
  final String title;
  final int score;
  final int total;

  const ScoreHeader({super.key, required this.title, required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.crimsonPro(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.gold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$score / $total',
            style: GoogleFonts.notoSerifTc(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: AppColors.creamLight,
            ),
          ),
        ],
      ),
    );
  }
}
