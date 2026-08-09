import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../services/forum_realtime_service.dart';
import '../../services/forum_service.dart';

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
  bool _loading = false, _more = false;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
    _realtime.connect((event) {
      if (mounted && event['type'].toString().startsWith('forum.'))
        _load(reset: true);
    });
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
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDeep, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x337A1F1A),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ALANG',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '族人交流廣場',
                              style: TextStyle(
                                color: Color(0xFFF2E8D5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '收藏貼文',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForumBookmarksScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.bookmarks_outlined),
                        color: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '分享生活、文化與學習的每一刻',
                          style: TextStyle(color: Color(0xFFE8DBC0)),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _compose,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                        ),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('發文'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip(null, '全部'),
                ..._categories.entries.map((e) => _chip(e.key, e.value)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: _posts.isEmpty
                          ? 1
                          : _posts.length + (_more ? 1 : 0),
                      itemBuilder: (c, i) {
                        if (_posts.isEmpty) {
                          return const _ForumEmptyState();
                        }
                        if (i >= _posts.length)
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        return ForumPostCard(
                          post: _posts[i],
                          onTap: () => Navigator.push(
                            c,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ForumDetailScreen(post: _posts[i]),
                            ),
                          ).then((_) => _load(reset: true)),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _chip(String? id, String label) => Padding(
    padding: const EdgeInsets.only(right: 9),
    child: ChoiceChip(
      showCheckmark: false,
      label: Text(label),
      selected: _category == id,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: _category == id ? AppColors.primary : AppColors.creamDeep,
      ),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: _category == id ? Colors.white : AppColors.inkSoft,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) {
        setState(() => _category = id);
        _load(reset: true);
      },
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
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: AppColors.creamDeep,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.forum_outlined,
            color: AppColors.primary,
            size: 34,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '這個分類還沒有貼文',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.creamDeep),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _categories[post.category] ?? post.category,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.fog),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 19,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                post.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.inkSoft, height: 1.45),
              ),
              if (post.imageUrls.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: AppColors.creamDeep),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.moss,
                    backgroundImage: post.author.avatarUrl == null
                        ? null
                        : NetworkImage(post.author.avatarUrl!),
                    child: post.author.avatarUrl == null
                        ? Text(
                            post.author.displayName.isEmpty
                                ? '?'
                                : post.author.displayName.substring(0, 1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.author.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.favorite_border,
                    size: 17,
                    color: AppColors.fog,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.likeCount}',
                    style: const TextStyle(color: AppColors.fog),
                  ),
                  const SizedBox(width: 13),
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: AppColors.fog,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.commentCount}',
                    style: const TextStyle(color: AppColors.fog),
                  ),
                ],
              ),
            ],
          ),
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
  final List<XFile> _files = [];
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.post?.title);
    _content = TextEditingController(text: widget.post?.content);
    _category = widget.post?.category ?? 'general';
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final x = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (mounted) setState(() => _files.addAll(x.take(4 - _files.length)));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final urls = <String>[...?(widget.post?.imageUrls)];
      for (final file in _files) {
        final bytes = await file.readAsBytes();
        urls.add(
          await ForumService.uploadImage(
            bytes: bytes,
            filename: file.name,
            mimeType: file.mimeType ?? 'image/jpeg',
          ),
        );
      }
      if (widget.post == null) {
        await ForumService.createPost(
          category: _category,
          title: _title.text,
          content: _content.text,
          imageUrls: urls,
        );
      } else {
        await ForumService.updatePost(
          widget.post!.id,
          category: _category,
          title: _title.text,
          content: _content.text,
          imageUrls: urls,
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
    appBar: AppBar(
      backgroundColor: AppColors.creamLight,
      surfaceTintColor: Colors.transparent,
      title: Text(widget.post == null ? '新增貼文' : '編輯貼文'),
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField(
              value: _category,
              decoration: InputDecoration(
                labelText: '貼文分類',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _categories.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            TextField(
              controller: _title,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: '標題',
                hintText: '用一句話說明你的分享',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _content,
                maxLength: 5000,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  labelText: '想和大家分享什麼？',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Wrap(
                spacing: 8,
                children: [
                  ..._files.map(
                    (f) => FutureBuilder<Uint8List>(
                      future: f.readAsBytes(),
                      builder: (_, s) => s.hasData
                          ? Image.memory(
                              s.data!,
                              height: 65,
                              width: 65,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox(height: 65, width: 65),
                    ),
                  ),
                  if (_files.length < 4)
                    IconButton(
                      onPressed: _pick,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(_saving ? '上傳中…' : '發布貼文'),
            ),
          ],
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
    appBar: AppBar(title: const Text('收藏貼文')),
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
