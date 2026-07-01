import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  int _typeIndex = 0; // 0 = 動態 patas, 1 = 活動 smratuc
  final _controller = TextEditingController();
  final Set<int> _selectedTags = {0};

  static const _tags = ['Mhuway', '族語心得', '走讀', '老人家的話', '求救', 'Gaya'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeSegment(),
                  _buildAuthorRow(),
                  _buildTextInput(),
                  _buildPhotoAttachments(),
                  _buildTagsSection(),
                ],
              ),
            ),
          ),
          _buildToolBar(),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 54, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.creamLight,
        border: Border(bottom: BorderSide(color: AppColors.creamDeep)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.inkSoft,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '新發布',
                style: GoogleFonts.notoSerifTc(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '發布',
              style: GoogleFonts.notoSerifTc(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.creamLight,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSegment() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          children: [
            _SegmentTab(
              label: '動態',
              truku: 'patas',
              icon: _PenIcon(),
              active: _typeIndex == 0,
              onTap: () => setState(() => _typeIndex = 0),
            ),
            _SegmentTab(
              label: '活動',
              truku: 'smratuc',
              icon: _CalIcon(),
              active: _typeIndex == 1,
              onTap: () => setState(() => _typeIndex = 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: const Border.fromBorderSide(
                BorderSide(color: AppColors.gold, width: 1.5),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'S',
              style: GoogleFonts.notoSerifTc(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sayun Lowking',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.language, size: 11, color: AppColors.fog),
                    const SizedBox(width: 4),
                    const Text(
                      '公開 · 所有族人都看得到',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.fog,
                        letterSpacing: 0.8,
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

  Widget _buildTextInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        constraints: const BoxConstraints(minHeight: 140),
        padding: const EdgeInsets.all(14).copyWith(left: 16),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: TextField(
          controller: _controller,
          maxLines: null,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.ink,
            height: 1.6,
            letterSpacing: 0.5,
          ),
          decoration: const InputDecoration(
            hintText: '今天跟 yaki 學了一個新詞...',
            hintStyle: TextStyle(color: AppColors.fog, fontSize: 15),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          cursorColor: AppColors.primary,
          cursorWidth: 1.5,
        ),
      ),
    );
  }

  Widget _buildPhotoAttachments() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          // 已附加照片
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [AppColors.moss, AppColors.mossDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                    child: const Icon(Icons.close, size: 10, color: AppColors.creamLight),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 新增照片按鈕
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.fog.withValues(alpha: 0.5),
                width: 1.5,
                style: BorderStyle.solid,
              ),
            ),
            child: const Icon(Icons.add, color: AppColors.fog, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HANGAN · 標籤',
            style: GoogleFonts.crimsonPro(
              fontStyle: FontStyle.italic,
              fontSize: 10,
              color: AppColors.fog,
              letterSpacing: 3.0,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(_tags.length, (i) {
              final active = _selectedTags.contains(i);
              return GestureDetector(
                onTap: () => setState(() {
                  if (active) {
                    _selectedTags.remove(i);
                  } else {
                    _selectedTags.add(i);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: active ? null : Border.all(color: AppColors.creamDeep),
                  ),
                  child: Text(
                    '#${_tags[i]}',
                    style: GoogleFonts.crimsonPro(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: active ? AppColors.creamLight : AppColors.inkSoft,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildToolBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppColors.creamLight,
        border: Border(top: BorderSide(color: AppColors.creamDeep)),
      ),
      child: Row(
        children: [
          _ToolButton(icon: _ImgIcon(), label: '圖片'),
          const SizedBox(width: 22),
          _ToolButton(icon: _MicIcon(), label: '錄音'),
          const SizedBox(width: 22),
          _ToolButton(icon: _TagIcon(), label: '標籤'),
          const SizedBox(width: 22),
          _ToolButton(icon: _LocIcon(), label: '部落'),
          const Spacer(),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (_, val, _) => Text(
              '${val.text.length} / 500',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: AppColors.fog,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Segment tab ───────────────────────────────────────────────

class _SegmentTab extends StatelessWidget {
  final String label, truku;
  final Widget icon;
  final bool active;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.label,
    required this.truku,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.creamLight : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 3, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.notoSerifTc(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : AppColors.fog,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                truku,
                style: GoogleFonts.crimsonPro(
                  fontStyle: FontStyle.italic,
                  fontSize: 10,
                  color: active ? AppColors.gold : AppColors.fog.withValues(alpha: 0.8),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 工具列按鈕 ────────────────────────────────────────────────

class _ToolButton extends StatelessWidget {
  final Widget icon;
  final String label;

  const _ToolButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cream,
          ),
          alignment: Alignment.center,
          child: icon,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.inkSoft,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ── SVG 圖示 (CustomPainter) ─────────────────────────────────

class _PenIcon extends StatelessWidget {
  const _PenIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(14, 14), painter: _PenPainter(AppColors.primary));
  }
}

class _PenPainter extends CustomPainter {
  final Color color;
  _PenPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.583, size.height * 0.167)
      ..lineTo(size.width * 0.833, size.height * 0.417)
      ..lineTo(size.width * 0.333, size.height * 0.917)
      ..lineTo(size.width * 0.083, size.height * 0.917)
      ..lineTo(size.width * 0.083, size.height * 0.667)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_PenPainter old) => old.color != color;
}

class _CalIcon extends StatelessWidget {
  const _CalIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(14, 14), painter: _CalPainter(AppColors.fog));
  }
}

class _CalPainter extends CustomPainter {
  final Color color;
  _CalPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.125, size.height * 0.208, size.width * 0.75, size.height * 0.667),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(rect, p);
    canvas.drawLine(Offset(size.width * 0.125, size.height * 0.417), Offset(size.width * 0.875, size.height * 0.417), p);
    canvas.drawLine(Offset(size.width * 0.333, size.height * 0.125), Offset(size.width * 0.333, size.height * 0.375), p);
    canvas.drawLine(Offset(size.width * 0.667, size.height * 0.125), Offset(size.width * 0.667, size.height * 0.375), p);
  }

  @override
  bool shouldRepaint(_CalPainter old) => old.color != color;
}

class _ImgIcon extends StatelessWidget {
  const _ImgIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.image_outlined, color: AppColors.primary, size: 18);
  }
}

class _MicIcon extends StatelessWidget {
  const _MicIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.mic_none_rounded, color: AppColors.primary, size: 18);
  }
}

class _TagIcon extends StatelessWidget {
  const _TagIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.label_outline_rounded, color: AppColors.primary, size: 18);
  }
}

class _LocIcon extends StatelessWidget {
  const _LocIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18);
  }
}
