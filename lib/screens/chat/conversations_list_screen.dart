// 聊天對話清單。入口：好友列表右上角訊息圖示。
// 每列顯示對方暱稱、最後一則訊息預覽、未讀徽章；點擊進對話串。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../models/friend_message_model.dart';
import '../../models/shop_item.dart';
import '../../services/chat_socket_service.dart';
import '../../services/friend_service.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/shop_service.dart';
import '../../shared/widgets/truku_empty_state.dart';
import '../../shared/widgets/user_avatar.dart';
import 'chat_screen.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  List<Conversation>? _conversations;
  bool _loading = true;
  Map<String, ShopItem> _itemCatalogById = const {};

  @override
  void initState() {
    super.initState();
    chatController.connect();
    chatController.addListener(_onChatEvent);
    _load();
    _loadItemCatalog();
  }

  Future<void> _loadItemCatalog() async {
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
    chatController.removeListener(_onChatEvent);
    super.dispose();
  }

  void _onChatEvent() {
    final event = chatController.lastEvent;
    if (event == null) return;
    if (event.type == ChatSocketEventType.message) _load();
  }

  Future<void> _load() async {
    try {
      final conversations = await FriendService.getConversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Failed to fetch conversations: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _conversations = const [];
        _loading = false;
      });
    }
  }

  Future<void> _openChat(Conversation c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          partnerUid: c.partnerUid,
          partnerNickname: c.nickname,
          partnerAvatarUrl: c.avatarUrl,
        ),
      ),
    );
    _load();
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
            '訊息',
            style: AppTypography.titleStyle(seniorMode: seniorMode, color: AppColors.ink),
          ),
        ),
      ],
    ),
  );

  Widget _buildBody(bool seniorMode) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    final conversations = _conversations ?? const [];
    if (conversations.isEmpty) {
      return TrukuEmptyState(
        icon: Icons.chat_bubble_outline,
        message: '還沒有對話',
        subtitle: '從好友列表點開對方即可開始聊天',
        seniorMode: seniorMode,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: conversations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _conversationCard(conversations[i], seniorMode),
      ),
    );
  }

  Widget _conversationCard(Conversation c, bool seniorMode) => GestureDetector(
    onTap: () => _openChat(c),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Row(
        children: [
          _avatar(c, seniorMode),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.nickname?.isNotEmpty == true ? c.nickname! : '未命名旅人',
                  style: AppTypography.bodyLargeStyle(seniorMode: seniorMode, color: AppColors.ink),
                ),
                if (c.lastMessage != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    c.lastMessage!.mine ? '你：${c.lastMessage!.body}' : c.lastMessage!.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.captionStyle(seniorMode: seniorMode, color: AppColors.fog),
                  ),
                ],
              ],
            ),
          ),
          if (c.unreadCount > 0) _unreadBadge(c.unreadCount, seniorMode),
        ],
      ),
    ),
  );

  Widget _unreadBadge(int count, bool seniorMode) => Container(
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: AppTypography.captionStyle(seniorMode: seniorMode, color: Colors.white),
    ),
  );

  Widget _avatar(Conversation c, bool seniorMode) {
    final size = seniorMode ? 52.0 : 44.0;
    return Container(
      decoration: c.frameId == null
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.5),
            )
          : null,
      child: FramedUserAvatar(
        avatarId: c.avatarId,
        avatarUrl: c.avatarUrl,
        frameId: c.frameId,
        itemCatalogById: _itemCatalogById,
        size: size,
        fallbackIconColor: AppColors.gold,
        fallback: DecoratedBox(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ink),
          child: Center(
            child: Text(
              c.nickname?.characters.firstOrNull ?? '?',
              style: AppTypography.bodyLargeStyle(color: AppColors.gold),
            ),
          ),
        ),
      ),
    );
  }
}
