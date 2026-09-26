import '../../shared/widgets/async_state_view.dart';

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/event_model.dart';
import '../../models/shop_item.dart';
import '../../shared/share_text_file.dart';
import '../../services/account_lock_controller.dart';
import '../../services/event_service.dart';
import '../../services/fcm_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/shop_service.dart';
import '../../services/user_service.dart';
import 'event_compose_screen.dart';
import 'widgets/event_action_bar.dart';
import 'widgets/event_detail_body.dart';
import 'widgets/event_detail_dialogs.dart';
import 'widgets/event_detail_hero.dart';
import '../../shared/widgets/app_back_button.dart';

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

  /// route 名稱：讓通知導頁能用 popUntil 找回已經開著的那一份。
  static String routeNameFor(int eventId) => 'event/detail/$eventId';

  /// 所有呼叫端都走這個工廠，settings.name 才會一致。
  static Route<T> route<T>(int eventId) => MaterialPageRoute<T>(
    settings: RouteSettings(name: routeNameFor(eventId)),
    builder: (_) => EventDetailScreen(eventId: eventId),
  );

  /// 目前開著的詳情頁：key = eventId，value = 該實例的重載函式。
  static final Map<int, VoidCallback> _live = {};

  static bool isOpen(int eventId) => _live.containsKey(eventId);

  static void refreshIfOpen(int eventId) => _live[eventId]?.call();

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  EventDetail? _event;

  /// 活動只回 tribe_id，名稱另外對照；查不到就不顯示相關部落列。
  String? _tribeName;
  int? _uid;
  List<EventReminder> _reminders = [];
  bool _loading = true;
  Object? _error;
  bool _acting = false; // 參加/退出/取消進行中，避免重複點
  bool _likeBusy = false;
  bool _bookmarkBusy = false;

  /// 商店目錄（頭像＋頭像框，id → item），渲染發起人頭像用。
  Map<String, ShopItem> _itemCatalogById = const {};

  @override
  void initState() {
    super.initState();
    EventDetailScreen._live[widget.eventId] = _load;
    _load();
    _loadItemCatalog();
    FcmService.onReminderReceivedForOpenScreen = _onForegroundReminder;
  }

  Future<void> _loadItemCatalog() async {
    try {
      final catalog = await ShopService.fetchItemCatalogCached();
      if (!mounted) return;
      setState(() => _itemCatalogById = catalog);
    } catch (e) {
      // 目錄拿不到只影響內建頭像/頭像框的圖，退回預設圖示即可，不擋整頁。
      debugPrint('Failed to fetch item catalog: $e');
    }
  }

  @override
  void dispose() {
    // 同一 eventId 若已被新實例接手，不要把它的登記清掉。
    if (EventDetailScreen._live[widget.eventId] == _load) {
      EventDetailScreen._live.remove(widget.eventId);
    }
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

  Future<void> _loadTribeName(int? tribeId) async {
    if (tribeId == null) {
      if (_tribeName != null) setState(() => _tribeName = null);
      return;
    }
    try {
      final name = await UserService.tribeName(tribeId);
      if (!mounted || _event?.tribeId != tribeId) return;
      setState(() => _tribeName = name);
    } catch (e) {
      debugPrint('[EventDetailScreen] 部落名稱載入失敗（忽略）：$e');
    }
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
      _loadTribeName(_event?.tribeId);
    } catch (e, st) {
      debugPrint('[EventDetailScreen] _load 失敗：$e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _error = e;
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
    if (blockIfReadOnly()) return;
    final email = await _askJoinEmail();
    if (email == null) return;
    await _runAction(
      () => EventService.joinEvent(widget.eventId, contactEmail: email),
      success: '已報名',
    );
  }

  /// 報名前彈窗要求聯絡 email（後端必填）；預填帳號 email 供使用者確認/修改。
  Future<String?> _askJoinEmail() async {
    String? prefill;
    try {
      prefill = (await UserService.fetchMe()).email;
    } catch (_) {
      // 拿不到就讓使用者自己輸入，不阻斷報名流程。
    }
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (ctx) => JoinEmailDialog(initialEmail: prefill),
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

  /// 成功後提示 [success] 並重新整理活動資料。
  Future<void> _runAction(
    Future<void> Function() action, {
    required String success,
  }) {
    return _guarded(() async {
      await action();
      if (!mounted) return;
      _snack(success);
      await _silentRefresh();
    });
  }

  /// 所有會打後端的動作共用：[_acting] 防連點，後端錯誤顯示其訊息，
  /// 其他錯誤以「[failurePrefix]：原因」提示。
  Future<void> _guarded(
    Future<void> Function() action, {
    String failurePrefix = '操作失敗',
  }) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await action();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('$failurePrefix：$e');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── 按讚 / 收藏（任何活動狀態皆可） ────────────────────────────

  /// 樂觀更新，API 回傳真實計數後校正；失敗則還原。
  Future<void> _toggleLike() async {
    final event = _event;
    if (event == null || _likeBusy) return;
    // 唯讀帳號只擋「按讚」，取消讚後端放行。
    if (!event.isLiked && blockIfReadOnly()) return;
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
      builder: (ctx) => const CancelReasonDialog(),
    );
  }

  // ── 編輯 / 刪除（僅發起人） ────────────────────────────────────
  Future<void> _editEvent() async {
    final event = _event;
    if (event == null || blockIfReadOnly()) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EventComposeScreen(editing: event)),
    );
    if (updated == true && mounted) await _silentRefresh();
  }

  /// 匯出報名名單 CSV（僅發起人）：拿到後端組好的 CSV 文字，寫成暫存檔再跳系統
  /// 分享選單（存檔/寄信/傳送皆可），錯誤處理走 [_guarded]。
  Future<void> _exportRoster() async {
    final event = _event;
    if (event == null) return;
    await _guarded(failurePrefix: '匯出失敗', () async {
      final csv = await EventService.exportRoster(widget.eventId);
      if (!mounted) return;
      // 名單含參加者姓名與 email，shareTextFile 分享完即刪暫存檔。
      await shareTextFile(
        content: csv,
        filename: 'event_${event.id}_roster.csv',
        mimeType: 'text/csv',
        subject: '${event.title} 報名名單',
      );
    });
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除活動？'),
        content: const Text('刪除後將無法復原，已報名的參加者也會看不到這個活動。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _guarded(failurePrefix: '刪除失敗', () async {
      await EventService.deleteEvent(widget.eventId);
      if (!mounted) return;
      Navigator.pop(context, true); // 通知活動列表刷新
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) =>
          _buildScaffold(context, seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(BuildContext context, bool seniorMode) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.creamLight,
        body: TrukuLoadingView(),
      );
    }
    if (_error != null || _event == null) {
      return Scaffold(
        backgroundColor: AppColors.creamLight,
        appBar: AppBar(
          leading: const AppBackButton(),
          backgroundColor: AppColors.creamLight,
          foregroundColor: AppColors.ink,
          elevation: 0,
        ),
        body: TrukuErrorView(
          error: _error,
          message: _error == null ? '找不到活動' : null,
          onRetry: _refresh,
          seniorMode: seniorMode,
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
            SliverToBoxAdapter(
              child: EventDetailHero(event: e, seniorMode: seniorMode),
            ),
            SliverToBoxAdapter(
              child: EventDetailBody(
                event: e,
                uid: _uid,
                reminders: _reminders,
                seniorMode: seniorMode,
                onToggleLike: _toggleLike,
                onToggleBookmark: _toggleBookmark,
                itemCatalogById: _itemCatalogById,
                tribeName: _tribeName,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      bottomNavigationBar: EventActionBar(
        event: e,
        uid: _uid,
        acting: _acting,
        seniorMode: seniorMode,
        onJoin: _join,
        onLeave: _leave,
        onCancel: _cancelEvent,
        onEdit: _editEvent,
        onExport: _exportRoster,
        onDelete: _deleteEvent,
        onReminderSent: _silentRefresh,
      ),
    );
  }
}
