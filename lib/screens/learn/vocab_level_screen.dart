import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/level_info.dart';
import '../../services/learn_service.dart';
import '../../shared/widgets/truku_widgets.dart';
import 'lesson_card_screen.dart';

class VocabLevelScreen extends StatefulWidget {
  const VocabLevelScreen({super.key});

  @override
  State<VocabLevelScreen> createState() => _VocabLevelScreenState();
}

class _VocabLevelScreenState extends State<VocabLevelScreen> {
  late Future<List<LevelInfo>> _levelsFuture;

  @override
  void initState() {
    super.initState();
    _levelsFuture = LearnService.fetchLevels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        child: FutureBuilder<List<LevelInfo>>(
          future: _levelsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (snapshot.hasError) {
              return _buildError(snapshot.error);
            }
            final levels = snapshot.data ?? const [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildSectionLabel('選擇級別'),
                const SizedBox(height: 10),
                if (levels.isEmpty)
                  Text(
                    '目前沒有可學習的級別',
                    style: GoogleFonts.notoSansTc(fontSize: 14, color: AppColors.fog),
                  )
                else
                  for (int i = 0; i < levels.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _LevelRow(level: levels[i]),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: AppColors.ink),
        ),
        const SizedBox(width: 12),
        Text(
          '單字測驗',
          style: GoogleFonts.notoSerifTc(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        const TrukuDiamond(size: 12, color: AppColors.primary, filled: true),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.notoSerifTc(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildError(Object? error) {
    final isUnauthorized = error is ApiException && error.isUnauthorized;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          isUnauthorized ? '請先登入' : '載入失敗，請稍後再試',
          style: GoogleFonts.notoSerifTc(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  final LevelInfo level;

  const _LevelRow({required this.level});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LessonCardScreen(level: level.level)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.creamDeep, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildDiamond(),
            const SizedBox(width: 14),
            Expanded(child: _buildTextArea()),
            const TrukuChevron(color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildDiamond() {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(52, 52),
            painter: const _LevelDiamondPainter(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          level.level,
          style: GoogleFonts.notoSerifTc(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            letterSpacing: 0.85,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${level.wordCount} 個單字',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.fog,
            letterSpacing: 0.55,
          ),
        ),
      ],
    );
  }
}

class _LevelDiamondPainter extends CustomPainter {
  const _LevelDiamondPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 26 / 52, h * 4 / 52)
      ..lineTo(w * 48 / 52, h * 26 / 52)
      ..lineTo(w * 26 / 52, h * 48 / 52)
      ..lineTo(w * 4 / 52, h * 26 / 52)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LevelDiamondPainter old) => false;
}
