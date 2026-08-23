import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_format.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/fcm_service.dart';
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
  List<EventReminder> _reminders = [];
  bool _loading = true;
  String? _error;
  bool _acting = false; // 參加/退出/取消進行中，避免重複點
  bool _likeBusy = false;
  bool _bookmarkBusy = false;

  static const _months = [
    '1月',
    '2月',
    '3月',
    '4月',
    '5月',
    '6月',
    '7月',
    '8月',
    '9月',
    '10月',
    '11月',
    '12月',
  ];
  static const _weekdays = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];

  @override
  void initState() {
    super.initState();
    _load();
    FcmService.onReminderReceivedForOpenScreen = _onForegroundReminder;
  }

  @override
  void dispose() {
    if (identical(
      FcmService.onReminderReceivedForOpenScreen,
      _onForegroundReminder,
    )) {
      FcmService.onReminderReceivedForOpenScreen = null;
    }
    super.dispose();
  }

  /// 前景收到本活動的新提醒推播時觸發，即時刷新提醒紀錄區塊。
  void _onForegroundReminder(int? eventId) {
    if (eventId != widget.eventId || !mounted) return;
    _fetchRemindersSafe().then((reminders) {
      if (!mounted) return;
      setState(() => _reminders = reminders);
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 詳情、目前 uid、提醒紀錄併行取得（uid 已快取就不重打）。
      final results = await Future.wait([
        EventService.fetchEventDetail(widget.eventId),
        _ensureUid(),
        _fetchRemindersSafe(),
      ]);
      if (!mounted) return;
      setState(() {
        _event = results[0] as EventDetail;
        _uid = results[1] as int?;
        _reminders = results[2] as List<EventReminder>;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[EventDetailScreen] _load 失敗：$e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// 提醒紀錄僅參加者可查看（非參加者打會 403），失敗時回空清單，
  /// 不能讓這支 API 拖垮整頁載入。
  Future<List<EventReminder>> _fetchRemindersSafe() async {
    try {
      return await EventService.fetchReminders(widget.eventId);
    } catch (_) {
      return const [];
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

  /// 動作（參加/退出/取消）成功後的刷新：只更新資料本身，不設 `_loading = true`，
  /// 避免整頁重建與剛關閉的對話框收尾動畫互撞（觸發 `_dependents.isEmpty` assertion）。
  Future<void> _silentRefresh() async {
    try {
      final results = await Future.wait([
        EventService.fetchEventDetail(widget.eventId),
        _ensureUid(),
        _fetchRemindersSafe(),
      ]);
      if (!mounted) return;
      setState(() {
        _event = results[0] as EventDetail;
        _uid = results[1] as int?;
        _reminders = results[2] as List<EventReminder>;
      });
    } catch (e, st) {
      debugPrint('[EventDetailScreen] _silentRefresh 失敗：$e');
      debugPrint('$st');
    }
  }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      await _silentRefresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失敗：$e')));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  // ── 按讚 / 收藏（任何活動狀態皆可） ────────────────────────────

  /// 樂觀更新，API 回傳真實計數後校正；失敗則還原。
  Future<void> _toggleLike() async {
    final event = _event;
    if (event == null || _likeBusy) return;
    setState(() {
      _likeBusy = true;
      _event = event.toggledLike();
    });
    try {
      final result = await EventService.likeEvent(
        widget.eventId,
        like: !event.isLiked,
      );
      if (!mounted) return;
      setState(() {
        _event = _event!.withLikeResult(
          liked: result.liked,
          likeCount: result.likeCount,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _event = event);
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  Future<void> _toggleBookmark() async {
    final event = _event;
    if (event == null || _bookmarkBusy) return;
    setState(() {
      _bookmarkBusy = true;
      _event = event.toggledBookmark();
    });
    try {
      await EventService.bookmarkEvent(
        widget.eventId,
        add: !event.isBookmarked,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _event = event);
    } finally {
      if (mounted) setState(() => _bookmarkBusy = false);
    }
  }

  Future<String?> _askCancelReason() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => const _CancelReasonDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.creamLight,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
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
              Text(
                _error ?? '找不到活動',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
              ),
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
            child: CustomPaint(
              painter: TrukuWeavePainter(opacity: 1, scale: 0.8),
            ),
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
                  border: Border.all(
                    color: AppColors.creamLight.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: AppColors.creamLight,
                  size: 18,
                ),
              ),
            ),
          ),
          // 標籤（分類，可能沒有）
          if (e.category != null && e.category!.isNotEmpty)
            Positioned(
              top: 58,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        cancelled ? '已取消' : '已結束',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.creamLight,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                Text(
                  '${_months[start.month - 1]}${start.day}日 · ${_weekdays[start.weekday - 1]}',
                  style: GoogleFonts.notoSerifTc(
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
    final timeText = formatDateTime(start);
    final hostName =
        e.participants
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
                child: const Icon(
                  Icons.person,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '發起人',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.fog,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    hostName,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              if (isHost) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '你發起的',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.goldDeep,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              _engagementButton(
                icon: e.isLiked ? Icons.favorite : Icons.favorite_border,
                active: e.isLiked,
                count: e.likeCount,
                onTap: _toggleLike,
              ),
              const SizedBox(width: 6),
              _engagementButton(
                icon: e.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                active: e.isBookmarked,
                onTap: _toggleBookmark,
              ),
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
            _infoRow(
              Icons.how_to_reg_outlined,
              '報名截止',
              formatDateTime(e.registrationDeadline!.toLocal()),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),

          // 名額
          _buildCapacity(e),
          const SizedBox(height: 22),

          // 介紹
          if (e.description != null && e.description!.isNotEmpty) ...[
            Text(
              '活動介紹',
              style: GoogleFonts.notoSerifTc(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              e.description!,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.inkSoft,
                height: 1.7,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 22),
          ],

          // 提醒事項
          if (e.reminderNote != null && e.reminderNote!.isNotEmpty) ...[
            _buildNoteBox('提醒事項', e.reminderNote!),
            const SizedBox(height: 16),
          ],

          // 提醒紀錄：排定發送（尚未送出）／已發送（含失敗、取消等已處理完的）
          if (_reminders.isNotEmpty) ...[
            Text(
              '提醒紀錄',
              style: GoogleFonts.notoSerifTc(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            if (_pendingReminders().isNotEmpty) ...[
              _buildReminderGroupLabel('排定發送'),
              const SizedBox(height: 6),
              for (final r in _pendingReminders()) ...[
                _buildReminderCard(r),
                const SizedBox(height: 10),
              ],
            ],
            if (_sentReminders().isNotEmpty) ...[
              _buildReminderGroupLabel('已發送'),
              const SizedBox(height: 6),
              for (final r in _sentReminders()) ...[
                _buildReminderCard(r),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 2),
          ],

          // 聯絡資訊
          if ((e.contactEmail != null && e.contactEmail!.isNotEmpty) ||
              (e.contactPhone != null && e.contactPhone!.isNotEmpty)) ...[
            Text(
              '聯絡資訊',
              style: GoogleFonts.notoSerifTc(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
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

  Widget _engagementButton({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    int? count,
  }) {
    final color = active ? AppColors.primary : AppColors.fog;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            if (count != null) ...[
              const SizedBox(width: 4),
              Text('$count', style: TextStyle(color: color, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          '$label ',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.fog,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.ink,
              letterSpacing: 0.4,
            ),
          ),
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
              const Icon(
                Icons.push_pin_outlined,
                size: 14,
                color: AppColors.goldDeep,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.goldDeep,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// 排定發送（尚未送出）：依排定時間由近到遠排序。
  List<EventReminder> _pendingReminders() {
    final list = _reminders.where((r) => r.status == 'pending').toList();
    list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  /// 已發送（含失敗、取消等已處理完的）：新的（id 較大）排在前面；
  /// 後端固定回傳 scheduled_at 遞增排序，這裡反過來。
  List<EventReminder> _sentReminders() {
    final list = _reminders.where((r) => r.status != 'pending').toList();
    list.sort((a, b) => b.id.compareTo(a.id));
    return list;
  }

  Widget _buildReminderGroupLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        color: AppColors.fog,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildReminderCard(EventReminder r) {
    final (label, color) = switch (r.status) {
      'sent' => (
        '已發送 · ${formatDateTime((r.sentAt ?? r.scheduledAt).toLocal())}',
        AppColors.mossDeep,
      ),
      'failed' => ('發送失敗', AppColors.dangerDark),
      'cancelled' => ('已取消', AppColors.fog),
      _ => (
        '排定於 ${formatDateTime(r.scheduledAt.toLocal())}',
        AppColors.primary,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.message,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.ink,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, letterSpacing: 0.6),
          ),
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
              Text(
                '報名人數',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.inkSoft,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                max == null
                    ? '$count 人 · 不限名額'
                    : '$count / $max 人 · 剩 ${max - count} 個名額',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
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
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.creamLight,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '發送提醒',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.creamLight,
                      letterSpacing: 1.5,
                    ),
                  ),
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
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.5),
                ),
              ),
              child: Center(
                heightFactor: 1.0,
                child: Text(
                  '取消活動',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dangerDark,
                    letterSpacing: 1.0,
                  ),
                ),
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
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.mossDeep,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '已報名',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mossDeep,
                    letterSpacing: 1.5,
                  ),
                ),
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
            child: Text(
              '退出',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.inkSoft,
                letterSpacing: 1.0,
              ),
            ),
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
        // heightFactor: 1.0 讓 Center 收縮到子元件高度；預設在 Scaffold
        // bottomNavigationBar 的有界高度下會撐滿整個高度，把 body 擠成 0。
        child: Center(
          heightFactor: 1.0,
          child: _acting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.creamLight,
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.creamLight,
                    letterSpacing: 2.0,
                  ),
                ),
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
        heightFactor: 1.0,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }
}

/// 「取消活動」理由輸入對話框。獨立成 StatefulWidget 讓
/// [TextEditingController] 隨這個 dialog 元件自身的生命週期建立/釋放，
/// 避免在 `showDialog` 的 Future resolve 當下就手動 dispose——
/// 此時 dialog 的關閉動畫可能還沒跑完，仍持有該 controller 的 TextField
/// 尚未真正 unmount，手動提早 dispose 會丟出
/// "A TextEditingController was used after being disposed." 例外。
class _CancelReasonDialog extends StatefulWidget {
  const _CancelReasonDialog();

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.creamLight,
      title: Text(
        '取消活動',
        style: GoogleFonts.notoSerifTc(
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '請填寫取消理由，會一併推播通知所有參加者。',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('返回', style: TextStyle(color: AppColors.inkSoft)),
        ),
        TextButton(
          onPressed: () {
            final r = _controller.text.trim();
            if (r.isEmpty) return;
            Navigator.pop(context, r);
          },
          child: const Text(
            '確認取消活動',
            style: TextStyle(color: AppColors.dangerDark),
          ),
        ),
      ],
    );
  }
}
