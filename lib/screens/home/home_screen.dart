import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../models/shop_item.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/truku_widgets.dart';
import '../../shared/widgets/mode_card.dart';
import '../../shared/widgets/millet_coin_icon.dart';
import '../../shared/widgets/user_avatar.dart';
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

// ModeData.key → MainContainer 的分頁 index（見 lib/main.dart 的 IndexedStack 順序）
const Map<String, int> _modeTabIndex = {
  'learn': 1,
  'culture': 2,
  'video': 3, // 視訊功能在「交流」分頁（CommunityScreen）內
  'plaza': 4,
  'event': 5,
};

class HomeScreen extends StatelessWidget {
  final VoidCallback? onShowProfile;
  final void Function(int tabIndex)? onNavigateToTab;
  final String? displayName;
  final int? millet;
  final String? avatarId;
  final String? avatarUrl;
  final Map<String, ShopItem> itemCatalogById;
  final bool checkedInToday;
  final int checkinStreak;
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
    this.onCheckin,
  });

  void _onModeTap(ModeData mode) {
    final index = _modeTabIndex[mode.key];
    if (index != null) onNavigateToTab?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.creamLight,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ① 頂部色條（6px）
          SizedBox(
            height: 6,
            child: Stack(
              fit: StackFit.expand,
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
              ],
            ),
          ),

          // ② 標頭 + ③ 今日進度卡
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo（點擊開啟「關於語見太魯閣」）
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutAppScreen()),
                    ),
                    child: Image.asset(
                      'assets/icon/logo.png',
                      width: 120,
                      height: 120,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 問候列 + Avatar
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          Text(
                            '${displayName ?? 'Yudaw'}，今天學什麼？',
                            style: GoogleFonts.notoSerifTc(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onShowProfile,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          border: Border.all(color: AppColors.gold, width: 2),
                        ),
                        child: ClipOval(
                          child: UserAvatar(
                            avatarId: avatarId,
                            avatarUrl: avatarUrl,
                            itemCatalogById: itemCatalogById,
                            size: 48,
                            fallbackIconColor: AppColors.creamLight,
                          ),
                        ),
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
                  onCheckin: onCheckin,
                ),
              ],
            ),
          ),

          // ④ 模式卡格（第一張全寬，後四張兩欄）
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
            child: Column(
              children: [
                ModeCard(
                  mode: _modes[3],
                  large: true,
                  onTap: () => _onModeTap(_modes[3]),
                ),
                const SizedBox(height: 12),
                Row(
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
                const SizedBox(height: 12),
                Row(
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
  final VoidCallback? onCheckin;

  const _TodayProgressCard({
    this.millet,
    this.checkedInToday = false,
    this.checkinStreak = 0,
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
                            const MilletCoinIcon(size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${millet ?? 0}',
                              style: GoogleFonts.notoSerifTc(
                                fontSize: 13,
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

                // 「連續學習 12 天」
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      height: 1.3,
                    ),
                    children: [
                      const TextSpan(text: '連續學習 '),
                      TextSpan(
                        text: '12',
                        style: const TextStyle(color: AppColors.gold),
                      ),
                      const TextSpan(text: ' 天'),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 七格進度條（5 金色 + 2 淡白）
                Row(
                  children: List.generate(
                    7,
                    (i) => Expanded(
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.only(right: i < 6 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: i < 5
                              ? AppColors.gold
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // 說明文字
                Opacity(
                  opacity: 0.85,
                  child: Text(
                    '本週目標 5/7 · 完成下個單元再得 +10 小米幣',
                    style: GoogleFonts.notoSansTc(
                      fontSize: 12,
                      color: AppColors.creamLight,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 每日簽到
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        checkinStreak > 0
                            ? '每日簽到 +50 · 已連續 $checkinStreak 天'
                            : '每日簽到 +50 小米幣',
                        style: GoogleFonts.notoSansTc(
                          fontSize: 12,
                          color: AppColors.creamLight.withValues(alpha: 0.85),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: checkedInToday ? null : onCheckin,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: checkedInToday
                                ? AppColors.gold.withValues(alpha: 0.4)
                                : AppColors.gold,
                          ),
                        ),
                        child: Text(
                          checkedInToday ? '已簽到' : '立即簽到',
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: checkedInToday
                                ? AppColors.gold.withValues(alpha: 0.4)
                                : AppColors.gold,
                            letterSpacing: 1,
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
}
