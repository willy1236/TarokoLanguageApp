import '../../shared/widgets/async_state_view.dart';

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/event_model.dart';
import '../../models/shop_item.dart';
import '../../shared/share_text_file.dart';
import '../../services/account_lock_controller.dart';
import '../../services/admin_service.dart';
import '../../services/event_service.dart';
import '../../services/fcm_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/shop_service.dart';
import '../../services/user_service.dart';
import '../admin/admin_error.dart';
import '../admin/widgets/admin_reason_dialog.dart';
import '../forum/widgets/forum_report_sheet.dart';
import 'event_compose_screen.dart';
import 'widgets/event_action_bar.dart';
import 'widgets/event_detail_body.dart';
import 'widgets/event_detail_dialogs.dart';
import 'widgets/event_detail_hero.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/confirm_dialog.dart';

/// 活動詳情頁 — 進頁後以 [eventId] 打 GET /api/events/:id 取真資料。
///
/// 是不是發起人看後端算好的 is_host。底部行動列依身分與狀態切換：
///   發起人 → 發送提醒 / 取消活動
///   參加者 → 已報名（可退出）
///   其他   → 我要參加（報名開放且未額滿時）／已截止／已額滿
class EventDetailScreen extends StatefulWidget {
  final int eventId;

  const EventDetailScreen({super.key, required this.eventId});

  /// route 名稱：讓通知導頁判斷最上層是不是這場活動。
  static String routeNameFor(int eventId) => 'event/detail/$eventId';

  /// 所有呼叫端都走這個工廠，settings.name 才會一致。
  ///
  /// 頁面上報名、退出、取消、編輯或刪除過活動時，返回的結果為 true（含返回鍵
  /// 與滑動返回），列表可以只在有變動時才重載。要拿結果時 [T] 給 bool。
  static Route<T> route<T>(int eventId) => _EventDetailRoute<T>(
    settings: RouteSettings(name: routeNameFor(eventId)),
    builder: (_) => EventDetailScreen(eventId: eventId),
  );

  /// 開著的詳情頁的重載函式，以所在的 route 為 key：同一場活動開了兩份時
  /// 各自登記，關掉上層那份不影響下層。
  static final Map<Route<dynamic>, VoidCallback> _live = {};

