// 個人資料「其他」→「關於語見太魯閣」。純靜態內容，不打 API。
//
// 版面刻意不做成一整面純文字：品牌故事「織語者」的核心意象是「把快消失的
// 語言、文化、記憶重新編織在一起」，所以中段用三股色帶交疊象徵編織過程，
// 收束到一枚太魯閣菱形織紋徽章；下段三張功能卡對應 App 實際的三個核心
// 模組（學習／文化影音／論壇），把「使命」直接錨回使用者已經在用的功能。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/truku_painters.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) => _buildScaffold(context, seniorModeController.enabled),
  );

  Widget _buildScaffold(BuildContext context, bool seniorMode) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero(context, seniorMode)),
          SliverToBoxAdapter(child: _buildBody(seniorMode)),
        ],
      ),
    );
  }

  // ── 頂部視覺 ──────────────────────────────────────────────────
  Widget _buildHero(BuildContext context, bool seniorMode) {
    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.midnight, AppColors.primaryDeep],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: TrukuMountainsPainter(opacity: 0.5)),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.16,
              child: CustomPaint(
                painter: TrukuWeavePainter(color: AppColors.gold, scale: 0.9),
              ),
            ),
          ),
          Positioned(
            top: 52,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: seniorMode ? 50 : 38,
                height: seniorMode ? 50 : 38,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.creamLight.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: AppColors.creamLight,
                  size: seniorMode ? 26 : 18,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _weaveBadge(size: seniorMode ? 64 : 52),
                const SizedBox(height: 14),
                Text(
                  '語見・太魯閣',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: seniorMode ? 28 : 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.creamLight,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'QITA SDA TRUKU',
                  style: GoogleFonts.crimsonPro(
                    fontSize: seniorMode ? 14 : 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.gold,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 菱形織紋徽章 — puniri 祖靈之眼縮圖，兼作「織語者」品牌識別。
  Widget _weaveBadge({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.midnightSoft,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.5),
      ),
      child: ClipOval(
        child: CustomPaint(painter: TrukuWeavePainter(color: AppColors.gold, opacity: 0.9, scale: 0.5)),
      ),
    );
  }

  // ── 內文 ──────────────────────────────────────────────────────
  Widget _buildBody(bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('我們的使命', seniorMode),
          const SizedBox(height: 10),
          Text(
            '近年來，族語與文化傳承逐漸面臨世代斷層。我們希望透過數位科技，'
            '打造一個專屬於太魯閣族的學習平台，透過互動學習族語、文化影音與'
            '社群交流，降低族語學習門檻，讓語言與文化不只被保存，更能持續'
            '被使用與傳承。',
            style: TextStyle(
              fontSize: seniorMode ? AppTypography.title : AppTypography.bodyLarge,
              color: AppColors.inkSoft,
              height: 1.9,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 32),
          _buildWeaveStory(seniorMode),
          const SizedBox(height: 32),
          _sectionLabel('三個入口，一起編織', seniorMode),
          const SizedBox(height: 14),
          _buildPillars(seniorMode),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool seniorMode) => Row(
    children: [
      Container(width: 4, height: seniorMode ? 22 : 18, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(
        text,
        style: GoogleFonts.notoSerifTc(
          fontSize: seniorMode ? AppTypography.headline : AppTypography.title,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          letterSpacing: 1.0,
        ),
      ),
    ],
  );

  /// 品牌故事「織語者」— 語言／文化／記憶三股色帶交疊，收束到織紋徽章，
  /// 具象化「重新編織」這個核心意象，而不是單純一段文字。
  Widget _buildWeaveStory(bool seniorMode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.midnight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '品牌故事',
                style: GoogleFonts.crimsonPro(
                  fontSize: seniorMode ? 15 : 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.gold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: AppColors.gold.withValues(alpha: 0.3))),
            ],
          ),
          const SizedBox(height: 16),
          _buildStrands(seniorMode),
          const SizedBox(height: 18),
          Text(
            '「織語者」',
            style: GoogleFonts.notoSerifTc(
              fontSize: seniorMode ? 24 : 19,
              fontWeight: FontWeight.w700,
              color: AppColors.creamLight,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '象徵我們要重新把快消失的語言、文化、記憶重新編織在一起。'
            '以太魯閣族為起點，透過數位專屬平台，讓這些族語不僅被保存，'
            '更能透過互動與交流，在每個世代間繼續傳承。',
            style: TextStyle(
              fontSize: seniorMode ? AppTypography.title : AppTypography.bodyLarge,
              color: AppColors.mist,
              height: 1.9,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// 三股交疊色帶：語言 / 文化 / 記憶，垂直位移＋輕微旋轉營造交織感，
  /// 匯聚成中央的織紋徽章。
  Widget _buildStrands(bool seniorMode) {
    const strands = [
      (label: '語言', icon: Icons.translate, color: AppColors.primaryLight),
      (label: '文化', icon: Icons.temple_buddhist_outlined, color: AppColors.moss),
      (label: '記憶', icon: Icons.auto_stories_outlined, color: AppColors.gold),
    ];
    return SizedBox(
      height: seniorMode ? 108 : 92,
      child: Row(
        children: [
          for (var i = 0; i < strands.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Transform.translate(
                offset: Offset(0, i.isOdd ? -10 : 10),
                child: Transform.rotate(
                  angle: (i - 1) * 0.05,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: strands[i].color.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: strands[i].color.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(strands[i].icon, color: strands[i].color, size: seniorMode ? 26 : 20),
                        const SizedBox(height: 6),
                        Text(
                          strands[i].label,
                          style: TextStyle(
                            fontSize: seniorMode ? AppTypography.subtitle : AppTypography.body,
                            fontWeight: FontWeight.w600,
                            color: AppColors.creamLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 使命段落提到的三個入口，對應 App 實際的學習／文化影音／論壇模組。
  Widget _buildPillars(bool seniorMode) {
    const pillars = [
      (
        icon: Icons.menu_book_outlined,
        title: '互動學習族語',
        desc: '從發音、詞彙到測驗，一步步降低入門門檻。',
        color: AppColors.primary,
      ),
      (
        icon: Icons.play_circle_outline,
        title: '文化影音',
        desc: '影像與文章保存部落記憶，隨時回看。',
        color: AppColors.moss,
      ),
      (
        icon: Icons.forum_outlined,
        title: '社群交流',
        desc: '論壇與活動串起世代，讓語言持續被使用。',
        color: AppColors.goldDeep,
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < pillars.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.creamDeep),
            ),
            child: Row(
              children: [
                Container(
                  width: seniorMode ? 52 : 44,
                  height: seniorMode ? 52 : 44,
                  decoration: BoxDecoration(
                    color: pillars[i].color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    pillars[i].icon,
                    color: pillars[i].color,
                    size: seniorMode ? 28 : 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pillars[i].title,
                        style: GoogleFonts.notoSerifTc(
                          fontSize: seniorMode ? AppTypography.title : AppTypography.bodyLarge,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pillars[i].desc,
                        style: TextStyle(
                          fontSize: seniorMode ? AppTypography.subtitle : AppTypography.body,
                          color: AppColors.inkSoft,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
