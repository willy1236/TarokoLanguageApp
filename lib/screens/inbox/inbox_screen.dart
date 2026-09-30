// 站內收件匣：論壇回覆、活動、審核處置、官方公告四類通知，依分類分頁。
// 規格：Truku_backend 說明文件/API/收件匣與申訴.md。
//
// 入口：廣場鈴鐺（預選論壇）、活動鈴鐺（預選活動）、個人頁「收件匣」（全部）、
// 公告推播（預選公告）。好友邀請與私訊不在這裡。
// 每個分頁切過去就重抓，已讀狀態以後端為準；點一則即標已讀，去向由
// [inboxTargetFor] 決定。被鎖（唯讀）帳號也能看、能標已讀。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icon_size.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_format.dart';
import '../../models/inbox_models.dart';
import '../../models/shop_item.dart';
import '../../services/inbox_service.dart';
import '../../services/notification_summary_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/shop_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/ephemeral_network_image.dart';
import '../../shared/widgets/nickname_text.dart';
import '../../shared/widgets/truku_empty_state.dart';
import '../../shared/widgets/user_avatar.dart';
import '../events/event_detail_screen.dart';
import '../events/widgets/tribe_event_push_sheet.dart';
import '../forum/forum_author_code.dart';
import '../forum/forum_detail_screen.dart';
import '../forum/forum_theme.dart';
import '../moderation/moderation_case_screen.dart';
import 'announcement_detail_screen.dart';

/// 分頁順序；category 為 null 是「全部」。
const _tabs = <({String label, String? category})>[
  (label: '全部', category: null),
  (label: '論壇', category: InboxCategory.forum),
  (label: '活動', category: InboxCategory.event),
  (label: '審核', category: InboxCategory.moderation),
  (label: '公告', category: InboxCategory.announcement),
];

class InboxScreen extends StatefulWidget {
  /// 一開始停在哪個分類；null 為「全部」。
  final String? initialCategory;

  const InboxScreen({super.key, this.initialCategory});

