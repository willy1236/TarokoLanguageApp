import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../shop/shop_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onClose;
  const ProfileScreen({super.key, this.onClose});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedBadge = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHero(),
              _buildBadgeSection(),
              _buildAccountSection(),
              _buildPreferencesSection(),
              _buildOtherSection(),
              _buildLogout(context),
              const SizedBox(height: 40),
            ],
          ),
          Positioned(
            top: 56,
            left: 16,
            child: GestureDetector(
              onTap: widget.onClose ?? () => Navigator.of(context).maybePop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.creamLight.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.chevron_left, color: AppColors.creamLight),
              ),
            ),
          ),
          Positioned(
            top: 56,
            right: 16,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.creamLight.withValues(alpha: 0.15),
              ),
              child: CustomPaint(painter: _SettingsIconPainter()),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: CustomPaint(
                painter: TrukuWeavePainter(color: AppColors.gold, opacity: 1.0, scale: 0.8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SAYUN LOWKING',
                            style: GoogleFonts.crimsonPro(
                              fontStyle: FontStyle.italic,
                              fontSize: 11,
                              color: AppColors.gold,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Apyang Imiq',
                            style: GoogleFonts.notoSerifTc(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppColors.creamLight,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '銅門部落 · 加入 124 天',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.creamLight.withValues(alpha: 0.85),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _statCell('248', '已學詞彙'),
                    const SizedBox(width: 10),
                    _statCell('36', '通話次數'),
                    const SizedBox(width: 10),
                    _statCell('12', '發文'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.ink,
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: ClipOval(
              child: Center(
                child: Icon(Icons.person, size: 52, color: AppColors.gold.withValues(alpha: 0.7)),
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: CustomPaint(painter: _EditIconPainter()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCell(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.creamLight.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.notoSerifTc(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.creamLight.withValues(alpha: 0.80),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 大頭貼選擇 ────────────────────────────────────────────────────────────

  Widget _buildBadgeSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'LUKUS · 大頭貼',
                style: GoogleFonts.crimsonPro(
                  fontStyle: FontStyle.italic,
                  fontSize: 10,
                  color: AppColors.fog,
                  letterSpacing: 3,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                ),
                child: Text(
                  '前往商店 →',
                  style: TextStyle(fontSize: 11, color: AppColors.primary, letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.creamDeep),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '從擁有的徽章中選一個作為頭貼',
                  style: TextStyle(fontSize: 11, color: AppColors.fog, letterSpacing: 1),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 6,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      if (i == 5) {
                        return Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            color: AppColors.gold.withValues(alpha: 0.06),
                          ),
                          child: const Icon(Icons.add, color: AppColors.primary, size: 20),
                        );
                      }
                      final selected = i == _selectedBadge;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedBadge = i),
                        child: Stack(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected ? AppColors.primary : Colors.transparent,
                                border: Border.all(
                                  color: selected ? AppColors.gold : AppColors.creamDeep,
                                  width: selected ? 2.0 : 1.5,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.face_rounded,
                                  size: 34,
                                  color: selected
                                      ? AppColors.gold
                                      : AppColors.fog,
                                ),
                              ),
                            ),
                            if (selected)
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.gold,
                                    border: Border.all(color: AppColors.creamLight, width: 1.5),
                                  ),
                                  child: const Icon(Icons.check, size: 10, color: AppColors.ink),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.creamDeep),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold.withValues(alpha: 0.2),
                      ),
                      child: const Icon(Icons.grain, size: 16, color: AppColors.gold),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.notoSerifTc(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                                letterSpacing: 0.5,
                              ),
                              children: const [
                                TextSpan(text: '目前小米：'),
                                TextSpan(
                                  text: '320',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '每日登入 / 完成單元都能得小米',
                            style: TextStyle(fontSize: 10, color: AppColors.fog, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ShopScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '逛商店',
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.creamLight,
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

  // ── 帳號設定 ──────────────────────────────────────────────────────────────

  Widget _buildAccountSection() {
    const rows = [
      (label: '中文姓名', value: 'Apyang Imiq', truku: false, editable: true),
      (label: '族語名字', value: 'Sayun Lowking', truku: true, editable: true),
      (label: '部落', value: '銅門 Dowmung', truku: false, editable: true),
      (label: '電子信箱', value: 'apyang@truku.org', truku: false, editable: false),
    ];
    return _section(
      'HANGAN · 帳號',
      rows.map((r) => _settingRow(r.label, r.value, truku: r.truku, editable: r.editable)).toList(),
    );
  }

  // ── 偏好設定 ──────────────────────────────────────────────────────────────

  Widget _buildPreferencesSection() {
    return _section('SMPUNG · 偏好', [
      _toggleRow('通知', '已開啟', true),
      _chevronRow('族語顯示', '優先顯示拼音'),
      _chevronRow('字級大小', '中'),
      _toggleRow('通話開放', '所有族人', true),
    ]);
  }

  // ── 其他 ──────────────────────────────────────────────────────────────────

  Widget _buildOtherSection() {
    const items = ['關於語見太魯閣', '隱私權政策', '聯絡我們'];
    return _section(
      'QITA · 其他',
      List.generate(items.length, (i) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    items[i],
                    style: GoogleFonts.notoSerifTc(fontSize: 14, color: AppColors.ink, letterSpacing: 0.5),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.fog, size: 16),
                ],
              ),
            ),
            if (i < items.length - 1)
              const Divider(height: 1, color: AppColors.creamDeep, indent: 16, endIndent: 16),
          ],
        );
      }),
    );
  }

  // ── 登出 ──────────────────────────────────────────────────────────────────

  Widget _buildLogout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              await AuthService.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(size: const Size(16, 16), painter: _LogoutIconPainter()),
                  const SizedBox(width: 8),
                  Text(
                    '登出',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'v1.0.0 · MHUWAY SU',
            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppColors.fog, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  // ── 共用 section 外框 ─────────────────────────────────────────────────────

  Widget _section(String label, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.crimsonPro(
              fontStyle: FontStyle.italic,
              fontSize: 10,
              color: AppColors.fog,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.creamDeep),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(String label, String value, {bool truku = false, bool editable = true}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: AppColors.fog, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: (truku
                            ? GoogleFonts.crimsonPro(fontStyle: FontStyle.italic)
                            : GoogleFonts.notoSerifTc())
                        .copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (editable)
                CustomPaint(size: const Size(16, 16), painter: _EditPenPainter()),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.creamDeep, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _toggleRow(String label, String value, bool on) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.notoSerifTc(fontSize: 14, color: AppColors.ink, letterSpacing: 0.5)),
              Row(
                children: [
                  Text(value, style: TextStyle(fontSize: 12, color: AppColors.fog, letterSpacing: 1)),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 22,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: on ? AppColors.primary : AppColors.creamDeep,
                    ),
                    child: Align(
                      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.creamLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.creamDeep, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _chevronRow(String label, String value) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.notoSerifTc(fontSize: 14, color: AppColors.ink, letterSpacing: 0.5)),
              Row(
                children: [
                  Text(value, style: TextStyle(fontSize: 12, color: AppColors.fog, letterSpacing: 1)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: AppColors.fog, size: 16),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.creamDeep, indent: 16, endIndent: 16),
      ],
    );
  }
}

