import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/quiz_models.dart';
import '../../services/learn_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';

enum _Phase { loading, error, quiz, result }

class LessonCardScreen extends StatefulWidget {
  final String level;

  const LessonCardScreen({super.key, required this.level});

  @override
  State<LessonCardScreen> createState() => _LessonCardScreenState();
}

class _LessonCardScreenState extends State<LessonCardScreen> {
  final _player = AudioPlayer();

  _Phase _phase = _Phase.loading;
  Object? _error;
  QuizSession? _session;
  int _currentIndex = 0;
  int? _selectedOptionId;
  final List<QuizAnswer> _answers = [];
  QuizResult? _result;

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
      final session = await LearnService.startQuiz(widget.level);
      setState(() {
        _session = session;
        _currentIndex = 0;
        _selectedOptionId = null;
        _answers.clear();
        _result = null;
        _phase = _Phase.quiz;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _phase = _Phase.error;
      });
    }
  }

  QuizQuestion get _currentQuestion => _session!.questions[_currentIndex];

  Future<void> _play({double rate = 1.0}) async {
    final url = _currentQuestion.promptAudioUrl;
    if (url == null) return;
    await _player.stop();
    await _player.setPlaybackRate(rate);
    await _player.play(UrlSource(url));
  }

  void _selectOption(int optionId) {
    setState(() => _selectedOptionId = optionId);
  }

  Future<void> _confirmAndNext() async {
    final selected = _selectedOptionId;
    if (selected == null) return;
    _answers.add(QuizAnswer(
      questionId: _currentQuestion.questionId,
      selectedOptionId: selected,
    ));

    if (_currentIndex < _session!.questions.length - 1) {
      setState(() {
        _currentIndex += 1;
        _selectedOptionId = null;
      });
      return;
    }

    setState(() => _phase = _Phase.loading);
    try {
      final result = await LearnService.submitQuiz(_session!.sessionId, _answers);
      setState(() {
        _result = result;
        _phase = _Phase.result;
      });
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
            case _Phase.result:
              return _buildResult();
            case _Phase.quiz:
              return _buildQuiz();
          }
        }),
      ),
    );
  }

  bool get _isUnauthorized =>
      _error is ApiException && (_error as ApiException).isUnauthorized;

  Widget _buildError() {
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
                  painter: _BackArrowPainter(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isUnauthorized ? '請先登入' : '載入失敗，請稍後再試',
              style: GoogleFonts.notoSerifTc(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
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
        ),
      ),
    );
  }

  Widget _buildResult() {
    final result = _result!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.level} · 測驗完成',
              style: GoogleFonts.crimsonPro(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.fog,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${result.score} / ${result.total}',
              style: GoogleFonts.notoSerifTc(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBottomButton(
                  label: '重新測驗',
                  primary: false,
                  onTap: _load,
                ),
                const SizedBox(width: 10),
                _buildBottomButton(
                  label: '返回 →',
                  primary: true,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
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
              painter: _BackArrowPainter(),
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
            'LEVEL · ${widget.level.toUpperCase()}',
            style: GoogleFonts.crimsonPro(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.fog,
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.level,
            style: GoogleFonts.notoSerifTc(
              fontSize: 18,
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
    final question = _currentQuestion;
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
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        question.prompt,
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
                const SizedBox(height: 20),
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
                                painter: _SpeakerIconPainter(color: AppColors.ink),
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
                    GestureDetector(
                      onTap: () => _play(rate: 0.6),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.gold, width: 1),
                        ),
                        child: Center(
                          child: CustomPaint(
                            size: const Size(24, 24),
                            painter: _SlowIconPainter(),
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
            label: option.displayText(question.direction),
            selected: option.id == _selectedOptionId,
            onTap: () => _selectOption(option.id),
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
          label: '再聽一次',
          primary: false,
          onTap: () => _play(),
        ),
        const SizedBox(width: 10),
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

// ── OptionTile ────────────────────────────────────────────────────────────────

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

// ── Painters ──────────────────────────────────────────────────────────────────

class _BackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 15 / 24, h * 4 / 24)
      ..lineTo(w * 7 / 24, h * 12 / 24)
      ..lineTo(w * 15 / 24, h * 20 / 24);

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_BackArrowPainter old) => false;
}

class _SpeakerIconPainter extends CustomPainter {
  final Color color;

  const _SpeakerIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final body = Path()
      ..moveTo(w * 11 / 20, h * 5 / 20)
      ..lineTo(w * 6 / 20, h * 8 / 20)
      ..lineTo(w * 3 / 20, h * 8 / 20)
      ..lineTo(w * 3 / 20, h * 12 / 20)
      ..lineTo(w * 6 / 20, h * 12 / 20)
      ..lineTo(w * 11 / 20, h * 15 / 20)
      ..close();
    canvas.drawPath(body, paint);

    final arc1 = Path()
      ..moveTo(w * 13 / 20, h * 8 / 20)
      ..quadraticBezierTo(w * 15 / 20, h * 10 / 20, w * 13 / 20, h * 12 / 20);
    canvas.drawPath(arc1, paint);

    final arc2 = Path()
      ..moveTo(w * 15 / 20, h * 6 / 20)
      ..quadraticBezierTo(w * 18 / 20, h * 10 / 20, w * 15 / 20, h * 14 / 20);
    canvas.drawPath(arc2, paint);
  }

  @override
  bool shouldRepaint(_SpeakerIconPainter old) => old.color != color;
}

class _SlowIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawCircle(
      Offset(w * 12 / 24, h * 13 / 24),
      w * 7 / 24,
      paint,
    );

    final hands = Path()
      ..moveTo(w * 12 / 24, h * 9 / 24)
      ..lineTo(w * 12 / 24, h * 13 / 24)
      ..lineTo(w * 14 / 24, h * 15 / 24);
    canvas.drawPath(hands, paint);

    canvas.drawLine(
      Offset(w * 9 / 24, h * 3 / 24),
      Offset(w * 15 / 24, h * 3 / 24),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SlowIconPainter old) => false;
}
