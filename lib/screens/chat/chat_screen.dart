// 一對一聊天對話串。訂閱 ChatController 的 WS 事件即時收訊息/已讀，
// 開啟時 markRead，往上滑分頁補歷史；陌生人（未加好友）超過 3 則、或任一方
// 未成年／沒填生日時會收到 NEED_FRIEND，被禁言收到 MUTED，皆用 SnackBar 顯示
// 後端訊息、不猜測前端狀態。
// 對象是刪除中或被鎖帳號（歷史訊息回應的 partner.unavailable）時歷史照常顯示，
// 輸入列停用：送出一定會被後端擋。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_icon_size.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../core/platform/platform_features.dart';
import '../../models/friend_message_model.dart';
import '../../models/friend_model.dart';
import '../../services/account_lock_controller.dart';
import '../../services/chat_socket_service.dart';
import '../../services/friend_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/truku_empty_state.dart';
import '../../models/shop_item.dart';
import '../../services/shop_service.dart';
import '../../shared/widgets/user_avatar.dart';
import '../friends/directed_call_waiting_screen.dart';
import '../friends/public_profile_screen.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/utils/utf16_length_limit.dart';
import '../../shared/widgets/nickname_text.dart';
import '../../shared/widgets/report_sheet.dart';

class ChatScreen extends StatefulWidget {
  /// 對方的好友碼：辨識聊天室、打聊天 API、標題列末碼與點進公開檔案都用它。
  final String friendCode;
  final String? partnerNickname;
  final String? partnerAvatarUrl;

  /// 商店頭像與頭像框：後端有給就用，沒有就退回 [partnerAvatarUrl]。
  final String? avatarId;
  final String? frameId;

  /// 從對方公開檔案進來時為 false：已經在檔案頁了，不必再提供回去的入口。
  final bool linkToProfile;

  const ChatScreen({
    super.key,
    required this.friendCode,
    this.partnerNickname,
    this.partnerAvatarUrl,
    this.avatarId,
    this.frameId,
    this.linkToProfile = true,
  });

  static String routeNameFor(String friendCode) =>
      'chat/${friendCode.toUpperCase()}';

  /// 所有呼叫端都走這個工廠，settings.name 才會一致（推播導頁靠它判斷是否已開著）。
  static Route<T> route<T>({
    required String friendCode,
    String? partnerNickname,
    String? partnerAvatarUrl,
    String? avatarId,
    String? frameId,
    bool linkToProfile = true,
  }) => MaterialPageRoute<T>(
    settings: RouteSettings(name: routeNameFor(friendCode)),
    builder: (_) => ChatScreen(
      friendCode: friendCode,
      partnerNickname: partnerNickname,
      partnerAvatarUrl: partnerAvatarUrl,
      avatarId: avatarId,
      frameId: frameId,
      linkToProfile: linkToProfile,
    ),
  );

  /// 開著的聊天室的重載函式，以所在的 route 為 key：同一人開了兩個聊天室時
  /// 各自登記，關掉上層那個不影響下層。
  static final Map<Route<dynamic>, VoidCallback> _live = {};

  /// 點私訊通知時人已在 [route] 這個聊天室：重抓背景期間漏掉的訊息並標成已讀。
  static void refreshRoute(Route<dynamic> route) => _live[route]?.call();

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  /// 後端 friendMessages.ts 的訊息長度上限。
  static const _messageMax = 2000;

  final List<FriendMessage> _messages = []; // 新到舊排序（index 0 = 最新）
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _sending = false;
  bool _loadingMore = false;

  /// 初次載入還沒回來就連上了：載入的快照可能早於訂閱生效，等載入完再補抓一次。
  bool _catchUpAfterLoad = false;
  String? _nextCursor;

  /// 標題列頭像要查商店目錄才知道 avatarId/frameId 對應的圖。
  Map<String, ShopItem> _itemCatalogById = const {};

