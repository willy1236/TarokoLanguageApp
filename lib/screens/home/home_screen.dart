import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_density.dart';
import '../../core/constants/app_typography.dart';
import '../../models/shop_item.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import '../../shared/widgets/mode_card.dart';
import '../../shared/widgets/millet_coin_icon.dart';
import '../../shared/widgets/senior_mode_toggle_icon.dart';
import '../profile/about_app_screen.dart';
import '../shop/shop_screen.dart';

// 五張模式卡資料（依設計稿）
const List<ModeData> _modes = [
  ModeData(
    key: 'learn',
    zh: '族語學習',
    truku: 'Kari Truku',
    sub: '一天一句·從問候開始',
    bg: AppColors.primary,
    fg: AppColors.creamLight,
    accent: AppColors.gold,
    icon: 'lesson',
  ),
  ModeData(
    key: 'culture',
    zh: '文化影音',
    truku: 'Lnglungan',
    sub: '部落故事與傳統知識',
    bg: AppColors.midnight,
    fg: AppColors.creamLight,
    accent: AppColors.gold,
    icon: 'film',
  ),
  ModeData(
    key: 'video',
    zh: '視訊',
    truku: 'Pgkala',
    sub: '和 rudan 一對一',
    bg: AppColors.moss,
    fg: AppColors.creamLight,
    accent: AppColors.gold,
    icon: 'comm',
  ),
  ModeData(
    key: 'plaza',
    zh: '廣場',
    truku: 'Alang',
    sub: '族人的動態',
    bg: AppColors.creamLight,
    fg: AppColors.primary,
    accent: AppColors.primary,
    icon: 'plaza',
  ),
  ModeData(
    key: 'event',
    zh: '活動',
    truku: 'Smratuc',
    sub: '部落聚會與走讀',
    bg: AppColors.gold,
    fg: AppColors.ink,
    accent: AppColors.primary,
    icon: 'event',
  ),
];

// ModeData.key → MainContainer 的分頁 index（見 lib/main.dart 的 IndexedStack 順序）。
// learn/culture 共用「學習影音」分頁、plaza/event 共用「廣場活動」分頁、
// 視訊配對在「我的」分頁內，落在哪個子分頁由 _modeSubTab 決定。
const Map<String, int> _modeTabIndex = {
  'learn': 1,
  'culture': 1,
  'plaza': 2,
  'event': 2,
  'video': 4,
};

// learn/culture 的子分頁（LearnCultureScreen: 0=學習,1=影音）、
// plaza/event 的子分頁（PlazaEventScreen: 0=廣場,1=活動）、
// video 的子分頁（ProfileVideoScreen: 0=個人資料,1=視訊配對）。
const Map<String, int> _modeSubTab = {
  'learn': 0,
  'culture': 1,
  'plaza': 0,
  'event': 1,
  'video': 1,
};

class HomeScreen extends StatelessWidget {
  final VoidCallback? onShowProfile;
  final void Function(int tabIndex, {int? subTab})? onNavigateToTab;
  final String? displayName;
  final int? millet;
  final String? avatarId;
  final String? avatarUrl;
  final Map<String, ShopItem> itemCatalogById;
  final bool checkedInToday;
  final int checkinStreak;
  final int weeklyCheckinCount;
  final bool weeklyBonusEarned;
  final VoidCallback? onCheckin;

  const HomeScreen({
    super.key,
    this.onShowProfile,
    this.onNavigateToTab,
    this.displayName,
    this.millet,
    this.avatarId,
    this.avatarUrl,
    this.itemCatalogById = const {},
    this.checkedInToday = false,
    this.checkinStreak = 0,
    this.weeklyCheckinCount = 0,
    this.weeklyBonusEarned = false,
    this.onCheckin,
  });

  void _onModeTap(ModeData mode) {
    final index = _modeTabIndex[mode.key];
    if (index != null) {
      onNavigateToTab?.call(index, subTab: _modeSubTab[mode.key]);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) => _buildPage(context, seniorModeController.enabled),
  );

