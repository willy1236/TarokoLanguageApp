import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../services/forum_realtime_service.dart';
import '../../services/forum_service.dart';

const _categories = {
  'general': 'General',
  'culture': 'Culture',
  'learning': 'Learning',
  'events': 'Events',
  'help': 'Help',
};
void _message(BuildContext c, Object e) => ScaffoldMessenger.of(c).showSnackBar(
  SnackBar(
    content: Text(
      e is ApiException ? e.message : 'Unable to complete this action',
    ),
  ),
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
  bool _loading = true, _more = false;
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
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _compose,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.edit),
      label: const Text('Post'),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'ALANG FORUM',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForumBookmarksScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.bookmarks_outlined),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip(null, 'All'),
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
                      itemCount: _posts.length + (_more ? 1 : 0),
                      itemBuilder: (c, i) {
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
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _category == id,
      onSelected: (_) {
        setState(() => _category = id);
        _load(reset: true);
      },
    ),
  );
}

class ForumPostCard extends StatelessWidget {
  const ForumPostCard({super.key, required this.post, required this.onTap});
  final ForumPost post;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => Card(
    margin: const EdgeInsets.fromLTRB(14, 8, 14, 4),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _categories[post.category] ?? post.category,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              post.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(post.content, maxLines: 3, overflow: TextOverflow.ellipsis),
            if (post.imageUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    post.imageUrls.first,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              '${post.author.displayName}  ·  ${post.likeCount} likes  ·  ${post.commentCount} comments',
              style: Theme.of(c).textTheme.bodySmall,
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
    appBar: AppBar(title: Text(widget.post == null ? 'New post' : 'Edit post')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          DropdownButtonFormField(
            value: _category,
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
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          Expanded(
            child: TextField(
              controller: _content,
              maxLength: 5000,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                labelText: 'What would you like to share?',
                alignLabelWithHint: true,
              ),
            ),
          ),
          Wrap(
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
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Uploading...' : 'Publish'),
          ),
        ],
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
    appBar: AppBar(
      title: const Text('Post'),
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
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
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
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _like,
                      icon: Icon(
                        _post.isLiked ? Icons.favorite : Icons.favorite_border,
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
                      child: const Text('Report'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ..._comments.map(
                (x) => ListTile(
                  title: Text(x.author.displayName),
                  subtitle: Text(x.content),
                  trailing: TextButton(
                    onPressed: () => _report(c, commentId: x.id),
                    child: const Text('Report'),
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment',
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
        title: const Text('Report'),
        content: TextField(
          controller: text,
          decoration: const InputDecoration(hintText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Send'),
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
          ).showSnackBar(const SnackBar(content: Text('Report sent')));
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
    appBar: AppBar(title: const Text('Saved posts')),
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