  /// 後端回的對象資料，有值就蓋過建構子帶進來的暱稱與頭像；
  /// 還沒載到、或對方不存在／有封鎖關係時為 null。
  ChatPartner? _partner;

  bool get _partnerUnavailable => _partner?.unavailable ?? false;
  String? get _nickname => _partner?.nickname ?? widget.partnerNickname;
  String? get _avatarUrl =>
      _partner == null ? widget.partnerAvatarUrl : _partner!.avatarUrl;
  String? get _avatarId =>
      _partner == null ? widget.avatarId : _partner!.avatarId;
  String? get _frameId => _partner == null ? widget.frameId : _partner!.frameId;

  /// 這個聊天室所在的 route，推播重載的登記 key。
  Route<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && _route == null) {
      _route = route;
      ChatScreen._live[route] = _refreshFromPush;
    }
  }

  @override
  void initState() {
    super.initState();
    chatController.connect();
    chatController.addListener(_onChatEvent);
    _scrollController.addListener(_onScroll);
    _load();
    _markRead();
    _loadItemCatalog();
  }

  Future<void> _loadItemCatalog() async {
    if (_avatarId == null && _frameId == null) return;
    if (_itemCatalogById.isNotEmpty) return;
    try {
      final catalog = await ShopService.fetchItemCatalogCached();
      if (!mounted) return;
      setState(() => _itemCatalogById = catalog);
    } catch (e) {
      debugPrint('Failed to fetch item catalog: $e');
    }
  }

  @override
  void dispose() {
    final route = _route;
    if (route != null) ChatScreen._live.remove(route);
    chatController.removeListener(_onChatEvent);
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 40) {
      _loadMore();
    }
  }

  void _onChatEvent() {
    final event = chatController.lastEvent;
    if (event == null) return;
    if (event.type == ChatSocketEventType.connected) {
      _catchUp();
      return;
    }
    if (!sameFriendCode(event.friendCode, widget.friendCode)) return;
    if (event.type == ChatSocketEventType.message) {
      final m = event.message!;
      // 重連補抓可能已經抓到同一則，依 id 去重。
      if (!mounted || _messages.any((e) => e.id == m.id)) return;
      setState(() => _messages.insert(0, m));
      _markRead();
    } else if (event.type == ChatSocketEventType.read && mounted) {
      final now = DateTime.now();
      setState(() {
        for (var i = 0; i < _messages.length; i++) {
          final m = _messages[i];
          if (m.mine && m.readAt == null) _messages[i] = m.markedRead(now);
        }
      });
    }
  }

  void _refreshFromPush() {
    _load();
    _markRead();
  }

  Future<void> _load() async {
    try {
      final page = await FriendService.getMessages(widget.friendCode);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.messages);
        _nextCursor = page.nextCursor;
        _partner = page.partner;
        _loading = false;
      });
      _loadItemCatalog();
    } catch (e, st) {
      debugPrint('Failed to fetch messages: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() => _loading = false);
    }
    if (_catchUpAfterLoad && mounted) {
      _catchUpAfterLoad = false;
      _catchUp();
    }
  }

  /// 重連後補抓斷線期間的訊息：重抓最新一頁併進清單，不動往上捲的分頁游標；
  /// 與已載入的接不起來（離線期間超過一頁）才整頁替換。
  Future<void> _catchUp() async {
    if (_loading) {
      _catchUpAfterLoad = true;
      return;
    }
    try {
      final page = await FriendService.getMessages(widget.friendCode);
      if (!mounted) return;
      final hadUnread = page.messages.any((m) => !m.mine && m.readAt == null);
      final merged = mergeLatestMessages(_messages, page.messages);
      setState(() {
        _messages
          ..clear()
          ..addAll(merged ?? page.messages);
        if (merged == null) _nextCursor = page.nextCursor;
        _partner = page.partner;
      });
      if (hadUnread) _markRead();
    } catch (e) {
      debugPrint('Failed to catch up messages: $e');
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await FriendService.getMessages(
        widget.friendCode,
        cursor: cursor,
      );
      if (!mounted) return;
      // 等待期間重連補抓整頁替換過清單（游標已換），這一頁接不上，丟棄。
      if (_nextCursor != cursor) {
        setState(() => _loadingMore = false);
        return;
      }
      setState(() {
        _messages.addAll(page.messages);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('Failed to load more messages: $e');
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await FriendService.markRead(widget.friendCode);
    } catch (e) {
      debugPrint('Failed to mark read: $e');
    }
  }

  Future<void> _send() async {
    final body = _inputController.text.trim();
    if (body.isEmpty || _sending) return;
    if (!withinUtf16Limit(context, body, _messageMax, label: '訊息')) return;
    setState(() => _sending = true);
    try {
      final message = await FriendService.sendMessage(widget.friendCode, body);
      if (!mounted) return;
      setState(() {
        _messages.insert(0, message);
        _inputController.clear();
        _sending = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _handleSendError(e);
    } catch (e, st) {
      debugPrint('Failed to send message: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() => _sending = false);
      _showMessage('傳送失敗，請稍後再試');
    }
  }

  void _handleSendError(ApiException e) {
    if (e.isNeedFriend) {
      // 超過 3 則與未成年保護共用此錯誤碼，原因只有後端知道，照它的訊息顯示。
      _showMessage(e.message.isNotEmpty ? e.message : '加對方為好友才能繼續聊天');
      return;
    }
    if (e.isMuted) {
      // 後端訊息已由 ApiClient 接上禁言到期時間（14／30 天不等）。
      _showMessage(e.message);
      return;
    }
    if (e.isRateLimited) {
      _showMessage('操作太頻繁，請稍後再試');
      return;
    }
    if (e.isBlocked) {
      _showMessage('因封鎖關係，無法傳送訊息');
      return;
    }
    if (e.isUserUnavailable) {
      _showMessage('該使用者暫時無法使用');
      return;
    }
    _showMessage(e.message);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _startVideoCall() {
    if (blockIfReadOnly()) return;
    if (_partnerUnavailable) {
      _showMessage('對方暫時無法使用，無法通話');
      return;
    }
    if (!PlatformFeatures.supportsVideoCall) {
      _showMessage(PlatformFeatures.videoCallUnsupportedMessage);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectedCallWaitingScreen(
          calleeFriendCode: widget.friendCode,
          calleeNickname: _nickname,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([seniorModeController, accountLockController]),
    builder: (context, _) => _buildScaffold(seniorModeController.enabled),
  );

  Widget _buildScaffold(bool seniorMode) => Scaffold(
    backgroundColor: AppColors.creamLight,
    body: SafeArea(
      child: Column(
        children: [
          _topBar(seniorMode),
          Expanded(child: _buildBody(seniorMode)),
          _inputBar(seniorMode),
        ],
      ),
    ),
  );

  Widget _partnerAvatar(bool seniorMode) => Opacity(
    opacity: _partnerUnavailable ? 0.55 : 1,
    child: FramedUserAvatar(
      avatarId: _avatarId,
      avatarUrl: _avatarUrl,
      frameId: _frameId,
      itemCatalogById: _itemCatalogById,
      size: seniorMode ? 40 : 32,
      fallbackIconColor: _partnerUnavailable ? AppColors.fog : AppColors.gold,
    ),
  );

  Future<void> _openPartnerProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(friendCode: widget.friendCode),
      ),
    );
  }

  Widget _topBar(bool seniorMode) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
    child: Row(
      children: [
        const AppBackButton(),
        _partnerAvatar(seniorMode),
        const SizedBox(width: 8),
        Expanded(
          child: _partnerUnavailable
              // 暱稱是後端的替代文字，不附末碼；公開檔案也進不去。
              ? Text(
                  _nickname?.isNotEmpty == true ? _nickname! : '暫時無法使用',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleStyle(
                    seniorMode: seniorMode,
                    color: AppColors.fog,
                  ),
                )
              : GestureDetector(
                  // 頭像旁的暱稱是對方公開檔案的入口（好友列表已不再直接進檔案頁）。
                  onTap: widget.linkToProfile ? _openPartnerProfile : null,
                  behavior: HitTestBehavior.opaque,
                  child: NicknameText(
                    _nickname?.isNotEmpty == true ? _nickname! : '未命名旅人',
                    friendCode: widget.friendCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleStyle(
                      seniorMode: seniorMode,
                      color: AppColors.ink,
                    ),
                  ),
                ),
        ),
        IconButton(
          onPressed: _startVideoCall,
          iconSize: AppIconSize.action(seniorMode),
          icon: Icon(
            Icons.videocam_outlined,
            color: accountLockController.locked || _partnerUnavailable
                ? AppColors.fog
                : AppColors.primary,
          ),
          tooltip: '視訊通話',
        ),
      ],
    ),
  );

  Widget _buildBody(bool seniorMode) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_messages.isEmpty) {
      return TrukuEmptyState(
        icon: Icons.chat_bubble_outline,
        message: '還沒有訊息',
        subtitle: '打個招呼開始聊天吧',
        seniorMode: seniorMode,
      );
    }
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _messages.length + (_nextCursor != null ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final isLastMine = i == _messages.indexWhere((m) => m.mine);
        return _bubble(_messages[i], seniorMode, showStatus: isLastMine);
      },
    );
  }

  Widget _bubble(FriendMessage m, bool seniorMode, {required bool showStatus}) {
    final mine = m.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: mine || accountLockController.locked
            ? null
            : () => _reportMessage(m),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : AppColors.cream,
            borderRadius: BorderRadius.circular(16),
            border: mine ? null : Border.all(color: AppColors.creamDeep),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                m.body,
                style: AppTypography.bodyLargeStyle(
                  seniorMode: seniorMode,
                  color: mine ? Colors.white : AppColors.ink,
                ),
              ),
              if (mine && showStatus) ...[
                const SizedBox(height: 2),
                Text(
                  m.isRead ? '已讀' : '已送出',
                  style: AppTypography.captionStyle(
                    seniorMode: seniorMode,
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reportMessage(FriendMessage m) => showReportSheet(
    context,
    title: '檢舉此訊息',
    description: '請說明檢舉的原因，管理員會再確認。',
    hintText: '例如：騷擾、詐騙、不當內容',
    submitLabel: '送出檢舉',
    successMessage: '已送出檢舉',
    // 後端 friendMessages.ts 的 REASON_MAX。
    maxLength: 500,
    onSubmit: (reason) => FriendService.reportMessage(m.id, reason),
    errorMessage: (e) => apiErrorMessage(e, fallback: '檢舉失敗，請稍後再試'),
  );

  Widget _inputBar(bool seniorMode) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: !_inputDisabled,
              minLines: 1,
              maxLines: 4,
              inputFormatters: const [
                Utf16LengthLimitingTextInputFormatter(_messageMax),
              ],
              style: AppTypography.bodyLargeStyle(
                seniorMode: seniorMode,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText: _locked
                    ? '帳號唯讀中，無法傳送訊息'
                    : _partnerUnavailable
                    ? '對方暫時無法使用，無法傳送訊息'
                    : '傳送訊息…',
                hintStyle: AppTypography.bodyLargeStyle(
                  seniorMode: seniorMode,
                  color: AppColors.fog,
                ),
                filled: true,
                fillColor: AppColors.cream,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: AppColors.creamDeep),
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending || _inputDisabled ? null : _send,
            iconSize: AppIconSize.action(seniorMode),
            icon: const Icon(Icons.send, color: AppColors.primary),
          ),
        ],
      ),
    ),
  );

  /// 唯讀帳號不能傳訊息（後端 403 ACCOUNT_LOCKED），輸入列停用。
  bool get _locked => accountLockController.locked;

  bool get _inputDisabled => _locked || _partnerUnavailable;
}
