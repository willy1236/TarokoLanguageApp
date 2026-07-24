import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../models/listening_models.dart';
import '../../shared/widgets/truku_painters.dart';
import '../history/history_review_card.dart';

class ListeningCorrectionScreen extends StatefulWidget {
  final ListeningResult result;
  final String level;

  const ListeningCorrectionScreen({
    super.key,
    required this.result,
    required this.level,
  });

  @override
  State<ListeningCorrectionScreen> createState() =>
      _ListeningCorrectionScreenState();
}

class _ListeningCorrectionScreenState extends State<ListeningCorrectionScreen> {
  final _player = AudioPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              ScoreHeader(
                title: '${widget.level} · 聽力測驗訂正',
                score: result.score,
                total: result.total,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    for (final item in result.results)
                      ReviewCard(
                        order: item.order,
                        promptText: null,
                        promptAudioUrl: item.promptAudioUrl,
                        isCorrect: item.isCorrect,
                        yourAnswerText: item.yourAnswer.text,
                        correctAnswerText: item.correctAnswer.text,
                        detailTitle: item.detail.type == 'word'
                            ? '${item.detail.truku} · ${item.detail.zh}'
                            : item.detail.zh,
                        detailSubtitle: item.detail.context,
                        explanation: item.detail.explanation,
                        detailAudioUrl: item.detail.audioUrl,
                        player: _player,
                      ),
                    const SizedBox(height: 8),
                    _buildBottomButtons(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: CustomPaint(
              size: const Size(24, 24),
              painter: const BackArrowPainter(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Row(
      children: [
        _buildBottomButton(
          label: '重新測驗',
          primary: false,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 10),
        _buildBottomButton(
          label: '返回 →',
          primary: true,
          onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
      ],
    );
  }

  Widget _buildBottomButton({
    required String label,
    required bool primary,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: primary ? AppColors.primary : AppColors.creamLight,
            borderRadius: BorderRadius.circular(12),
            border: primary
                ? null
                : Border.all(color: AppColors.creamDeep, width: 1.5),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.notoSerifTc(
                fontSize: 14,
                fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
                color: primary ? AppColors.creamLight : AppColors.inkSoft,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
