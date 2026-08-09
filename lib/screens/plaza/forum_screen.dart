import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../models/user_model.dart';
import '../../services/forum_realtime_service.dart';
import '../../services/forum_service.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/truku_widgets.dart';

const _categories = {
  'general': '綜合',
  'culture': '文化',
  'learning': '學習',
  'events': '活動',
  'help': '求助',
};
void _message(BuildContext c, Object e) => ScaffoldMessenger.of(c).showSnackBar(
  SnackBar(content: Text(e is ApiException ? e.message : '操作未完成，請稍後再試')),
);

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});
  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final _scroll = ScrollController(), _realtime = ForumRealtimeService();
  final List<ForumPost> _posts = [];
  String? _category, _cursor;
  bool _loading = false, _more = false, _isAdmin = false;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
    _loadRole();
    _realtime.connect((event) {
      if (mounted && event['type'].toString().startsWith('forum.'))
        _load(reset: true);
    });
  }

  Future<void> _loadRole() async {
    try {
      final user = await UserService.fetchMe();
      if (mounted) setState(() => _isAdmin = user.role == 'admin');
    } catch (_) {}
  }

  @override
  void dispose() {
    _scroll.dispose();
    _realtime.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 240)
      _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || _more || (!reset && _cursor == null)) return;
    if (reset) {
      setState(() {
        _loading = true;
        _cursor = '';
        _posts.clear();
      });
    } else {
      setState(() => _more = true);
    }
    try {
      final page = await ForumService.fetchPosts(
        category: _category,
        cursor: reset ? null : _cursor,
      );
      if (mounted)
        setState(() {
          _posts.addAll(page.posts);
          _cursor = page.nextCursor;
        });
    } catch (e) {
      if (mounted) _message(context, e);
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _more = false;
        });
    }
  }

  Future<void> _compose([ForumPost? post]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ForumComposeScreen(post: post)),
    );
    if (changed == true) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.creamLight,
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildTabBar()),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_posts.isEmpty)
            const SliverToBoxAdapter(child: _ForumEmptyState())
          else
            _buildPostsSection(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    ),
  );

  Widget _buildHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ALANG · 廣場',
                    style: GoogleFonts.crimsonPro(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: AppColors.fog,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '族人交流廣場',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _compose,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: AppColors.creamLight, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '發文',
                      style: GoogleFonts.notoSerifTc(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.creamLight,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                '分享生活、文化與學習的每一刻',
                style: GoogleFonts.crimsonPro(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: AppColors.fog,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _headerIcon(
              Icons.search_rounded,
              '搜尋貼文',
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForumSearchScreen()),
              ),
            ),
            _headerIcon(
              Icons.bookmarks_outlined,
              '收藏貼文',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ForumBookmarksScreen(),
                ),
              ),
            ),
            _headerIcon(
              Icons.notifications_none_rounded,
              '通知中心',
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ForumNotificationsScreen(),
                ),
              ),
            ),
            if (_isAdmin)
              _headerIcon(
                Icons.gpp_maybe_outlined,
                '檢舉管理',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ForumReportAdminScreen(),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _headerIcon(IconData icon, String tooltip, VoidCallback onPressed) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: AppColors.ink,
        visualDensity: VisualDensity.compact,
      );

  Widget _buildTabBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.creamDeep)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _CategoryTab(
            label: '全部',
            selected: _category == null,
            onTap: () => _selectCategory(null),
          ),
          ..._categories.entries.map(
            (e) => _CategoryTab(
              label: e.value,
              selected: _category == e.key,
              onTap: () => _selectCategory(e.key),
            ),
          ),
        ],
      ),
    ),
  );

  void _selectCategory(String? id) {
    setState(() => _category = id);
    _load(reset: true);
  }

  Widget _buildPostsSection() => SliverList(
    delegate: SliverChildBuilderDelegate(
      (c, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              'PATAS · 族人發文',
              style: GoogleFonts.crimsonPro(
                fontStyle: FontStyle.italic,
                fontSize: 10,
                color: AppColors.fog,
                letterSpacing: 3.0,
              ),
            ),
          );
        }
        final index = i - 1;
        if (index >= _posts.length) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ForumPostCard(
          post: _posts[index],
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(
              builder: (_) => ForumDetailScreen(post: _posts[index]),
            ),
          ).then((_) => _load(reset: true)),
        );
      },
      childCount: 1 + _posts.length + (_more ? 1 : 0),
    ),
  );
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.only(right: 22),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              style: GoogleFonts.notoSerifTc(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.fog,
                letterSpacing: 1.0,
              ),
            ),
          ),
          if (selected)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(height: 2, color: AppColors.primary),
            ),
        ],
      ),
    ),
  );
}

