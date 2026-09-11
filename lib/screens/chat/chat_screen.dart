// 一對一聊天對話串。訂閱 ChatController 的 WS 事件即時收訊息/已讀，
// 開啟時 markRead，往上滑分頁補歷史；陌生人（未加好友）超過 3 則會收到
// NEED_FRIEND，被禁言收到 MUTED，皆用 SnackBar 呈現、不猜測前端狀態。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../core/platform/platform_features.dart';
import '../../models/friend_message_model.dart';
import '../../services/chat_socket_service.dart';
import '../../services/friend_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/truku_empty_state.dart';
import '../friends/directed_call_waiting_screen.dart';

class ChatScreen extends StatefulWidget {
  final int partnerUid;
  final String? partnerNickname;
  final String? partnerAvatarUrl;

  const ChatScreen({
    super.key,
    required this.partnerUid,
    this.partnerNickname,
    this.partnerAvatarUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<FriendMessage> _messages = []; // 新到舊排序（index 0 = 最新）
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _sending = false;
  bool _loadingMore = false;
  int? _nextCursor;

  @override
  void initState() {
    super.initState();
    chatController.connect();
    chatController.addListener(_onChatEvent);
    _scrollController.addListener(_onScroll);
    _load();
    _markRead();
  }

  @override
  void dispose() {
    chatController.removeListener(_onChatEvent);
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 40) {
      _loadMore();
    }
  }

  void _onChatEvent() {
    final event = chatController.lastEvent;
    if (event == null) return;
    if (event.type == ChatSocketEventType.message) {
      final m = event.message!;
      if (m.senderUid == widget.partnerUid || m.recipientUid == widget.partnerUid) {
        if (!mounted) return;
        setState(() => _messages.insert(0, m));
        if (m.senderUid == widget.partnerUid) _markRead();
      }
    } else if (event.type == ChatSocketEventType.read) {
      if (event.byUid == widget.partnerUid && mounted) {
        setState(() {
          for (var i = 0; i < _messages.length; i++) {
            final m = _messages[i];
            if (m.senderUid == UserService.currentUid && m.readAt == null) {
              _messages[i] = FriendMessage(
                id: m.id,
                senderUid: m.senderUid,
                recipientUid: m.recipientUid,
                body: m.body,
                createdAt: m.createdAt,
                readAt: DateTime.now(),
              );
            }
          }
        });
      }
    }
  }

  Future<void> _load() async {
    try {
      final page = await FriendService.getMessages(widget.partnerUid);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.messages);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to fetch messages: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await FriendService.getMessages(widget.partnerUid, cursor: cursor);
      if (!mounted) return;
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
      await FriendService.markRead(widget.partnerUid);
    } catch (e) {
      debugPrint('Failed to mark read: $e');
    }
  }

  Future<void> _send() async {
    final body = _inputController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await FriendService.sendMessage(widget.partnerUid, body);
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
      _showMessage('陌生人最多只能傳 3 則訊息，加對方為好友才能繼續聊天');
      return;
    }
    if (e.isMuted) {
      _showMessage('你已被禁言，暫時無法傳送訊息');
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
    if (e.isProfanity) {
      _showMessage('訊息含不當字詞，請修改後再送出');
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
    if (!PlatformFeatures.supportsVideoCall) {
      _showMessage(PlatformFeatures.videoCallUnsupportedMessage);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectedCallWaitingScreen(
          calleeUid: widget.partnerUid,
          calleeNickname: widget.partnerNickname,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: seniorModeController,
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

  Widget _topBar(bool seniorMode) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
        ),
        Expanded(
          child: Text(
            widget.partnerNickname?.isNotEmpty == true ? widget.partnerNickname! : '未命名旅人',
            style: AppTypography.titleStyle(seniorMode: seniorMode, color: AppColors.ink),
          ),
        ),
        IconButton(
          onPressed: _startVideoCall,
          icon: const Icon(Icons.videocam_outlined, color: AppColors.primary),
          tooltip: '視訊通話',
        ),
      ],
    ),
  );

  Widget _buildBody(bool seniorMode) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        final isLastMine = i ==
            _messages.indexWhere((m) => m.senderUid == UserService.currentUid);
        return _bubble(_messages[i], seniorMode, showStatus: isLastMine);
      },
    );
  }

  Widget _bubble(FriendMessage m, bool seniorMode, {required bool showStatus}) {
    final mine = m.senderUid == UserService.currentUid;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: mine ? null : () => _reportMessage(m),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
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

  Future<void> _reportMessage(FriendMessage m) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ReportDialog(),
    );
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await FriendService.reportMessage(m.id, reason.trim());
      _showMessage('已送出檢舉');
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      debugPrint('Failed to report message: $e');
      _showMessage('檢舉失敗，請稍後再試');
    }
  }

  Widget _inputBar(bool seniorMode) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              style: AppTypography.bodyLargeStyle(seniorMode: seniorMode, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: '傳送訊息…',
                hintStyle: AppTypography.bodyLargeStyle(seniorMode: seniorMode, color: AppColors.fog),
                filled: true,
                fillColor: AppColors.cream,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send, color: AppColors.primary),
          ),
        ],
      ),
    ),
  );
}

class _ReportDialog extends StatefulWidget {
  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('檢舉此訊息'),
    content: TextField(
      controller: _controller,
      maxLines: 3,
      decoration: const InputDecoration(hintText: '請說明檢舉原因'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('送出'),
      ),
    ],
  );
}