// ── SVG 圖示 Painters ─────────────────────────────────────────────────────────

class _EditIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.58, size.height * 0.17)
      ..lineTo(size.width * 0.83, size.height * 0.42)
      ..lineTo(size.width * 0.33, size.height * 0.92)
      ..lineTo(size.width * 0.08, size.height * 0.92)
      ..lineTo(size.width * 0.08, size.height * 0.67)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _EditPenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.58, size.height * 0.17)
      ..lineTo(size.width * 0.83, size.height * 0.42)
      ..lineTo(size.width * 0.33, size.height * 0.92)
      ..lineTo(size.width * 0.08, size.height * 0.92)
      ..lineTo(size.width * 0.08, size.height * 0.67)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _LogoutIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.55, size.height * 0.5), Offset(size.width, size.height * 0.5), p);
    canvas.drawLine(Offset(size.width * 0.75, size.height * 0.25), Offset(size.width, size.height * 0.5), p);
    canvas.drawLine(Offset(size.width * 0.75, size.height * 0.75), Offset(size.width, size.height * 0.5), p);
    final door = Path()
      ..moveTo(size.width * 0.45, size.height * 0.13)
      ..lineTo(size.width * 0.2, size.height * 0.13)
      ..arcToPoint(Offset(size.width * 0.08, size.height * 0.25), radius: Radius.circular(size.width * 0.12))
      ..lineTo(size.width * 0.08, size.height * 0.75)
      ..arcToPoint(Offset(size.width * 0.2, size.height * 0.87), radius: Radius.circular(size.width * 0.12))
      ..lineTo(size.width * 0.45, size.height * 0.87);
    canvas.drawPath(door, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _SettingsIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.creamLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.16;
    canvas.drawCircle(Offset(cx, cy), r, p);
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final inner = r + size.width * 0.08;
      final outer = r + size.width * 0.22;
      canvas.drawLine(
        Offset(cx + inner * math.cos(a), cy + inner * math.sin(a)),
        Offset(cx + outer * math.cos(a), cy + outer * math.sin(a)),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
