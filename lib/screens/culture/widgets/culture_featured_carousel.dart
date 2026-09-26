// 文化頁「本週精選」輪播卡：取代原本滿版 hero。內縮圓角卡、左右滑、自動輪播，
// 高度固定，不會因分頁或內容不同而推動下方版面。

import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/widgets/truku_painters.dart';

class CultureFeaturedItem {
  final String? imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const CultureFeaturedItem({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class CultureFeaturedCarousel extends StatefulWidget {
  /// null 代表載入中；空清單代表沒有精選，整塊不顯示。
  final List<CultureFeaturedItem>? items;
  final bool seniorMode;

  /// 疊在卡片右上角、不隨翻頁移動的元件（搜尋鈕）；沒有精選時改單獨靠右顯示。
  final Widget? action;

  /// 輪播所在分頁是否正顯示在畫面上。為 false 時停止自動翻頁、停在目前這張；
  /// 回到 true 時從這張重新計時。父層在 IndexedStack 裡一直活著，不能靠
  /// TickerMode 判斷（IndexedStack 不會關掉它，Timer 也不是 Ticker）。
  final bool active;

  const CultureFeaturedCarousel({
    super.key,
    required this.items,
    required this.seniorMode,
    this.action,
    this.active = true,
  });

  @override
  State<CultureFeaturedCarousel> createState() =>
      _CultureFeaturedCarouselState();
}

class _CultureFeaturedCarouselState extends State<CultureFeaturedCarousel> {
  static const _interval = Duration(seconds: 5);

  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(CultureFeaturedCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 比對的是清單本身：父層只在精選真的重新抓回來時才換新清單，
    // 其餘重建（簽到、切分類、排序）傳進來的都是同一份，不重設。
    if (oldWidget.items != widget.items) {
      _page = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _restartTimer();
    } else if (oldWidget.active != widget.active) {
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // 使用者手動滑過後重新計時，避免剛滑完就被自動翻走。
  void _restartTimer() {
    _timer?.cancel();
    if (!widget.active || (widget.items?.length ?? 0) < 2) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!_controller.hasClients) return;
      final next = (_page + 1) % widget.items!.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final action = widget.action;
    if (items != null && items.isEmpty) {
      if (action == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Align(alignment: Alignment.centerRight, child: action),
      );
    }
    final height = widget.seniorMode ? 220.0 : 200.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: items == null
                      ? _buildCard(null)
                      : NotificationListener<ScrollStartNotification>(
                          onNotification: (n) {
                            if (n.dragDetails != null) _restartTimer();
                            return false;
                          },
                          child: PageView.builder(
                            controller: _controller,
                            itemCount: items.length,
                            onPageChanged: (i) => setState(() => _page = i),
                            itemBuilder: (_, i) => _buildCard(items[i]),
                          ),
                        ),
                ),
                if (action != null)
                  Positioned(top: 10, right: 10, child: action),
              ],
            ),
          ),
          // 只有一則也顯示圓點，讓使用者知道這是可輪播的精選區，版面高度也固定。
          if (items != null) ...[
            const SizedBox(height: 10),
            _buildDots(items.length),
          ],
        ],
      ),
    );
  }

  Widget _buildDots(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _page ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == _page
                  ? AppColors.gold
                  : AppColors.cream.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(CultureFeaturedItem? item) {
    final seniorMode = widget.seniorMode;
    return GestureDetector(
      onTap: item?.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item?.imageUrl != null)
            Image.network(
              item!.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallbackDecoration(),
            )
          else
            _fallbackDecoration(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.35, 1.0],
                colors: [Colors.black26, Colors.transparent, Colors.black87],
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 16,
            child: Text(
              '本週精選',
              style: AppTypography.mono(
                fontSize: AppTypography.size(
                  AppTypography.caption,
                  seniorMode: seniorMode,
                ),
                color: AppColors.gold,
                letterSpacing: 4.0,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item?.title ?? '精選內容載入中…',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.serif(
                          fontSize: seniorMode
                              ? AppTypography.display24
                              : AppTypography.title,
                          fontWeight: FontWeight.w600,
                          color: AppColors.creamLight,
                          letterSpacing: 1.0,
                          height: 1.25,
                        ),
                      ),
                      if (item != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppTypography.size(
                              AppTypography.caption,
                              seniorMode: seniorMode,
                            ),
                            color: AppColors.creamLight.withValues(alpha: 0.75),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackDecoration() {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.mossDeep, AppColors.midnightSoft],
            ),
          ),
        ),
        CustomPaint(
          painter: TrukuWeavePainter(
            color: AppColors.gold,
            opacity: 0.2,
            scale: 0.8,
          ),
        ),
      ],
    );
  }
}
