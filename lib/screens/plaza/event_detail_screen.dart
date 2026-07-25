import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/truku_painters.dart';
import 'reminder_compose_screen.dart';

/// 活動詳情頁 — 進頁後以 [eventId] 打 GET /api/events/:id 取真資料。
///
/// isHost 由「登入者 uid == host_uid」即時判斷（uid 取自 UserService 快取，
/// 沒有就補打 /api/me）。底部行動列依身分與狀態切換：
///   發起人 → 發送提醒 / 取消活動
///   參加者 → 已報名（可退出）
///   其他   → 我要參加（報名開放且未額滿時）／已截止／已額滿
class EventDetailScreen extends StatefulWidget {
  final int eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  EventDetail? _event;
  int? _uid;
  bool _loading = true;
  String? _error;
  bool _acting = false; // 參加/退出/取消進行中，避免重複點

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  static const _weekdays = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 詳情與目前 uid 併行取得（uid 已快取就不重打）。
      final results = await Future.wait([
        EventService.fetchEventDetail(widget.eventId),
        _ensureUid(),
      ]);
      if (!mounted) return;
      setState(() {
        _event = results[0] as EventDetail;
        _uid = results[1] as int?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<int?> _ensureUid() async {
    if (UserService.currentUid != null) return UserService.currentUid;
    try {
      final me = await UserService.fetchMe();
      return me.uid;
    } catch (_) {
      return null; // 拿不到 uid 就當非發起人處理，不阻斷看活動
    }
  }

  Future<void> _refresh() => _load();

  // ── 行動：參加 / 退出 / 取消 ─────────────────────────────────
  Future<void> _join() async {
    await _runAction(
      () => EventService.joinEvent(widget.eventId),
      success: '已報名',
    );
  }

  Future<void> _leave() async {
    await _runAction(
      () => EventService.leaveEvent(widget.eventId),
      success: '已退出活動',
    );
  }

  Future<void> _cancelEvent() async {
    final reason = await _askCancelReason();
    if (reason == null) return;
    await _runAction(
      () => EventService.cancelEvent(widget.eventId, reason),
      success: '活動已取消，已通知參加者',
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String success,
  }) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<String?> _askCancelReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.creamLight,
        title: Text('取消活動',
            style: GoogleFonts.notoSerifTc(
                fontWeight: FontWeight.w700, color: AppColors.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('請填寫取消理由，會一併推播通知所有參加者。',
                style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.5)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 500,
              autofocus: true,
              style: const TextStyle(fontSize: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: '例如：因天候因素順延…',
                hintStyle: TextStyle(color: AppColors.fog),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('返回', style: TextStyle(color: AppColors.inkSoft)),
          ),
          TextButton(
            onPressed: () {
              final r = controller.text.trim();
              if (r.isEmpty) return;
              Navigator.pop(ctx, r);
            },
            child: const Text('確認取消活動',
                style: TextStyle(color: AppColors.dangerDark)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.creamLight,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_error != null || _event == null) {
      return Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: AppBar(
          backgroundColor: AppColors.creamLight,
          foregroundColor: AppColors.ink,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.fog, size: 40),
              const SizedBox(height: 12),
              Text(_error ?? '找不到活動',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 14)),
              const SizedBox(height: 16),
              TextButton(onPressed: _refresh, child: const Text('重試')),
            ],
          ),
        ),
      );
    }