  // 一般模式首頁不可捲動，模式卡吃掉剩餘高度；精簡模式字放大後可能塞不下，
  // 2x2 模式卡仍吃滿剩餘高度，但畫面太矮時整頁可捲動。
  Widget _buildPage(BuildContext context, bool seniorMode) {
    return ColoredBox(
      color: AppColors.creamLight,
      child: SafeArea(
        bottom: false,
        child: seniorMode
            ? CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopStrip(),
                        _buildHeader(context, seniorMode),
                      ],
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildSeniorModeGrid(),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildTopStrip(),
                  _buildHeader(context, seniorMode),
                  Expanded(child: _buildModeGrid()),
                ],
              ),
      ),
    );
  }

  // 精簡模式只列 AppDensity.maxHomeSections 張卡，排成 2x2；「族語學習」省略，
  // 仍可從導航列「學習影音」進入。
  static const _seniorModeKeys = ['plaza', 'event', 'video', 'culture'];

  Widget _buildSeniorModeGrid() {
    final modes = [
      for (final key in _seniorModeKeys.take(AppDensity.maxHomeSections))
        _modes.firstWhere((m) => m.key == key),
    ];
    Widget cell(int i) => Expanded(
      child: i < modes.length
          ? ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 120),
              child: ModeCard(
                mode: modes[i],
                seniorMode: true,
                onTap: () => _onModeTap(modes[i]),
              ),
            )
          : const SizedBox.shrink(),
    );
    Widget row(int start) => Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [cell(start), const SizedBox(width: 12), cell(start + 1)],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(children: [row(0), const SizedBox(height: 12), row(2)]),
    );
  }

  // ① 頂部色條（6px）
  Widget _buildTopStrip() {
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          const ColoredBox(color: AppColors.primary),
          Opacity(
            opacity: 0.4,
            child: CustomPaint(
              painter: const TrukuWeavePainter(
                color: AppColors.gold,
                opacity: 1.0,
                scale: 0.4,
              ),
            ),
          ),
          // 上方對稱菱形裝飾，呼應下方今日進度卡右上角的菱形
          Positioned(
            top: -14,
            right: 16,
            child: Opacity(
              opacity: 0.18,
              child: TrukuDiamond(
                size: 40,
                color: AppColors.gold,
                strokeWidth: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ② 標頭 + ③ 今日進度卡
  Widget _buildHeader(BuildContext context, bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 問候列 + Logo（取代原本的個人資料頭像）
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 精簡模式隱藏族語問候眉標，只留中文主標。
                    if (!seniorMode) ...[
                      Text(
                        'Embiyax su hug · 你好',
                        style: GoogleFonts.crimsonPro(
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                          color: AppColors.fog,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      // 精簡模式字大，刻意在逗號後換行，避免從字中間斷開。
                      '${displayName ?? 'Yudaw'}，${seniorMode ? '\n' : ''}今天學什麼？',
                      style: GoogleFonts.notoSerifTc(
                        fontSize: seniorMode ? 28 : 24,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SeniorModeToggleIcon(),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutAppScreen()),
                ),
                child: Image.asset(
                  'assets/icon/logo.png',
                  width: 48,
                  height: 48,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ③ 今日進度卡（暗色）
          _TodayProgressCard(
            millet: millet,
            checkedInToday: checkedInToday,
            checkinStreak: checkinStreak,
            weeklyCheckinCount: weeklyCheckinCount,
            weeklyBonusEarned: weeklyBonusEarned,
            seniorMode: seniorMode,
            onCheckin: onCheckin,
          ),
        ],
      ),
    );
  }

  // ④ 模式卡格（第一張全寬，後四張兩欄）－ 吃掉剩餘高度，首頁不可捲動
  // Scaffold(extendBody: false) 已經把導覽列的高度從 body 可用空間中扣除，
  // 這裡不需要再手動預留底部間距。
  Widget _buildModeGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        children: [
          Expanded(
            child: ModeCard(
              mode: _modes[3],
              large: true,
              onTap: () => _onModeTap(_modes[3]),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ModeCard(
                    mode: _modes[1],
                    onTap: () => _onModeTap(_modes[1]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ModeCard(
                    mode: _modes[2],
                    onTap: () => _onModeTap(_modes[2]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ModeCard(
                    mode: _modes[0],
                    onTap: () => _onModeTap(_modes[0]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ModeCard(
                    mode: _modes[4],
                    onTap: () => _onModeTap(_modes[4]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 今日進度卡 ──────────────────────────────────────────────────────────────

class _TodayProgressCard extends StatelessWidget {
  final int? millet;
  final bool checkedInToday;
  final int checkinStreak;
  final int weeklyCheckinCount;
  final bool weeklyBonusEarned;
  final bool seniorMode;
  final VoidCallback? onCheckin;

  const _TodayProgressCard({
    this.millet,
    this.checkedInToday = false,
    this.checkinStreak = 0,
    this.weeklyCheckinCount = 0,
    this.weeklyBonusEarned = false,
    this.seniorMode = false,
    this.onCheckin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          // 右上角菱形背景裝飾
          Positioned(
            right: -10,
            top: -10,
            child: Opacity(
              opacity: 0.18,
              child: TrukuDiamond(
                size: 120,
                color: AppColors.gold,
                strokeWidth: 1.5,
              ),
            ),
          ),

          // 卡片內容
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 標籤列 + 小米幣 chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 精簡模式隱藏英文／族語眉標，小米幣 chip 仍靠右。
                    if (seniorMode)
                      const SizedBox.shrink()
                    else
                      Text(
                        'TODAY · SAYANG',
                        style: GoogleFonts.crimsonPro(
                          fontStyle: FontStyle.italic,
                          fontSize: 11,
                          color: AppColors.gold,
                          letterSpacing: 3.2,
                        ),
                      ),
                    // 小米幣 chip
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ShopScreen(),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.18),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MilletCoinIcon(size: seniorMode ? 24 : 18),
                            const SizedBox(width: 4),
                            Text(
                              '${millet ?? 0}',
                              style: GoogleFonts.notoSerifTc(
                                fontSize: seniorMode ? AppTypography.title : 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // 「本週簽到 N/7 天」
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.notoSerifTc(
                      fontSize: seniorMode ? 26 : 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      height: 1.3,
                    ),
                    children: [
                      const TextSpan(text: '本週簽到 '),
                      TextSpan(
                        text: '$weeklyCheckinCount',
                        style: const TextStyle(color: AppColors.gold),
                      ),
                      const TextSpan(text: '/7 天'),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 七格進度條：亮起的格數 = 本週已簽到天數（非星期幾）
                Row(
                  children: List.generate(
                    7,
                    (i) => Expanded(
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: i < weeklyCheckinCount
                              ? AppColors.gold
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),

                // 說明文字：精簡模式省略週全勤獎勵細節，只留簽到主流程。
                if (!seniorMode) ...[
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: 0.85,
                    child: Text(
                      weeklyBonusEarned
                          ? '本週已集滿 7 天 · 已獲得 +50 小米幣'
                          : '再簽到 ${7 - weeklyCheckinCount} 天，本週集滿再得 +50 小米幣',
                      style: GoogleFonts.notoSansTc(
                        fontSize: 12,
                        color: AppColors.creamLight,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // 每日簽到：精簡模式字大，說明與按鈕改上下排列避免折行。
                if (seniorMode) ...[
                  _buildCheckinText(),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: _buildCheckinButton(),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(child: _buildCheckinText()),
                      const SizedBox(width: 8),
                      _buildCheckinButton(),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinText() {
    return Text(
      checkinStreak > 0 ? '每日簽到 +50 · 已連續 $checkinStreak 天' : '每日簽到 +50 小米幣',
      style: GoogleFonts.notoSansTc(
        fontSize: seniorMode ? AppTypography.subtitle : 12,
        color: AppColors.creamLight.withValues(alpha: 0.85),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCheckinButton() {
    return GestureDetector(
      onTap: checkedInToday ? null : onCheckin,
      child: Container(
        constraints: BoxConstraints(minHeight: seniorMode ? 48 : 0),
        alignment: seniorMode ? Alignment.center : null,
        padding: EdgeInsets.symmetric(
          horizontal: seniorMode ? 18 : 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(seniorMode ? 24 : 16),
          border: Border.all(
            color: checkedInToday
                ? AppColors.gold.withValues(alpha: 0.4)
                : AppColors.gold,
          ),
        ),
        child: Text(
          checkedInToday ? '已簽到' : '立即簽到',
          style: GoogleFonts.notoSerifTc(
            fontSize: seniorMode ? AppTypography.title : 12,
            fontWeight: FontWeight.w600,
            color: checkedInToday
                ? AppColors.gold.withValues(alpha: 0.4)
                : AppColors.gold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