  /// 點提醒通知時人已在 [route] 這份詳情頁：就地重載。
  static void refreshRoute(Route<dynamic> route) => _live[route]?.call();

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailRoute<T> extends MaterialPageRoute<T> {
  _EventDetailRoute({required super.builder, super.settings});

  bool changed = false;

  // 返回時沒帶結果（返回鍵、滑動返回）就用這個值。
  @override
  T? get currentResult =>
      changed && true is T ? true as T : super.currentResult;
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  EventDetail? _event;

  /// 活動只回 tribe_id，名稱另外對照；查不到就不顯示相關部落列。
  String? _tribeName;

  List<EventReminder> _reminders = [];
  bool _loading = true;
  Object? _error;
  bool _acting = false; // 參加/退出/取消進行中，避免重複點
  bool _likeBusy = false;
  bool _bookmarkBusy = false;

  /// 商店目錄（頭像＋頭像框，id → item），渲染發起人頭像用。
  Map<String, ShopItem> _itemCatalogById = const {};

  /// 這份詳情頁所在的 route，通知重載的登記 key。
  Route<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && _route == null) {
      _route = route;
      EventDetailScreen._live[route] = _load;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadItemCatalog();
    FcmService.onReminderReceivedForOpenScreen = _onForegroundReminder;
    FcmService.addEventDeletedListener(_onEventDeleted);
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
    final route = _route;
    if (route != null) EventDetailScreen._live.remove(route);
    FcmService.removeEventDeletedListener(_onEventDeleted);
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

  bool _deletedNoticeShown = false;

  /// 前景收到本活動被發起人刪除的推播：說明後關閉這一頁（重載只會得到 404）。
  Future<void> _onEventDeleted(int? eventId) async {
    if (eventId != widget.eventId || !mounted || _deletedNoticeShown) return;
    _deletedNoticeShown = true;
    final title = _event?.title;
    await showEventDeletedDialog(
      context,
      title == null ? '此活動已被發起人刪除。' : '您參加的$title已被發起人刪除。',
    );
    if (!mounted) return;
    _markChanged();
    final route = _route;
    if (route == null || !route.isActive) return;
    final navigator = Navigator.of(context);
    // 詳情頁上面還蓋著別的頁面時，只移除這一頁，不動到上面的頁面。
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
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
      // 詳情與提醒紀錄併行取得。
      final results = await Future.wait([
        EventService.fetchEventDetail(widget.eventId),
        _fetchRemindersSafe(),
      ]);
      if (!mounted) return;
      setState(() {
        _event = results[0] as EventDetail;
        _reminders = results[1] as List<EventReminder>;
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

  /// 動作（參加/退出/取消）成功後與下拉重整的刷新：只更新資料本身，不設
  /// `_loading = true`，避免整頁重建與剛關閉的對話框收尾動畫互撞（觸發
  /// `_dependents.isEmpty` assertion），也不卸載正在上傳或刪除照片的輪播。
  /// 失敗時保留現有畫面，不換成錯誤頁；[reportFailure]（下拉重整、點照片重試）才提示使用者，
  /// 其他背景重取失敗不打擾。
  Future<void> _silentRefresh({bool reportFailure = false}) async {
    final imagesVersion = _imagesVersion;
    try {
      final results = await Future.wait([
        EventService.fetchEventDetail(widget.eventId),
        _fetchRemindersSafe(),
      ]);
      if (!mounted) return;
      final fresh = results[0] as EventDetail;
      final current = _event;
      setState(() {
        // 重取途中發起人剛上傳或刪除照片：這份回應的照片是舊的，保留剛換上的清單。
        _event = imagesVersion != _imagesVersion && current != null
            ? fresh.withImages(current.images)
            : fresh;
        _reminders = results[1] as List<EventReminder>;
      });
    } catch (e, st) {
      debugPrint('[EventDetailScreen] _silentRefresh 失敗：$e');
      debugPrint('$st');
      if (reportFailure && mounted) {
        // 離線時連點重試會一次次失敗：換掉上一則，不讓同樣的提示排成一串。
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(apiErrorMessage(e, fallback: '重新整理失敗，請稍後再試')),
            ),
          );
      }
    }
  }

  /// 使用者自己要求的重整（下拉、點照片重試）：失敗要讓人知道。
  Future<void> _userRefresh() => _silentRefresh(reportFailure: true);

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

  /// 活動資料被這頁改動過，返回時通知列表重載。
  void _markChanged() {
    final route = ModalRoute.of(context);
    if (route is _EventDetailRoute) route.changed = true;
  }

  /// 成功後提示 [success] 並重新整理活動資料。
  Future<void> _runAction(
    Future<void> Function() action, {
    required String success,
  }) {
    return _guarded(() async {
      await action();
      if (!mounted) return;
      _markChanged();
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
      if (e.isBlocked) return _handleBlocked();
      _snack(e.message);
      // 報名尚未開始：畫面狀態過期，重抓讓按鈕換成「報名將於 X 開始」。
      if (e.isRegistrationNotOpen) await _silentRefresh();
    } catch (e) {
      _snack('$failurePrefix：$e');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  /// 403 BLOCKED：與發起人有封鎖關係（畫面還沒重新整理時會發生），重載後詳情會回 404。
  void _handleBlocked() {
    _markChanged(); // 重載後看不到這個活動，列表也要拿掉
    _snack('無法與此活動互動');
    _load();
  }

  void _report() {
    if (blockIfReadOnly()) return;
    showForumReportSheet(
      context,
      targetType: 'event',
      targetId: widget.eventId,
    );
  }

  /// 管理員直接下架他人的活動：活動隱藏並送進違規區等另一位管理員二審。
  Future<void> _adminRemove() async {
    final input = await promptAdminReason(
      context,
      title: '管理員下架活動',
      description: '活動會立刻隱藏、未送出的提醒一併取消，並送進違規區等另一位管理員二審。',
      confirmMessage: '確定下架這個活動？',
      confirmText: '下架',
    );
    if (input == null || !mounted) return;
    try {
      await AdminService.removeEvent(widget.eventId, input.reason);
      showAdminMessage('已下架，等待其他管理員二審');
      if (mounted) Navigator.pop(context, true); // 通知活動列表刷新
    } catch (e) {
      if (mounted) handleAdminError(context, e);
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _event = event);
      if (e is ApiException && e.isBlocked) _handleBlocked();
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _event = event);
      if (e is ApiException && e.isBlocked) _handleBlocked();
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

  /// 發起人在頂端輪播上傳或刪除圖片成功：換成後端回的清單，返回時列表重載換封面。
  /// 每次輪播換上後端回的照片清單就加一，讓較早發出的重取不會蓋回舊照片。
  int _imagesVersion = 0;

  void _onImagesChanged(List<EventImage> images) {
    final event = _event;
    if (event == null) return;
    _imagesVersion++;
    _markChanged();
    setState(() => _event = event.withImages(images));
  }

  /// 照片網址過期（15 分鐘）自動重取詳情的次數；圖片本身壞掉時重取也沒用，
  /// 設上限避免一直重打。手動點重試不受限。
  int _imageAutoRefreshes = 0;
  static const _maxImageAutoRefreshes = 3;
  bool _imageRefreshing = false;

  Future<void> _onImageExpired() async {
    if (_imageRefreshing || _imageAutoRefreshes >= _maxImageAutoRefreshes) {
      return;
    }
    _imageAutoRefreshes++;
    _imageRefreshing = true;
    try {
      await _silentRefresh();
    } finally {
      _imageRefreshing = false;
    }
  }

  // ── 編輯 / 刪除（僅發起人） ────────────────────────────────────
  Future<void> _editEvent() async {
    final event = _event;
    if (event == null || blockIfReadOnly()) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EventComposeScreen(editing: event)),
    );
    if (updated != true || !mounted) return;
    _markChanged();
    await _silentRefresh();
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
    final confirmed = await showConfirmDialog(
      context,
      title: '刪除活動？',
      message: '刪除後將無法復原，已報名的參加者也會看不到這個活動。',
      cancelText: '取消',
      confirmText: '刪除',
    );
    if (confirmed != true) return;
    await _guarded(failurePrefix: '刪除失敗', () async {
      final notified = await EventService.deleteEvent(widget.eventId);
      if (!mounted) return;
      _snack(notified > 0 ? '活動已刪除，已通知 $notified 位報名者' : '活動已刪除');
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
          onRetry: _load,
          seniorMode: seniorMode,
        ),
      );
    }

    final e = _event!;
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: RefreshIndicator(
        onRefresh: _userRefresh,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: EventDetailHero(
                event: e,
                seniorMode: seniorMode,
                onImagesChanged: _onImagesChanged,
                onImageExpired: _onImageExpired,
                onImageRetryTap: _userRefresh,
              ),
            ),
            SliverToBoxAdapter(
              child: EventDetailBody(
                event: e,
                reminders: _reminders,
                seniorMode: seniorMode,
                onToggleLike: _toggleLike,
                onToggleBookmark: _toggleBookmark,
                itemCatalogById: _itemCatalogById,
                tribeName: _tribeName,
              ),
            ),
            // 發起人自己的活動不顯示檢舉。
            if (!e.isHost)
              SliverToBoxAdapter(
                child: Center(
                  child: TextButton.icon(
                    onPressed: _report,
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('檢舉此活動'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.fog),
                  ),
                ),
              ),
            if (!e.isHost && (UserService.cachedUser?.isAdmin ?? false))
              SliverToBoxAdapter(
                child: Center(
                  child: TextButton.icon(
                    onPressed: _adminRemove,
                    icon: const Icon(Icons.gavel_outlined, size: 18),
                    label: const Text('管理員下架'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.dangerDark,
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      bottomNavigationBar: EventActionBar(
        event: e,
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
