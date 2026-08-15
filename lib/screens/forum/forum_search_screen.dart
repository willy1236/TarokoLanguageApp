// 關鍵字搜尋。
//
// 後端用 pg_trgm 做子字串比對，沒有相關度排序，結果依 id 遞減，
// 所以介面不宣稱「最相關」，只說「搜尋結果」。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import 'forum_theme.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import 'forum_board_view.dart';
import 'forum_detail_screen.dart';

class ForumSearchScreen extends StatefulWidget {
  final List<ForumBoard> boards;

  /// 在搜尋結果裡改了收藏狀態時回報，讓推開這一頁的列表同步書籤圖示。
  final void Function(int postId, bool bookmarked)? onBookmarkChanged;

  const ForumSearchScreen({
    super.key,
    this.boards = const [],
    this.onBookmarkChanged,
  });

  @override
  State<ForumSearchScreen> createState() => _ForumSearchScreenState();
}

class _ForumSearchScreenState extends State<ForumSearchScreen> {
  final _controller = TextEditingController();
  final _boardViewKey = GlobalKey<ForumBoardViewState>();
  String? _query;
  String? _boardSlug;
  String? _hint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.length < ForumService.searchMin ||
        text.length > ForumService.searchMax) {
      setState(() {
        _hint = '請輸入 ${ForumService.searchMin}-${ForumService.searchMax} 字的關鍵字';
        _query = null;
      });
      return;
    }
    setState(() {
      _hint = null;
      _query = text;
    });
  }

  @override
  Widget build(BuildContext context) =>
      Theme(data: forumTheme(context), child: _buildScaffold(context));

  Widget _buildScaffold(BuildContext context) {
    final query = _query;
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: '搜尋貼文',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(onPressed: _submit, icon: const Icon(Icons.search)),
        ],
      ),
      body: Column(
        children: [
          if (widget.boards.isNotEmpty) _boardFilter(),
          if (_hint != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_hint!, style: const TextStyle(color: AppColors.fog)),
            ),
          if (query == null && _hint == null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                '輸入關鍵字開始搜尋',
                style: GoogleFonts.notoSerifTc(color: AppColors.fog),
              ),
            ),
          if (query != null)
            Expanded(
              child: ForumBoardView(
                key: _boardViewKey,
                reloadKey: '$query|$_boardSlug',
                emptyMessage: '找不到符合的貼文',
                // 搜尋沒有「比某 id 新」語意，下拉刷新一律整份重載，
                // 所以 loadPage 只需按 cursor 分頁。
                prependOnRefresh: false,
                loadPage: ({cursor, after}) => ForumService.search(
                  query,
                  board: _boardSlug,
                  cursor: cursor,
                ),
                toggleLike: ForumService.likePost,
                toggleBookmark: (postId, {required add}) async {
                  final result = await ForumService.bookmarkPost(
                    postId,
                    add: add,
                  );
                  widget.onBookmarkChanged?.call(postId, result);
                  return result;
                },
                onOpenPost: (post) async {
                  final result = await Navigator.push<ForumDetailResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForumDetailScreen(
                        postId: post.id,
                        onPostChanged: (p) {
                          _boardViewKey.currentState?.replacePost(p);
                          widget.onBookmarkChanged?.call(p.id, p.isBookmarked);
                        },
                      ),
                    ),
                  );
                  if (result == null) return;
                  if (result.deleted) {
                    _boardViewKey.currentState?.removePost(post.id);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _boardFilter() => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _chip('全部看板', null),
        for (final board in widget.boards) _chip(board.name, board.slug),
      ],
    ),
  );

  /// 選中態刻意只用淡淡的酒紅底加同色文字與邊框：整片深色會蓋掉文字，
  /// 太淡又看不出選了哪一個，所以底色壓在 0.16、靠邊框與文字顏色補足對比。
  Widget _chip(String label, String? slug) {
    final selected = _boardSlug == slug;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        backgroundColor: AppColors.cream,
        selectedColor: AppColors.primary.withValues(alpha: 0.16),
        labelStyle: TextStyle(
          fontSize: 13,
          color: selected ? AppColors.primary : AppColors.inkSoft,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.45)
              : AppColors.creamDeep,
        ),
        onSelected: (_) => setState(() => _boardSlug = slug),
      ),
    );
  }
}
