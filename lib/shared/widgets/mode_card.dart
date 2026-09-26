import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'truku_painters.dart';
import '../../core/constants/app_typography.dart';

class ModeData {
  final String key;
  final String zh;
  final String truku;
  final String sub;
  final Color bg;
  final Color fg;
  final Color accent;
  final String icon;

  const ModeData({
    required this.key,
    required this.zh,
    required this.truku,
    required this.sub,
    required this.bg,
    required this.fg,
    required this.accent,
    required this.icon,
  });
}

class ModeCard extends StatelessWidget {
  final ModeData mode;
  final bool large;
  final VoidCallback? onTap;

  /// 精簡模式：只留大 icon（左上）＋大字中文名（底部），隱藏族語名與副標；
  /// 由外層給定格子高度（首頁 2x2）。
  final bool seniorMode;

  const ModeCard({
    super.key,
    required this.mode,
    this.large = false,
    this.onTap,
    this.seniorMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: mode.bg,
          borderRadius: BorderRadius.circular(20),
          border: mode.bg == AppColors.creamLight
              ? Border.all(color: AppColors.creamDeep, width: 1.5)
              : null,
        ),
        child: Stack(
          children: [
            // 背景織紋
            Positioned.fill(
              child: Opacity(
                opacity: 0.12,
                child: CustomPaint(
                  painter: TrukuWeavePainter(
                    color: mode.accent,
                    opacity: 1.0,
                    scale: 0.6,
                  ),
                ),
              ),
            ),

            // 內容
            if (seniorMode) _buildSeniorContent() else _buildContent(),
          ],
        ),
      ),
    );
  }

  // 外層是 Clip.hardEdge：高度不足時溢出的內容會被圓角矩形直接切掉，連 overflow
  // 黃條都看不到（實際在 web 矮視窗上把中文標題切成一半）。所以這裡用
  // LayoutBuilder 依實際可用高度逐級降級，而不是硬撐版面：
  //   充裕 → 完整版面；偏緊 → 縮小內距；很緊 → 再捨棄副標；極緊 → 只留標題。
  // 每一級都保證內容量得出來的高度 <= 可用高度，所以永遠不會被裁掉。
  // 精簡模式的 2x2 是放在 SliverFillRemaining(hasScrollBody: false) 裡的，外層會
  // 量它的 intrinsic 高度——LayoutBuilder 不支援 intrinsic 量測，所以這裡不能用
  // 一般模式那套依可用高度降級的做法。改用「整頁可捲」保證裝得下（見
  // home_screen 的 _buildPage），這裡只保留標題的縮放保護。
  Widget _buildSeniorContent() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModeIcon(name: mode.icon, color: mode.accent, size: 36),
          const Spacer(),
          _title(fontSize: AppTypography.display26, height: 1.2),
        ],
      ),
    );
  }

  /// 內容量到的高度超過可用高度時把 18 的內距逐步收到 8，讓文字先保住。
  double _padFor(double available, double contentHeight) {
    if (!available.isFinite) return 18;
    final slack = available - contentHeight;
    if (slack >= 36) return 18;
    if (slack >= 16) return 8 + (slack - 16) / 20 * 10;
    return 8;
  }

  /// 中文名一律單行不換行；FittedBox 在高度被 Flexible 夾住後才會等比縮小，
  /// 縮到底仍不夠才退 ellipsis。
  Widget _title({required double fontSize, required double height}) {
    return Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          mode.zh,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.serif(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: mode.fg,
            letterSpacing: 1.0,
            height: height,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context);
        final titleSize = large
            ? AppTypography.display26
            : AppTypography.headline;
        final titleHeight = scale.scale(titleSize) * 1.1;
        final subHeight = scale.scale(AppTypography.caption) * 1.2;
        const iconHeight = 28.0;
        final full = iconHeight + 8 + titleHeight + 4 + subHeight;
        final pad = _padFor(constraints.maxHeight, full + 36);
        // 連最小內距都塞不下完整內容時，副標是最先該讓位的——它是輔助說明，
        // 中文標題與 icon 才是這張卡的識別。
        final showSub =
            !constraints.maxHeight.isFinite ||
            constraints.maxHeight >= full + pad * 2;
        return Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 頂部：icon 左，Truku 名右
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ModeIcon(name: mode.icon, color: mode.accent),
                  const SizedBox(width: 8),
                  // 半寬卡在 414px 機型只剩約 113px 給族語名，KARI TRUKU／LNGLUNGAN
                  // 加上 2.6 的字距會撐破 Row。FittedBox 讓窄卡自動縮排版而非截字，
                  // 縮到底仍不夠才退 ellipsis。
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        mode.truku.toUpperCase(),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.latin(
                          fontStyle: FontStyle.italic,
                          fontSize: AppTypography.caption,
                          color: mode.accent,
                          letterSpacing: 2.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // 底部：中文名 +（空間夠時）副標
              _title(fontSize: titleSize, height: 1.1),
              if (showSub) ...[
                const SizedBox(height: 4),
                Flexible(
                  child: Opacity(
                    opacity: 0.7,
                    child: Text(
                      mode.sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppTypography.caption,
                        color: mode.fg,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class ModeIcon extends StatelessWidget {
  final String name;
  final Color color;
  final double size;

  const ModeIcon({
    super.key,
    required this.name,
    required this.color,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _ModeIconPainter(name: name, color: color),
    );
  }
}

class _ModeIconPainter extends CustomPainter {
  final String name;
  final Color color;

  const _ModeIconPainter({required this.name, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 28;
    canvas.scale(scale, scale);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (name) {
      case 'lesson':
        _drawLesson(canvas, stroke, fill);
      case 'film':
        _drawFilm(canvas, stroke, fill);
      case 'comm':
        _drawComm(canvas, stroke, fill);
      case 'plaza':
        _drawPlaza(canvas, stroke);
      case 'event':
        _drawEvent(canvas, stroke);
    }
  }

  void _drawLesson(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRect(Rect.fromLTWH(4, 6, 20, 16), stroke);
    canvas.drawLine(const Offset(14, 6), const Offset(14, 22), stroke);
    canvas.drawLine(const Offset(8, 11), const Offset(12, 11), stroke);
    canvas.drawLine(const Offset(8, 15), const Offset(12, 15), stroke);
    canvas.drawLine(const Offset(16, 11), const Offset(20, 11), stroke);
    canvas.drawLine(const Offset(16, 15), const Offset(20, 15), stroke);
    canvas.drawCircle(const Offset(14, 6), 1.2, fill);
  }

  void _drawFilm(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(
      RRect.fromRectXY(Rect.fromLTWH(3, 6, 22, 16), 2, 2),
      stroke,
    );
    final tri = Path()
      ..moveTo(11, 11)
      ..lineTo(17, 14)
      ..lineTo(11, 17)
      ..close();
    canvas.drawPath(tri, fill);
    final thin = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(const Offset(3, 10), const Offset(25, 10), thin);
    canvas.drawLine(const Offset(3, 18), const Offset(25, 18), thin);
  }

  void _drawComm(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(
      RRect.fromRectXY(Rect.fromLTWH(3, 8, 16, 12), 2, 2),
      stroke,
    );
    final tri = Path()
      ..moveTo(19, 12)
      ..lineTo(25, 9)
      ..lineTo(25, 19)
      ..lineTo(19, 16)
      ..close();
    canvas.drawPath(
      tri,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(tri, stroke);
  }

  void _drawPlaza(Canvas canvas, Paint stroke) {
    canvas.drawCircle(const Offset(9, 10), 3, stroke);
    canvas.drawCircle(const Offset(19, 10), 3, stroke);
    final p1 = Path()
      ..moveTo(3, 22)
      ..cubicTo(3, 19, 6, 17, 9, 17)
      ..cubicTo(12, 17, 15, 19, 15, 22);
    canvas.drawPath(p1, stroke);
    final p2 = Path()
      ..moveTo(13, 22)
      ..cubicTo(13, 19, 16, 17, 19, 17)
      ..cubicTo(22, 17, 25, 19, 25, 22);
    canvas.drawPath(p2, stroke);
  }

  void _drawEvent(Canvas canvas, Paint stroke) {
    canvas.drawRRect(
      RRect.fromRectXY(Rect.fromLTWH(4, 6, 20, 18), 2, 2),
      stroke,
    );
    canvas.drawLine(const Offset(4, 11), const Offset(24, 11), stroke);
    canvas.drawLine(const Offset(9, 3), const Offset(9, 9), stroke);
    canvas.drawLine(const Offset(19, 3), const Offset(19, 9), stroke);
    final check = Path()
      ..moveTo(10, 16)
      ..lineTo(13, 19)
      ..lineTo(18, 14);
    canvas.drawPath(check, stroke);
  }

  @override
  bool shouldRepaint(covariant _ModeIconPainter old) =>
      old.name != name || old.color != color;
}
