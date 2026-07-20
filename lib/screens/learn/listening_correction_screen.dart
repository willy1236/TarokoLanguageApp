import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../models/listening_models.dart';
import '../../shared/widgets/truku_painters.dart';

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

  Future<void> _play(String? url) async {
    if (url == null) return;
    await _player.stop();
    await _player.play(UrlSource(url));
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
              _buildScoreSummary(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: [
                    for (final item in result.results) ...[
                      _ResultCard(item: item, onPlay: _play),
                      const SizedBox(height: 12),
                    ],
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

  Widget _buildScoreSummary() {
    final result = widget.result;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.level} · 聽力測驗訂正',
            style: GoogleFonts.crimsonPro(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.fog,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.score} / ${result.total}',
            style: GoogleFonts.notoSerifTc(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
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

class _ResultCard extends StatelessWidget {
  final ListeningResultItem item;
  final void Function(String? url) onPlay;

  const _ResultCard({required this.item, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final detail = item.detail;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isCorrect ? AppColors.creamDeep : AppColors.danger,
          width: item.isCorrect ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.isCorrect ? Icons.check_circle : Icons.cancel,
                color: item.isCorrect ? AppColors.moss : AppColors.danger,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '第 ${item.order} 題',
                style: GoogleFonts.notoSerifTc(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '你的答案：${item.yourAnswer.text}',
            style: GoogleFonts.notoSansTc(
              fontSize: 13,
              color: item.isCorrect ? AppColors.inkSoft : AppColors.danger,
            ),
          ),
          if (!item.isCorrect) ...[
            const SizedBox(height: 4),
            Text(
              '正確答案：${item.correctAnswer.text}',
              style: GoogleFonts.notoSansTc(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.moss,
              ),
            ),
          ],
          if (detail.explanation != null && detail.explanation!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail.explanation!,
              style: GoogleFonts.notoSansTc(fontSize: 12, color: AppColors.fog),
            ),
          ],
          if (detail.context != null && detail.context!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '場景：${detail.context}',
              style: GoogleFonts.notoSansTc(fontSize: 12, color: AppColors.fog),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _ReplayButton(
                label: '重聽題目',
                onTap: () => onPlay(item.promptAudioUrl),
              ),
              const SizedBox(width: 8),
              _ReplayButton(
                label: '聽正確答案發音',
                onTap: () => onPlay(detail.audioUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplayButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ReplayButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.creamLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(14, 14),
              painter: SpeakerIconPainter(color: AppColors.goldDeep),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.notoSansTc(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.goldDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