class _ForumEmptyState extends StatelessWidget {
  const _ForumEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 76, 24, 24),
    child: Column(
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.creamDeep,
                  shape: BoxShape.circle,
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: Opacity(
                  opacity: 0.13,
                  child: TrukuDiamond(size: 40, color: AppColors.primary),
                ),
              ),
              const Icon(
                Icons.forum_outlined,
                color: AppColors.primary,
                size: 34,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '這個分類還沒有貼文',
          style: GoogleFonts.notoSerifTc(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '下拉重新整理，或成為第一位分享的人。',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.fog),
        ),
      ],
    ),
  );
}

class ForumPostCard extends StatelessWidget {
  const ForumPostCard({super.key, required this.post, required this.onTap});
  final ForumPost post;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
    padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
    decoration: BoxDecoration(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.creamDeep),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.moss,
                    image: post.author.avatarUrl == null
                        ? null
                        : DecorationImage(
                            image: NetworkImage(post.author.avatarUrl!),
                            fit: BoxFit.cover,
                          ),
                    border: const Border.fromBorderSide(
                      BorderSide(color: AppColors.gold, width: 1.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: post.author.avatarUrl != null
                      ? null
                      : Text(
                          post.author.displayName.isEmpty
                              ? '?'
                              : post.author.displayName.substring(0, 1),
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gold,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    post.author.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#${_categories[post.category] ?? post.category}',
                    style: GoogleFonts.crimsonPro(
                      fontStyle: FontStyle.italic,
                      fontSize: 11,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSerifTc(
                color: AppColors.ink,
                fontSize: 17,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              post.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.inkSoft,
                height: 1.55,
                letterSpacing: 0.5,
              ),
            ),
            if (post.imageUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    post.imageUrls.first,
                    height: 164,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '♡ ${post.likeCount}',
                  style: const TextStyle(fontSize: 12, color: AppColors.fog),
                ),
                const SizedBox(width: 18),
                Text(
                  '💬 ${post.commentCount}',
                  style: const TextStyle(fontSize: 12, color: AppColors.fog),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ForumComposeScreen extends StatefulWidget {
  const ForumComposeScreen({super.key, this.post});
  final ForumPost? post;
  @override
  State<ForumComposeScreen> createState() => _ForumComposeScreenState();
}

class _ForumComposeScreenState extends State<ForumComposeScreen> {
  late final TextEditingController _title, _content;
  String _category = 'general';
  bool _saving = false;
  UserModel? _me;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.post?.title);
    _content = TextEditingController(text: widget.post?.content);
    _category = widget.post?.category ?? 'general';
    UserService.fetchMe().then((u) {
      if (mounted) setState(() => _me = u);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      _message(context, '請輸入標題與內容');
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.post == null) {
        await ForumService.createPost(
          category: _category,
          title: _title.text,
          content: _content.text,
          imageUrls: const [],
        );
      } else {
        await ForumService.updatePost(
          widget.post!.id,
          category: _category,
          title: _title.text,
          content: _content.text,
          imageUrls: widget.post!.imageUrls,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _message(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: AppColors.creamLight,
    body: Column(
      children: [
        _buildAppBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategorySegment(),
                _buildAuthorRow(),
                _buildTitleInput(),
                _buildContentInput(),
              ],
            ),
          ),
        ),
        _buildToolBar(),
      ],
    ),
  );

  Widget _buildAppBar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 54, 16, 12),
    decoration: const BoxDecoration(
      color: AppColors.creamLight,
      border: Border(bottom: BorderSide(color: AppColors.creamDeep)),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            '取消',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.inkSoft,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              widget.post == null ? '新發布' : '編輯貼文',
              style: GoogleFonts.notoSerifTc(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: _saving ? null : _save,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _saving ? '發布中…' : '發布',
              style: GoogleFonts.notoSerifTc(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.creamLight,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildCategorySegment() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: Row(
        children: _categories.entries
            .map(
              (e) => Expanded(
                child: _CategorySegmentTab(
                  label: e.value,
                  active: _category == e.key,
                  onTap: () => setState(() => _category = e.key),
                ),
              ),
            )
            .toList(),
      ),
    ),
  );

  Widget _buildAuthorRow() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            image: _me?.avatarUrl == null
                ? null
                : DecorationImage(
                    image: NetworkImage(_me!.avatarUrl!),
                    fit: BoxFit.cover,
                  ),
            border: const Border.fromBorderSide(
              BorderSide(color: AppColors.gold, width: 1.5),
            ),
          ),
          alignment: Alignment.center,
          child: _me?.avatarUrl != null
              ? null
              : Text(
                  (_me?.displayName?.isNotEmpty ?? false)
                      ? _me!.displayName!.substring(0, 1)
                      : '?',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _me?.displayName ?? '',
                style: GoogleFonts.notoSerifTc(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              const Row(
                children: [
                  Icon(Icons.language, size: 11, color: AppColors.fog),
                  SizedBox(width: 4),
                  Text(
                    '公開 · 所有族人都看得到',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.fog,
                      letterSpacing: 0.8,
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

  Widget _buildTitleInput() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: TextField(
      controller: _title,
      maxLength: 120,
      style: GoogleFonts.notoSerifTc(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      decoration: const InputDecoration(
        hintText: '用一句話說明你的分享',
        hintStyle: TextStyle(color: AppColors.fog, fontSize: 16),
        border: InputBorder.none,
        counterText: '',
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      cursorColor: AppColors.primary,
    ),
  );

  Widget _buildContentInput() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
    child: Container(
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(14).copyWith(left: 16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamDeep),
      ),
      child: TextField(
        controller: _content,
        maxLength: 5000,
        maxLines: null,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.ink,
          height: 1.6,
          letterSpacing: 0.5,
        ),
        decoration: const InputDecoration(
          hintText: '今天跟 yaki 學了一個新詞...',
          hintStyle: TextStyle(color: AppColors.fog, fontSize: 15),
          border: InputBorder.none,
          counterText: '',
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        cursorColor: AppColors.primary,
        cursorWidth: 1.5,
      ),
    ),
  );

  Widget _buildToolBar() => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    decoration: const BoxDecoration(
      color: AppColors.creamLight,
      border: Border(top: BorderSide(color: AppColors.creamDeep)),
    ),
    child: Row(
      children: [
        const Spacer(),
        ValueListenableBuilder(
          valueListenable: _content,
          builder: (_, val, _) => Text(
            '${val.text.length} / 5000',
            style: const TextStyle(fontSize: 11, color: AppColors.fog),
          ),
        ),
      ],
    ),
  );
}

class _CategorySegmentTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _CategorySegmentTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.creamLight : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSerifTc(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: active ? AppColors.primary : AppColors.fog,
          letterSpacing: 1.2,
        ),
      ),
    ),
  );
}

class ForumDetailScreen extends StatefulWidget {
  const ForumDetailScreen({super.key, required this.post});
  final ForumPost post;
  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  late ForumPost _post;
  List<ForumComment> _comments = [];
  final _input = TextEditingController();
  final _realtime = ForumRealtimeService();
  bool _sending = false;
  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _load();
    _realtime.connect(_event);
  }

