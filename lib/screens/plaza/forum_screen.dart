import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';
import '../../services/forum_realtime_service.dart';

const _categories = <String, String>{
  'general': '全部',
  'culture': '文化',
  'learning': '學習',
  'events': '活動',
  'help': '求助',
};

class ForumScreen extends StatefulWidget {
  const ForumScreen({super.key});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  String? _category;
  late Future<List<ForumPost>> _posts;
  final _realtime = ForumRealtimeService();

  @override
  void initState() {
    super.initState();
    _posts = ForumService.fetchPosts();
    _realtime.connect((event) {
      if (event['type'] == 'forum.comment.created' && mounted) _reload();
    });
  }

  @override
  void dispose() {
    _realtime.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final request = ForumService.fetchPosts(category: _category);
    setState(() => _posts = request);
    await request;
  }

  Future<void> _openComposer() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ForumComposeScreen()),
    );
    if (created == true && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.creamLight,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('發表貼文'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ALANG FORUM', style: GoogleFonts.crimsonPro(
                          color: AppColors.primary, letterSpacing: 2.5, fontSize: 13,
                        )),
                        const SizedBox(height: 3),
                        Text('族人交流論壇', style: GoogleFonts.notoSerifTc(
                          color: AppColors.ink, fontSize: 26, fontWeight: FontWeight.w700,
                        )),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '重新整理',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 45,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final item = _categories.entries.elementAt(index);
                  final selected = _category == item.key || (item.key == 'general' && _category == null);
                  return ChoiceChip(
                    label: Text(item.value),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: selected ? AppColors.creamLight : AppColors.inkSoft),
                    side: const BorderSide(color: AppColors.creamDeep),
                    onSelected: (_) {
                      setState(() => _category = item.key == 'general' ? null : item.key);
                      _reload();
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1, color: AppColors.creamDeep),
            Expanded(
              child: FutureBuilder<List<ForumPost>>(
                future: _posts,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (snapshot.hasError) return _ForumError(onRetry: _reload, error: snapshot.error);
                  final posts = snapshot.data ?? const [];
                  if (posts.isEmpty) return const _EmptyForum();
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _reload,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: posts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => _PostCard(
                        post: posts[index],
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ForumDetailScreen(post: posts[index]),
                        )),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.onTap});
  final ForumPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                  backgroundColor: AppColors.moss,
                  foregroundColor: Colors.white,
                  child: Text(post.author.displayName.isEmpty ? '?' : post.author.displayName.characters.first),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(post.author.displayName, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700)),
                  Text(_timeAgo(post.createdAt), style: const TextStyle(color: AppColors.fog, fontSize: 12)),
                ])),
                _CategoryBadge(category: post.category),
              ]),
              const SizedBox(height: 12),
              Text(post.title, style: GoogleFonts.notoSerifTc(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(post.content, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.inkSoft, height: 1.45)),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.chat_bubble_outline, size: 17, color: AppColors.fog),
                const SizedBox(width: 5),
                Text('${post.commentCount} 則回覆', style: const TextStyle(color: AppColors.fog, fontSize: 13)),
              ]),
            ]),
          ),
        ),
      );
}

class ForumDetailScreen extends StatefulWidget {
  const ForumDetailScreen({required this.post, super.key});
  final ForumPost post;
  @override
  State<ForumDetailScreen> createState() => _ForumDetailScreenState();
}

class _ForumDetailScreenState extends State<ForumDetailScreen> {
  late Future<List<ForumComment>> _comments;
  final _commentController = TextEditingController();
  bool _sending = false;
  @override
  void initState() { super.initState(); _comments = ForumService.fetchComments(widget.post.id); }
  @override
  void dispose() { _commentController.dispose(); super.dispose(); }