  static Route<void> route({String? initialCategory}) =>
      MaterialPageRoute<void>(
        builder: (_) => InboxScreen(initialCategory: initialCategory),
      );

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: _tabs.length,
    vsync: this,
    initialIndex: _initialIndex(),
  );

  /// 論壇回覆者頭像要查商店目錄才知道 avatarId／frameId 對應的圖。
  Map<String, ShopItem> _itemCatalogById = const {};

  int _initialIndex() {
    final i = _tabs.indexWhere((t) => t.category == widget.initialCategory);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    NotificationSummaryService.refresh();
    _loadItemCatalog();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadItemCatalog() async {
    try {
      final catalog = await ShopService.fetchItemCatalogCached();
      if (!mounted) return;
      setState(() => _itemCatalogById = catalog);
    } catch (e) {
      debugPrint('InboxScreen: 取得商店目錄失敗，頭像顯示預設圖示：$e');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
    builder: (context, _) => Theme(
      data: forumTheme(context),
      child: _buildScaffold(seniorModeController.enabled),
    ),
  );

  Widget _buildScaffold(bool seniorMode) => Scaffold(
    backgroundColor: AppColors.creamLight,
    appBar: AppBar(
      leading: const AppBackButton(),
      backgroundColor: AppColors.creamLight,
      elevation: 0,
      foregroundColor: AppColors.ink,
      title: Text(
        '收件匣',
        style: AppTypography.titleStyle(
          seniorMode: seniorMode,
          color: AppColors.ink,
        ),
      ),
      actions: [
        IconButton(
          tooltip: '推播設定',
          icon: const Icon(Icons.settings_outlined),
          iconSize: AppIconSize.action(seniorMode),
          onPressed: () => showTribeEventPushSheet(context),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(seniorMode ? 56 : 46),
        child: ValueListenableBuilder<NotificationSummary>(
          valueListenable: NotificationSummaryService.notifier,
          builder: (context, summary, _) => TabBar(
            controller: _tabController,
            labelColor: AppColors.ink,
            unselectedLabelColor: AppColors.fog,
            indicatorColor: AppColors.primary,
            labelPadding: EdgeInsets.zero,
            labelStyle: AppTypography.bodyStyle(
              seniorMode: seniorMode,
            ).copyWith(fontWeight: FontWeight.w600),
            tabs: [
              for (final tab in _tabs)
                Tab(
                  child: Badge(
                    isLabelVisible: summary.inbox.of(tab.category) > 0,
                    smallSize: 7,
                    backgroundColor: AppColors.primary,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(tab.label),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: [
        for (final tab in _tabs)
          _InboxTab(
            key: ValueKey('inbox-${tab.category}'),
            category: tab.category,
            seniorMode: seniorMode,
            itemCatalogById: _itemCatalogById,
          ),
      ],
    ),
  );
}

class _InboxTab extends StatefulWidget {
  final String? category;
  final bool seniorMode;
  final Map<String, ShopItem> itemCatalogById;

  const _InboxTab({
    super.key,
    required this.category,
    required this.seniorMode,
    required this.itemCatalogById,
  });

  @override
  State<_InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<_InboxTab> {
  final _scrollController = ScrollController();
  final List<InboxItem> _items = [];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _markingAll = false;
  Object? _error;

  /// 每次重載加一：晚回來的舊分頁不接到新列表上。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) _loadMore();
  }

  /// 重抓第一頁。公告圖片是限時網址，過期時也是靠這裡拿新的。
  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final page = await InboxService.fetch(category: widget.category);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.pageInfo.nextCursor;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (_loadingMore || _loading || cursor == null) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await InboxService.fetch(
        category: widget.category,
        cursor: cursor,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.pageInfo.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _loadingMore = false);
      _toast(apiErrorMessage(e));
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await InboxService.markAllRead(category: widget.category);
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].markedRead();
        }
      });
    } catch (e) {
      if (mounted) _toast(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _open(InboxItem item) async {
    if (!item.isRead) {
      final i = _items.indexOf(item);
      if (i >= 0) setState(() => _items[i] = item.markedRead());
      // 標記失敗不該擋住導頁，紅點下次進來會再對齊。
      InboxService.markRead([
        item.id,
      ]).catchError((Object e) => debugPrint('InboxScreen: 標記已讀失敗：$e'));
    }
    switch (inboxTargetFor(item)) {
      case InboxOpenPost(:final postId, :final commentId):
        await Navigator.push(
          context,
          ForumDetailScreen.route(postId: postId, focusCommentId: commentId),
        );
      case InboxOpenEvent(:final eventId):
        await Navigator.push(context, EventDetailScreen.route<void>(eventId));
      case InboxOpenAnnouncement():
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AnnouncementDetailScreen(item: item),
          ),
        );
      case InboxGone(:final message):
        _toast(message);
      case InboxOpenCase(:final caseId):
        await Navigator.push(context, ModerationCaseScreen.route(caseId));
      case InboxShowBody(:final refreshMe):
        if (refreshMe) {
          UserService.fetchMe(forceRefresh: true).then<void>(
            (_) {},
            onError: (Object e) => debugPrint('權限變更通知後重抓 /api/me 失敗：$e'),
          );
        }
        await _showBody(item);
    }
  }

  Future<void> _showBody(InboxItem item) => showDialog<void>(
    context: context,
    builder: (ctx) => AppDialog(
      title: item.title,
      message: item.body ?? '',
      primaryText: '知道了',
      onPrimary: () => Navigator.pop(ctx),
    ),
  );

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final seniorMode = widget.seniorMode;
    if (_loading) return const TrukuLoadingView();
    if (_error != null) {
      return TrukuErrorView(
        error: _error,
        onRetry: _load,
        seniorMode: seniorMode,
      );
    }
    return Column(
      children: [
        _header(seniorMode),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _load,
            child: _items.isEmpty ? _empty(seniorMode) : _list(seniorMode),
          ),
        ),
      ],
    );
  }

  /// 這個分類的未讀數與「全部已讀」。未讀數讀全域 summary，標已讀後會跟著變。
  Widget _header(bool seniorMode) =>
      ValueListenableBuilder<NotificationSummary>(
        valueListenable: NotificationSummaryService.notifier,
        builder: (context, summary, _) {
          final unread = summary.inbox.of(widget.category);
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 4, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    unread > 0 ? '未讀 ${badgeLabel(unread)} 則' : '沒有未讀通知',
                    style: AppTypography.captionStyle(
                      seniorMode: seniorMode,
                      color: AppColors.fog,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: unread == 0 || _markingAll ? null : _markAllRead,
                  child: Text(
                    '全部已讀',
                    style: AppTypography.bodyStyle(
                      seniorMode: seniorMode,
                      color: unread == 0 ? AppColors.fog : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

  Widget _empty(bool seniorMode) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.only(top: AppSpacing.xl),
    children: [
      TrukuEmptyState(
        icon: Icons.notifications_none,
        message: '還沒有通知',
        subtitle: switch (widget.category) {
          InboxCategory.forum => '有人回覆你的貼文或留言時，會出現在這裡。',
          InboxCategory.event => '活動提醒、取消或下架，以及部落的新活動，會出現在這裡。',
          InboxCategory.moderation => '內容審核與帳號相關的通知，會出現在這裡。',
          InboxCategory.announcement => '官方公告會出現在這裡。',
          _ => '論壇回覆、活動、審核與官方公告的通知，會出現在這裡。',
        },
        seniorMode: seniorMode,
        scrollable: false,
      ),
    ],
  );

  Widget _list(bool seniorMode) => ListView.separated(
    controller: _scrollController,
    physics: const AlwaysScrollableScrollPhysics(),
    itemCount: _items.length + (_nextCursor != null ? 1 : 0),
    separatorBuilder: (_, _) =>
        const Divider(height: 1, color: AppColors.creamDeep),
    itemBuilder: (context, i) {
      if (i >= _items.length) {
        return const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      }
      final item = _items[i];
      return _InboxTile(
        item: item,
        seniorMode: seniorMode,
        itemCatalogById: widget.itemCatalogById,
        onTap: () => _open(item),
      );
    },
  );
}

class _InboxTile extends StatelessWidget {
  final InboxItem item;
  final bool seniorMode;
  final Map<String, ShopItem> itemCatalogById;
  final VoidCallback onTap;

  const _InboxTile({
    required this.item,
    required this.seniorMode,
    required this.itemCatalogById,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTypography.bodyLargeStyle(
      seniorMode: seniorMode,
      color: AppColors.ink,
    ).copyWith(fontWeight: FontWeight.w600);
    final actor = item.actor;
    final body = _bodyText();
    return Material(
      color: item.isRead ? AppColors.creamLight : AppColors.cream,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: seniorMode ? AppSpacing.md : 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _leading(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (actor != null)
                      Text.rich(
                        TextSpan(
                          style: titleStyle,
                          children: [
                            nicknameSpan(
                              actor.displayName,
                              actor.othersFriendCode,
                              style: const TextStyle(color: AppColors.ink),
                            ),
                            TextSpan(
                              text: item.kind == 'reply_comment'
                                  ? ' 回覆了你的留言'
                                  : ' 回覆了你的貼文',
                            ),
                          ],
                        ),
                      )
                    else
                      Text(item.title, style: titleStyle),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStyle(
                          seniorMode: seniorMode,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      formatRelativeTime(item.createdAt),
                      style: AppTypography.captionStyle(
                        seniorMode: seniorMode,
                        color: AppColors.fog,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 6),
                  child: Semantics(
                    key: const ValueKey('inbox-unread'),
                    label: '未讀',
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 論壇回覆的內文是貼文標題，貼文已刪除時後端給 null。
  String _bodyText() {
    final body = item.body;
    if (body != null && body.isNotEmpty) return body;
    return item.category == InboxCategory.forum ? '（貼文已刪除）' : '';
  }

  Widget _leading() {
    final size = seniorMode ? 48.0 : 40.0;
    final actor = item.actor;
    if (actor != null) {
      return FramedUserAvatar(
        avatarId: actor.avatarId,
        avatarUrl: actor.avatarUrl,
        frameId: actor.frameId,
        itemCatalogById: itemCatalogById,
        size: size,
        fallbackIconColor: AppColors.gold,
      );
    }
    final imageUrl = item.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return EphemeralNetworkImage(url: imageUrl, width: size, height: size);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12),
      ),
      child: Icon(
        switch (item.category) {
          InboxCategory.forum => Icons.forum_outlined,
          InboxCategory.event => Icons.event_outlined,
          InboxCategory.moderation => Icons.gavel_outlined,
          InboxCategory.announcement => Icons.campaign_outlined,
          _ => Icons.notifications_none,
        },
        size: size * 0.5,
        color: AppColors.primary,
      ),
    );
  }
}