  @override
  void dispose() {
    _input.dispose();
    _realtime.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        ForumService.fetchPost(_post.id),
        ForumService.fetchComments(_post.id),
      ]);
      if (mounted)
        setState(() {
          _post = values[0] as ForumPost;
          _comments = values[1] as List<ForumComment>;
        });
    } catch (e) {
      if (mounted) _message(context, e);
    }
  }

  void _event(Map<String, dynamic> e) {
    if (e['post_id'] != _post.id || !mounted) return;
    if (e['type'] == 'forum.comment.created') {
      setState(() {
        _comments.add(
          ForumComment.fromJson(e['comment'] as Map<String, dynamic>),
        );
        _post = ForumPost(
          id: _post.id,
          category: _post.category,
          title: _post.title,
          content: _post.content,
          imageUrls: _post.imageUrls,
          commentCount: _post.commentCount + 1,
          likeCount: _post.likeCount,
          isLiked: _post.isLiked,
          isBookmarked: _post.isBookmarked,
          isMine: _post.isMine,
          createdAt: _post.createdAt,
          author: _post.author,
        );
      });
    } else {
      _load();
    }
  }

  Future<void> _send() async {
    if (_sending || _input.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final comment = await ForumService.createComment(_post.id, _input.text);
      if (mounted)
        setState(() {
          _comments.add(comment);
          _input.clear();
        });
    } catch (e) {
      if (mounted) _message(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _like() async {
    try {
      final r = await ForumService.toggleLike(_post.id);
      if (mounted)
        setState(
          () => _post = ForumPost(
            id: _post.id,
            category: _post.category,
            title: _post.title,
            content: _post.content,
            imageUrls: _post.imageUrls,
            commentCount: _post.commentCount,
            likeCount: (r['like_count'] as num).toInt(),
            isLiked: r['liked'] == true,
            isBookmarked: _post.isBookmarked,
            isMine: _post.isMine,
            createdAt: _post.createdAt,
            author: _post.author,
          ),
        );
    } catch (e) {
      if (mounted) _message(context, e);
    }
  }

  Future<void> _bookmark() async {
    try {
      final r = await ForumService.toggleBookmark(_post.id);
      if (mounted)
        setState(
          () => _post = ForumPost(
            id: _post.id,
            category: _post.category,
            title: _post.title,
            content: _post.content,
            imageUrls: _post.imageUrls,
            commentCount: _post.commentCount,
            likeCount: _post.likeCount,
            isLiked: _post.isLiked,
            isBookmarked: r['bookmarked'] == true,
            isMine: _post.isMine,
            createdAt: _post.createdAt,
            author: _post.author,
          ),
        );
    } catch (e) {
      if (mounted) _message(context, e);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: AppColors.creamLight,
    appBar: AppBar(
      backgroundColor: AppColors.creamLight,
      surfaceTintColor: Colors.transparent,
      title: const Text('貼文'),
      actions: [
        if (_post.isMine)
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                final ok = await Navigator.push<bool>(
                  c,
                  MaterialPageRoute(
                    builder: (_) => ForumComposeScreen(post: _post),
                  ),
                );
                if (ok == true) _load();
              } else {
                await ForumService.deletePost(_post.id);
                if (c.mounted) Navigator.pop(c);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('編輯')),
              PopupMenuItem(value: 'delete', child: Text('刪除')),
            ],
          ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              ForumPostCard(post: _post, onTap: () {}),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _like,
                        icon: Icon(
                          _post.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                      ),
                      Text('${_post.likeCount}'),
                      IconButton(
                        onPressed: _bookmark,
                        icon: Icon(
                          _post.isBookmarked
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _report(c, postId: _post.id),
                        child: const Text('檢舉'),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              ..._comments.map(
                (x) => Container(
                  margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.creamDeep,
                      child: Text(
                        x.author.displayName.isEmpty
                            ? '?'
                            : x.author.displayName.substring(0, 1),
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ),
                    title: Text(
                      x.author.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(x.content),
                    trailing: TextButton(
                      onPressed: () => _report(c, commentId: x.id),
                      child: const Text('檢舉'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: InputDecoration(
                      hintText: '寫下留言',
                      filled: true,
                      fillColor: AppColors.creamLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(onPressed: _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  Future<void> _report(BuildContext c, {int? postId, int? commentId}) async {
    final text = TextEditingController();
    final yes = await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: const Text('檢舉'),
        content: TextField(
          controller: text,
          decoration: const InputDecoration(hintText: '請填寫檢舉原因'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('送出'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await ForumService.report(
          postId: postId,
          commentId: commentId,
          reason: text.text,
        );
        if (c.mounted)
          ScaffoldMessenger.of(
            c,
          ).showSnackBar(const SnackBar(content: Text('檢舉已送出')));
      } catch (e) {
        if (c.mounted) _message(c, e);
      }
    }
  }
}

class ForumBookmarksScreen extends StatelessWidget {
  const ForumBookmarksScreen({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: AppColors.creamLight,
    appBar: AppBar(
      backgroundColor: AppColors.creamLight,
      surfaceTintColor: Colors.transparent,
      title: const Text('收藏貼文'),
    ),
    body: FutureBuilder<List<ForumPost>>(
      future: ForumService.bookmarks(),
      builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(
          children: s.data!
              .map(
                (p) => ForumPostCard(
                  post: p,
                  onTap: () => Navigator.push(
                    c,
                    MaterialPageRoute(
                      builder: (_) => ForumDetailScreen(post: p),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class ForumSearchScreen extends StatefulWidget {
  const ForumSearchScreen({super.key});
  @override
  State<ForumSearchScreen> createState() => _ForumSearchScreenState();
}

class _ForumSearchScreenState extends State<ForumSearchScreen> {
  final _controller = TextEditingController();
  List<ForumPost> _posts = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    setState(() => _loading = true);
    try {
      final page = await ForumService.fetchPosts(search: keyword);
      if (mounted) setState(() => _posts = page.posts);
    } catch (e) {
      if (mounted) _message(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.creamLight,
    appBar: AppBar(
      backgroundColor: AppColors.creamLight,
      surfaceTintColor: Colors.transparent,
      title: const Text('搜尋貼文'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: '輸入標題或內容關鍵字',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: _search,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _posts.isEmpty
              ? const _ForumEmptyState()
              : ListView(
                  children: _posts
                      .map(
                        (post) => ForumPostCard(
                          post: post,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ForumDetailScreen(post: post),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    ),
  );
}

class ForumNotificationsScreen extends StatefulWidget {
  const ForumNotificationsScreen({super.key});
  @override
  State<ForumNotificationsScreen> createState() =>
      _ForumNotificationsScreenState();
}

class _ForumNotificationsScreenState extends State<ForumNotificationsScreen> {
  late Future<List<ForumNotification>> _future;
  @override
  void initState() {
    super.initState();
    _future = ForumService.notifications();
  }

  Future<void> _open(ForumNotification item) async {
    try {
      await ForumService.markNotificationRead(item.id);
      final post = await ForumService.fetchPost(item.postId);
      if (mounted)
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ForumDetailScreen(post: post)),
        );
      if (mounted) setState(() => _future = ForumService.notifications());
    } catch (e) {
      if (mounted) _message(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.creamLight,
    appBar: AppBar(
      backgroundColor: AppColors.creamLight,
      surfaceTintColor: Colors.transparent,
      title: const Text('通知中心'),
    ),
    body: FutureBuilder<List<ForumNotification>>(
      future: _future,
      builder: (_, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return const _ForumEmptyState();
        return RefreshIndicator(
          onRefresh: () async =>
              setState(() => _future = ForumService.notifications()),
          child: ListView(
            children: snapshot.data!
                .map(
                  (item) => Container(
                    margin: const EdgeInsets.fromLTRB(16, 7, 16, 0),
                    decoration: BoxDecoration(
                      color: item.isRead ? Colors.white : AppColors.cream,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      onTap: () => _open(item),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text(
                          item.actor.displayName.isEmpty
                              ? '?'
                              : item.actor.displayName.substring(0, 1),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        '${item.actor.displayName} 回覆了你的貼文',
                        style: TextStyle(
                          fontWeight: item.isRead
                              ? FontWeight.w500
                              : FontWeight.w800,
                        ),
                      ),
                      subtitle: const Text('點此查看留言內容'),
                      trailing: item.isRead
                          ? null
                          : const Icon(
                              Icons.circle,
                              size: 10,
                              color: AppColors.primary,
                            ),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    ),
  );
}

class ForumReportAdminScreen extends StatefulWidget {
  const ForumReportAdminScreen({super.key});
  @override
  State<ForumReportAdminScreen> createState() => _ForumReportAdminScreenState();
}

class _ForumReportAdminScreenState extends State<ForumReportAdminScreen> {
  late Future<List<ForumReport>> _future;
  @override
  void initState() {
    super.initState();
    _future = ForumService.adminReports();
  }

  Future<void> _review(ForumReport report, String action) async {
    try {
      await ForumService.reviewReport(report.id, action);
      if (mounted) setState(() => _future = ForumService.adminReports());
    } catch (e) {
      if (mounted) _message(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.creamLight,
    appBar: AppBar(
      backgroundColor: AppColors.creamLight,
      surfaceTintColor: Colors.transparent,
      title: const Text('檢舉管理'),
    ),
    body: FutureBuilder<List<ForumReport>>(
      future: _future,
      builder: (_, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return const _ForumEmptyState();
        return ListView(
          children: snapshot.data!
              .map(
                (report) => Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.targetPreview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text('檢舉原因：${report.reason}'),
                      Text(
                        '檢舉人：${report.reporterName}',
                        style: const TextStyle(color: AppColors.fog),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _review(report, 'dismiss'),
                            child: const Text('駁回'),
                          ),
                          TextButton(
                            onPressed: () => _review(report, 'resolve'),
                            child: const Text('標記已處理'),
                          ),
                          FilledButton(
                            onPressed: () => _review(report, 'hide'),
                            child: const Text('隱藏內容'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}
