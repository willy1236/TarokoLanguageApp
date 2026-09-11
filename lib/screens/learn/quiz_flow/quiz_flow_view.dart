// 四支測驗畫面共用的版面：進度條、單元標籤、深色題卡（題幹＋播放／慢速）、
// 選項、下一題按鈕與錯誤畫面。畫面差異只剩標籤文字、題卡說明與錯誤文案，
// 由 [QuizFlowView] 的參數帶入。

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/audio_url.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/truku_painters.dart';
import '../../../shared/widgets/truku_widgets.dart';
import 'quiz_flow_controller.dart';

/// 題目發音播放。失敗時呼叫 [onError]（畫面顯示 SnackBar）。
class QuizAudio {
  final _player = AudioPlayer();

  Future<void> play(
    String? url, {
    double rate = 1.0,
    required VoidCallback onError,
  }) async {
    if (url == null) return;
    try {
      await _player.stop();
      await _player.setPlaybackRate(rate);
      await _player.play(UrlSource(sanitizeAudioUrl(url)));
    } catch (e) {
      debugPrint('QuizAudio.play failed: $e');
      onError();
    }
  }

  void dispose() => _player.dispose();
}

class QuizFlowView extends StatelessWidget {
  final QuizFlowController controller;
  final QuizAudio audio;

  /// 題卡上方的小字（例如「LEVEL · A1」）與大字標題。
  final String unitCaption;
  final String unitTitle;
  final double unitTitleSize;

  /// 題卡左上的說明（例如「聆聽 · 選出正確答案」）。
  final String cardCaption;

  final Future<void> Function() onRetry;
  final Future<void> Function() onConfirm;

  /// 自訂錯誤文案；回 null 走 [TrukuErrorView] 預設規則。
  final String? Function(Object? error)? errorMessageOf;

  /// 錯誤是否可重試（例如已完成分級測驗就不給重試）。
  final bool Function(Object? error)? retryable;

  /// phase 為 done 時的畫面；null 則維持轉圈（送出後由畫面導頁）。
  final WidgetBuilder? doneBuilder;

  const QuizFlowView({
    super.key,
    required this.controller,
    required this.audio,
    required this.unitCaption,
    required this.unitTitle,
    this.unitTitleSize = 18,
    required this.cardCaption,
    required this.onRetry,
    required this.onConfirm,
    this.errorMessageOf,
    this.retryable,
    this.doneBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            switch (controller.phase) {
              case QuizFlowPhase.loading:
                return const TrukuLoadingView();
              case QuizFlowPhase.error:
                return _buildError(context);
              case QuizFlowPhase.done:
                return doneBuilder?.call(context) ?? const TrukuLoadingView();
              case QuizFlowPhase.quiz:
                return _buildQuiz(context);
            }
          },
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final error = controller.error;
    final canRetry = retryable?.call(error) ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _BackArrow(onTap: () => Navigator.pop(context)),
        ),
        Expanded(
          child: TrukuErrorView(
            error: error,
            message: errorMessageOf?.call(error),
            onRetry: canRetry ? onRetry : null,
          ),
        ),
      ],
    );
  }

  Widget _buildQuiz(BuildContext context) {
    final question = controller.current;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressBar(index: controller.currentIndex, total: controller.total),
          QuizUnitLabel(
            caption: unitCaption,
            title: unitTitle,
            titleSize: unitTitleSize,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: [
                _QuestionCard(
                  caption: cardCaption,
                  question: question,
                  onPlay: (rate) => audio.play(
                    question.audioUrl,
                    rate: rate,
                    onError: () {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('發音播放失敗，請稍後再試')),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                for (final option in question.options) ...[
                  _OptionTile(
                    label: option.text,
                    selected: option.id == controller.selectedOptionId,
                    onTap: () => controller.select(option.id),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    QuizBottomButton(
                      label: controller.isLast ? '完成測驗 →' : '下一題 →',
                      primary: true,
                      onTap: controller.selectedOptionId == null
                          ? null
                          : onConfirm,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackArrow extends StatelessWidget {
  final VoidCallback onTap;

  const _BackArrow({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: const CustomPaint(size: Size(24, 24), painter: BackArrowPainter()),
  );
}

class _ProgressBar extends StatelessWidget {
  final int index;
  final int total;

  const _ProgressBar({required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    final widthFactor = total == 0 ? 0.0 : (index + 1) / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _BackArrow(onTap: () => Navigator.pop(context)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 6,
                color: AppColors.creamDeep,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: widthFactor,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.gold],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${index + 1} / $total',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: AppColors.fog,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class QuizUnitLabel extends StatelessWidget {
  final String caption;
  final String title;
  final double titleSize;

  const QuizUnitLabel({
    super.key,
    required this.caption,
    required this.title,
    this.titleSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: GoogleFonts.crimsonPro(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.fog,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.notoSerifTc(
              fontSize: titleSize,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

/// 深色題卡：有題幹就顯示題幹，聽力題（無題幹）留同高度空白；
/// 有音檔才顯示播放／慢速按鈕。
class _QuestionCard extends StatelessWidget {
  final String caption;
  final QuizFlowQuestion question;
  final void Function(double rate) onPlay;

  const _QuestionCard({
    required this.caption,
    required this.question,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final prompt = question.prompt;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                painter: TrukuWeavePainter(
                  color: AppColors.gold,
                  opacity: 1.0,
                  scale: 0.8,
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: Opacity(
              opacity: 0.6,
              child: TrukuDiamond(
                size: 26,
                color: AppColors.gold,
                strokeWidth: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caption,
                  style: GoogleFonts.notoSansTc(
                    fontSize: 11,
                    color: AppColors.gold,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                if (prompt == null)
                  const SizedBox(height: 76)
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          prompt,
                          style: GoogleFonts.crimsonPro(
                            fontSize: 44,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            color: AppColors.creamLight,
                            letterSpacing: 1.12,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (question.audioUrl != null) ...[
                  if (prompt != null) const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _PlayButton(onTap: () => onPlay(1.0))),
                      const SizedBox(width: 10),
                      _SlowButton(onTap: () => onPlay(0.6)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(
            size: const Size(20, 20),
            painter: SpeakerIconPainter(color: AppColors.ink),
          ),
          const SizedBox(width: 10),
          Text(
            '播放發音',
            style: GoogleFonts.notoSerifTc(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SlowButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SlowButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '慢速播放發音',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CustomPaint(size: Size(20, 20), painter: SlowIconPainter()),
            const SizedBox(width: 8),
            Text(
              '慢速',
              style: GoogleFonts.notoSerifTc(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 測驗畫面底部的主要／次要按鈕（需放在 Row 內，會自動 Expanded）。
class QuizBottomButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback? onTap;

  const QuizBottomButton({
    super.key,
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = primary && onTap == null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: primary
                ? (disabled ? AppColors.creamDeep : AppColors.primary)
                : AppColors.creamLight,
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
                color: primary
                    ? (disabled ? AppColors.fog : AppColors.creamLight)
                    : AppColors.inkSoft,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.cream : AppColors.creamLight,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: selected ? AppColors.primary : AppColors.creamDeep,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.crimsonPro(
            fontSize: 17,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
