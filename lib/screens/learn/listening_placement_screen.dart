// 聽力分級測驗作答畫面。UI 流程比照 listening_quiz_screen.dart，
// 差異：不需選 mode/level（12 題橫跨 4 級、mode 隨機混合）、submit 走
// PlacementService、完成後導向 PlacementResultScreen 顯示建議等級。
// 規格參考：Truku_backend docs/superpowers/specs/2026-08-17-quiz-listening-placement-design.md

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/audio_url.dart';
import '../../models/listening_models.dart';
import '../../models/placement_models.dart';
import '../../services/placement_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import 'placement_result_screen.dart';

enum _Phase { loading, error, quiz }

class ListeningPlacementScreen extends StatefulWidget {
  const ListeningPlacementScreen({super.key});

  @override
  State<ListeningPlacementScreen> createState() =>
      _ListeningPlacementScreenState();
}

class _ListeningPlacementScreenState extends State<ListeningPlacementScreen> {
  final _player = AudioPlayer();

  _Phase _phase = _Phase.loading;
  Object? _error;
  ListeningPlacementSession? _session;
  int _currentIndex = 0;
  int? _selectedOptionId;
  final Map<String, int> _answeredOptions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    try {
      final session = await PlacementService.startListeningPlacement();

      _answeredOptions.clear();
      for (final q in session.questions) {
        if (q.selectedOptionId != null) {
          _answeredOptions[q.questionId] = q.selectedOptionId!;
        }
      }
      final firstUnanswered =
          session.questions.indexWhere((q) => q.selectedOptionId == null);
      final startIndex = firstUnanswered == -1
          ? session.questions.length - 1
          : firstUnanswered;

      setState(() {
        _session = session;
        _currentIndex = startIndex;
        _selectedOptionId =
            _answeredOptions[session.questions[startIndex].questionId];
        _phase = _Phase.quiz;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _phase = _Phase.error;
      });
    }
  }

  ListeningQuestion get _currentQuestion => _session!.questions[_currentIndex];

  Future<void> _play({double rate = 1.0}) async {
    final url = _currentQuestion.promptAudioUrl;
    if (url == null) return;
    try {
      await _player.stop();
      await _player.setPlaybackRate(rate);
      await _player.play(UrlSource(sanitizeAudioUrl(url)));
    } catch (e) {
      debugPrint('ListeningPlacementScreen._play failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('發音播放失敗，請稍後再試')),
      );
    }
  }

  void _selectOption(int optionId) {
    setState(() => _selectedOptionId = optionId);
    final questionId = _currentQuestion.questionId;
    _answeredOptions[questionId] = optionId;
    unawaited(_saveAnswer(questionId, optionId));
  }

  Future<void> _saveAnswer(String questionId, int optionId) async {
    try {
      await PlacementService.answerListeningPlacement(
        sessionId: _session!.sessionId,
        questionId: questionId,
        selectedOptionId: optionId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('儲存答案失敗，請稍後再試')),
      );
    }
  }

  Future<void> _confirmAndNext() async {
    if (_selectedOptionId == null) return;

    if (_currentIndex < _session!.questions.length - 1) {
      final nextIndex = _currentIndex + 1;
      setState(() {
        _currentIndex = nextIndex;
        _selectedOptionId = _answeredOptions[_currentQuestion.questionId];
      });
      return;
    }

    final unansweredIndex = _session!.questions
        .indexWhere((q) => !_answeredOptions.containsKey(q.questionId));
    if (unansweredIndex != -1) {
      setState(() {
        _currentIndex = unansweredIndex;
        _selectedOptionId =
            _answeredOptions[_session!.questions[unansweredIndex].questionId];
      });
      return;
    }

    setState(() => _phase = _Phase.loading);
    try {
      final answers = _session!.questions
          .map((q) => PlacementAnswer(
                questionId: q.questionId,
                selectedOptionId: _answeredOptions[q.questionId]!,
              ))
          .toList();
      final result = await PlacementService.submitListeningPlacement(
        _session!.sessionId,
        answers,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PlacementResultScreen(
            result: result,
            title: '聽力分級測驗',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e;
        _phase = _Phase.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        bottom: false,
        child: Builder(builder: (context) {
          switch (_phase) {
            case _Phase.loading:
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            case _Phase.error:
              return _buildError();
            case _Phase.quiz:
              return _buildQuiz();
          }
        }),
      ),
    );
  }

  bool get _isUnauthorized => isAuthError(_error);

  bool get _isAlreadyPlaced =>
      _error is ApiException && (_error as ApiException).code == 'ALREADY_PLACED';

  Widget _buildError() {
    final message = _isUnauthorized
        ? '請先登入'
        : (_isAlreadyPlaced ? '你已經完成過分級測驗了' : '載入失敗，請稍後再試');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CustomPaint(
                  size: const Size(24, 24),
                  painter: const BackArrowPainter(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerifTc(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            if (!_isAlreadyPlaced) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.creamLight,
                ),
                child: const Text('重試'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuiz() {
    final total = _session!.questions.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressBar(total),
          _buildUnitLabel(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: [
                _buildMainCard(),
                const SizedBox(height: 14),
                _buildOptions(),
                const SizedBox(height: 16),
                _buildBottomButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int total) {
    final widthFactor = total == 0 ? 0.0 : (_currentIndex + 1) / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: CustomPaint(
              size: const Size(24, 24),
              painter: const BackArrowPainter(),
            ),
          ),
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
            '${_currentIndex + 1} / $total',
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

  Widget _buildUnitLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PLACEMENT · 聽力分級測驗',
            style: GoogleFonts.crimsonPro(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.fog,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '橫跨四個等級，找出最適合你的起點',
            style: GoogleFonts.notoSerifTc(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard() {
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
                  '聆聽 · 選出正確答案',
                  style: GoogleFonts.notoSansTc(
                    fontSize: 11,
                    color: AppColors.gold,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 76),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _play(),
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
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      button: true,
                      label: '慢速播放發音',
                      child: GestureDetector(
                        onTap: () => _play(rate: 0.6),
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
                              const CustomPaint(
                                size: Size(20, 20),
                                painter: SlowIconPainter(),
                              ),
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

  Widget _buildOptions() {
    final question = _currentQuestion;
    return Column(
      children: [
        for (final option in question.options) ...[
          _OptionTile(
            label: option.text,
            selected: option.optionId == _selectedOptionId,
            onTap: () => _selectOption(option.optionId),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildBottomButtons() {
    final isLast = _currentIndex == _session!.questions.length - 1;
    return Row(
      children: [
        _buildBottomButton(
          label: isLast ? '完成測驗 →' : '下一題 →',
          primary: true,
          onTap: _selectedOptionId == null ? null : _confirmAndNext,
        ),
      ],
    );
  }

  Widget _buildBottomButton({
    required String label,
    required bool primary,
    required VoidCallback? onTap,
  }) {
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