  Future<void> _send() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ForumService.createComment(widget.post.id, content);
      _commentController.clear();
      setState(() => _comments = ForumService.fetchComments(widget.post.id));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.creamLight,
    appBar: AppBar(backgroundColor: AppColors.creamLight, foregroundColor: AppColors.ink, title: const Text('貼文內容')),
    body: Column(children: [
      Expanded(child: FutureBuilder<List<ForumComment>>(
        future: _comments,
        builder: (_, snapshot) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PostCard(post: widget.post, onTap: () {}),
            const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Text('回覆', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink))),
            if (snapshot.connectionState != ConnectionState.done) const Center(child: CircularProgressIndicator()),
            ...?snapshot.data?.map((comment) => _CommentTile(comment: comment)),
          ],
        ),
      )),
      SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(children: [Expanded(child: TextField(controller: _commentController, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: '寫下你的回覆…', filled: true))), IconButton(onPressed: _sending ? null : _send, icon: const Icon(Icons.send, color: AppColors.primary))]),
      )),
    ]),
  );
}

class ForumComposeScreen extends StatefulWidget {
  const ForumComposeScreen({super.key});
  @override
  State<ForumComposeScreen> createState() => _ForumComposeScreenState();
}

class _ForumComposeScreenState extends State<ForumComposeScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  String _category = 'general';
  bool _submitting = false;
  @override
  void dispose() { _title.dispose(); _content.dispose(); super.dispose(); }
  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請填寫標題和內容'))); return;
    }
    setState(() => _submitting = true);
    try {
      await ForumService.createPost(category: _category, title: _title.text.trim(), content: _content.text.trim());
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally { if (mounted) setState(() => _submitting = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.creamLight,
    appBar: AppBar(backgroundColor: AppColors.creamLight, foregroundColor: AppColors.ink, title: const Text('發表貼文'), actions: [TextButton(onPressed: _submitting ? null : _submit, child: Text(_submitting ? '發表中…' : '發表', style: const TextStyle(color: AppColors.primary)))]),
    body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      DropdownButtonFormField<String>(initialValue: _category, decoration: const InputDecoration(labelText: '分類'), items: _categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (value) => setState(() => _category = value ?? 'general')),
      const SizedBox(height: 12),
      TextField(controller: _title, maxLength: 120, decoration: const InputDecoration(labelText: '標題', filled: true)),
      const SizedBox(height: 12),
      Expanded(child: TextField(controller: _content, maxLength: 5000, minLines: null, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, decoration: const InputDecoration(labelText: '內容', alignLabelWithHint: true, filled: true))),
    ])),
  );
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment}); final ForumComment comment;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    CircleAvatar(radius: 17, backgroundColor: AppColors.moss, foregroundColor: Colors.white, child: Text(comment.author.displayName.characters.first)),
    const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(comment.author.displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)), Text(comment.content, style: const TextStyle(color: AppColors.inkSoft, height: 1.4)), Text(_timeAgo(comment.createdAt), style: const TextStyle(color: AppColors.fog, fontSize: 11))]))
  ]));
}

class _CategoryBadge extends StatelessWidget { const _CategoryBadge({required this.category}); final String category;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(99)), child: Text(_categories[category] ?? '討論', style: const TextStyle(color: AppColors.primary, fontSize: 12)));
}
class _EmptyForum extends StatelessWidget { const _EmptyForum(); @override Widget build(BuildContext context) => const Center(child: Text('還沒有貼文，成為第一位發文的族人吧！', style: TextStyle(color: AppColors.fog))); }
class _ForumError extends StatelessWidget { const _ForumError({required this.onRetry, this.error}); final VoidCallback onRetry; final Object? error;
  @override Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('暫時無法載入論壇', style: TextStyle(color: AppColors.ink)), const SizedBox(height: 8), OutlinedButton(onPressed: onRetry, child: const Text('再試一次'))])); }
String _timeAgo(DateTime time) { final duration = DateTime.now().difference(time); if (duration.inMinutes < 1) return '剛剛'; if (duration.inHours < 1) return '${duration.inMinutes} 分鐘前'; if (duration.inDays < 1) return '${duration.inHours} 小時前'; return '${duration.inDays} 天前'; }