    final e = _event!;
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHero(context, e)),
            SliverToBoxAdapter(child: _buildBody(e)),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionBar(context, e),
    );
  }

  // ── 頂部視覺 + 返回鈕 + 日期 ──────────────────────────────────
  Widget _buildHero(BuildContext context, EventDetail e) {
    final start = e.startsAt.toLocal();
    final cancelled = e.displayStatus == 'cancelled';
    final ended = e.displayStatus == 'ended';
    final gradient = cancelled || ended
        ? const [AppColors.fog, AppColors.inkSoft]
        : const [AppColors.primary, AppColors.primaryDeep];
    return SizedBox(
      height: 210,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Opacity(
            opacity: 0.22,
            child: CustomPaint(painter: TrukuWeavePainter(opacity: 1, scale: 0.8)),
          ),
          // 返回鈕
          Positioned(
            top: 52,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.creamLight.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.arrow_back, color: AppColors.creamLight, size: 18),
              ),
            ),
          ),
          // 標籤（分類，可能沒有）
          if (e.category != null && e.category!.isNotEmpty)
            Positioned(
              top: 58,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  e.category!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
            ),
          // 日期 + 標題
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cancelled || ended)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(cancelled ? '已取消' : '已結束',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.creamLight, letterSpacing: 1.5)),
                    ),
                  ),
                Text(
                  '${_months[start.month - 1]} ${start.day.toString().padLeft(2, '0')} · ${_weekdays[start.weekday - 1]}',
                  style: GoogleFonts.crimsonPro(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                    color: AppColors.gold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  e.title,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.creamLight,
                    letterSpacing: 0.8,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 內容 ─────────────────────────────────────────────────────
  Widget _buildBody(EventDetail e) {
    final start = e.startsAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final timeText = '${two(start.hour)}:${two(start.minute)}';
    final hostName = e.participants
            .where((p) => p.uid == e.hostUid)
            .map((p) => p.displayName)
            .firstWhere((n) => n != null && n.isNotEmpty, orElse: () => null) ??
        '發起人';
    final isHost = e.isHostedBy(_uid);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 發起人
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(Icons.person, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('發起人',
                      style: TextStyle(fontSize: 10, color: AppColors.fog, letterSpacing: 1.5)),
                  Text(hostName,
                      style: GoogleFonts.notoSerifTc(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                ],
              ),
              if (isHost) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('你發起的',
                      style: TextStyle(fontSize: 10, color: AppColors.goldDeep, letterSpacing: 1.0)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          _infoRow(Icons.access_time, '時間', timeText),
          const SizedBox(height: 12),
          if (e.location != null && e.location!.isNotEmpty) ...[
            _infoRow(Icons.location_on_outlined, '地點', e.location!),
            const SizedBox(height: 12),
          ],
          if (e.address != null && e.address!.isNotEmpty) ...[
            _infoRow(Icons.map_outlined, '地址', e.address!),
            const SizedBox(height: 12),
          ],
          if (e.registrationDeadline != null) ...[
            _infoRow(Icons.how_to_reg_outlined, '報名截止',
                _formatDateTime(e.registrationDeadline!.toLocal())),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),

          // 名額
          _buildCapacity(e),
          const SizedBox(height: 22),

          // 介紹
          if (e.description != null && e.description!.isNotEmpty) ...[
            Text('活動介紹',
                style: GoogleFonts.notoSerifTc(
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(e.description!,
                style: TextStyle(
                    fontSize: 13.5, color: AppColors.inkSoft, height: 1.7, letterSpacing: 0.4)),
            const SizedBox(height: 22),
          ],

          // 提醒事項
          if (e.reminderNote != null && e.reminderNote!.isNotEmpty) ...[
            _buildNoteBox('提醒事項', e.reminderNote!),
            const SizedBox(height: 16),
          ],

          // 聯絡資訊
          if ((e.contactEmail != null && e.contactEmail!.isNotEmpty) ||
              (e.contactPhone != null && e.contactPhone!.isNotEmpty)) ...[
            Text('聯絡資訊',
                style: GoogleFonts.notoSerifTc(
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 8),
            if (e.contactEmail != null && e.contactEmail!.isNotEmpty)
              _infoRow(Icons.email_outlined, 'Email', e.contactEmail!),
            if (e.contactPhone != null && e.contactPhone!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.phone_outlined, '電話', e.contactPhone!),
            ],
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 12),
        Text('$label ',
            style: TextStyle(fontSize: 12, color: AppColors.fog, letterSpacing: 1.0)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13.5, color: AppColors.ink, letterSpacing: 0.4)),
        ),
      ],
    );
  }

  Widget _buildNoteBox(String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.push_pin_outlined, size: 14, color: AppColors.goldDeep),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.goldDeep, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 6),
          Text(body,
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildCapacity(EventDetail e) {
    final count = e.participantCount;
    final max = e.maxParticipants;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('報名人數',
                  style: TextStyle(fontSize: 12, color: AppColors.inkSoft, letterSpacing: 1.0)),
              Text(
                max == null
                    ? '$count 人 · 不限名額'
                    : '$count / $max 人 · 剩 ${max - count} 個名額',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (max != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : (count / max).clamp(0.0, 1.0),
                backgroundColor: AppColors.creamDeep,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 底部行動列 ───────────────────────────────────────────────
  Widget _buildActionBar(BuildContext context, EventDetail e) {
    final isHost = e.isHostedBy(_uid);
    final isJoined = e.isJoinedBy(_uid);
    final status = e.displayStatus;

    Widget content;
    if (status == 'cancelled') {
      content = _disabledButton('活動已取消');
    } else if (status == 'ended') {
      content = _disabledButton('活動已結束');
    } else if (isHost) {
      content = _hostActions(context, e);
    } else if (isJoined) {
      content = _joinedActions();
    } else if (e.registrationOpen && !e.isFull) {
      content = _primaryButton('我要參加', _acting ? null : _join);
    } else if (e.isFull) {
      content = _disabledButton('名額已滿');
    } else {
      content = _disabledButton('報名已截止');
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.creamLight,
          border: Border(top: BorderSide(color: AppColors.creamDeep)),
        ),
        child: content,
      ),
    );
  }

  // 發起人：發送提醒 + 取消活動
  Widget _hostActions(BuildContext context, EventDetail e) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ReminderComposeScreen(eventId: e.id, eventTitle: e.title),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      color: AppColors.creamLight, size: 18),
                  const SizedBox(width: 8),
                  Text('發送提醒',
                      style: GoogleFonts.notoSerifTc(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.creamLight,
                          letterSpacing: 1.5)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: _acting ? null : _cancelEvent,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Text('取消活動',
                    style: GoogleFonts.notoSerifTc(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dangerDark,
                        letterSpacing: 1.0)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 參加者：已報名（可退出）
  Widget _joinedActions() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.moss.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.moss.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.mossDeep, size: 18),
                const SizedBox(width: 8),
                Text('已報名',
                    style: GoogleFonts.notoSerifTc(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mossDeep,
                        letterSpacing: 1.5)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _acting ? null : _leave,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.fog),
            ),
            child: Text('退出',
                style: TextStyle(
                    fontSize: 14, color: AppColors.inkSoft, letterSpacing: 1.0)),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: onTap == null
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: _acting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.creamLight),
                )
              : Text(label,
                  style: GoogleFonts.notoSerifTc(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      letterSpacing: 2.0)),
        ),
      ),
    );
  }

  Widget _disabledButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.fog.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft,
                letterSpacing: 2.0)),
      ),
    );
  }
}
