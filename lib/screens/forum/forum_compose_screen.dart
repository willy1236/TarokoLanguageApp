// 發文 / 編輯。排版沿用 feature/forum-dcard 的結構：看板 segment、標題、內文、
// 底部工具列。
//
// 編輯模式只送文字欄位：後端 PATCH /forum/posts/:id 不處理附圖，所以編輯時
// 附圖區唯讀——讓使用者以為改得動但實際沒生效，比不給改更糟。

import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import 'forum_theme.dart';
import '../../core/network/api_client.dart';
import '../../models/forum_models.dart';
import '../../services/forum_service.dart';

/// 依後端硬性限制檢查，回傳第一個錯誤訊息；全部通過回 null。
String? forumComposeError({
  required int? boardId,
  required String title,
  required String body,
  required List<String> tags,
}) {
  if (boardId == null) return '請選擇看板';
  if (title.trim().isEmpty) return '請填寫標題';
  if (title.trim().length > ForumService.titleMax) {
    return '標題不能超過 ${ForumService.titleMax} 字';
  }
  if (body.trim().isEmpty) return '請填寫內文';
  if (body.trim().length > ForumService.bodyMax) {
    return '內文不能超過 ${ForumService.bodyMax} 字';
  }
  if (tags.length > ForumService.tagMaxCount) {
    return '標籤最多 ${ForumService.tagMaxCount} 個';
  }
  if (tags.any((t) => t.length > ForumService.tagNameMax)) {
    return '每個標籤不能超過 ${ForumService.tagNameMax} 字';
  }
  return null;
}

class ForumComposeScreen extends StatefulWidget {
  final List<ForumBoard> boards;
  final ForumPost? editing;

  const ForumComposeScreen({super.key, required this.boards, this.editing});

  @override
  State<ForumComposeScreen> createState() => _ForumComposeScreenState();
}

class _PickedImage {
  final Uint8List bytes;
  final String filename;

  const _PickedImage({required this.bytes, required this.filename});
}

class _ForumComposeScreenState extends State<ForumComposeScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];
  final List<_PickedImage> _images = [];

  int? _boardId;
  bool _saving = false;
  List<ForumTagStat> _hotTags = [];

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _titleController.text = editing.title;
      _bodyController.text = editing.body;
      _tags.addAll(editing.tags.map((t) => t.name));
      _boardId = editing.board.id;
    } else {
      _boardId = widget.boards.isEmpty ? null : widget.boards.first.id;
    }
    _loadHotTags();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _loadHotTags() async {
    try {
      final tags = await ForumService.tags();
      if (!mounted) return;
      setState(() => _hotTags = tags.take(10).toList());
    } on ApiException {
      // 熱門標籤只是輔助輸入，拿不到就不顯示。
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImages() async {
    if (_images.length >= ForumService.imageMaxCount) {
      _toast('最多只能附 ${ForumService.imageMaxCount} 張圖');
      return;
    }
    final picked = await ImagePicker().pickMultiImage(
      limit: ForumService.imageMaxCount - _images.length,
    );
    if (picked.isEmpty) return;

    for (final file in picked) {
      // 後端不做伺服器端壓縮，且限制單張 5 MB，所以壓縮必須在這裡完成。
      final compressed = await FlutterImageCompress.compressWithFile(
        file.path,
        minWidth: 1920,
        minHeight: 1920,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) {
        _toast('無法處理 ${file.name}，請換一張');
        continue;
      }
      if (compressed.length > ForumService.imageMaxBytes) {
        _toast('${file.name} 壓縮後仍超過 5 MB，請換一張較小的圖');
        continue;
      }
      if (!mounted) return;
      setState(
        () => _images.add(
          _PickedImage(
            bytes: compressed,
            // 一律轉成 JPEG，副檔名跟著改，避免與 Content-Type 不一致。
            filename: '${DateTime.now().microsecondsSinceEpoch}.jpg',
          ),
        ),
      );
      if (_images.length >= ForumService.imageMaxCount) break;
    }
  }

  void _addTag() {
    final name = _tagController.text.trim();
    if (name.isEmpty) return;
    if (_tags.contains(name)) {
      _tagController.clear();
      return;
    }
    if (_tags.length >= ForumService.tagMaxCount) {
      _toast('標籤最多 ${ForumService.tagMaxCount} 個');
      return;
    }
    setState(() {
      _tags.add(name);
      _tagController.clear();
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final error = forumComposeError(
      boardId: _boardId,
      title: _titleController.text,
      body: _bodyController.text,
      tags: _tags,
    );
    if (error != null) {
      _toast(error);
      return;
    }

    setState(() => _saving = true);
    try {
      final editing = widget.editing;
      if (editing != null) {
        await ForumService.updatePost(
          editing.id,
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          tags: _tags,
        );
      } else {
        await ForumService.createPost(
          boardId: _boardId!,
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          tags: _tags,
          images: [
            for (final image in _images)
              MultipartFileData(
                field: 'images',
                bytes: image.bytes,
                filename: image.filename,
                mimeType: 'image/jpeg',
              ),
          ],
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Theme(data: forumTheme(context), child: _buildScaffold(context));

  Widget _buildScaffold(BuildContext context) => Scaffold(
    backgroundColor: AppColors.creamLight,
    appBar: AppBar(
      backgroundColor: AppColors.creamLight,
      elevation: 0,
      foregroundColor: AppColors.ink,
      title: Text(
        _isEditing ? '編輯貼文' : '發文',
        style: GoogleFonts.notoSerifTc(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(
            _saving ? '送出中…' : '送出',
            style: const TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _boardSegment(),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          maxLength: ForumService.titleMax,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.notoSerifTc(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
          decoration: const InputDecoration(
            hintText: '標題',
            border: InputBorder.none,
          ),
        ),
        const Divider(color: AppColors.creamDeep),
        TextField(
          controller: _bodyController,
          maxLength: ForumService.bodyMax,
          minLines: 8,
          maxLines: null,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: '想說的話…',
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 12),
        _tagSection(),
        const SizedBox(height: 16),
        _imageSection(),
      ],
    ),
  );

  /// 看板選擇採 segmented 樣式：整條淺褐底槽，選中的那格浮起成淺色卡片。
  /// 各格等寬，看板名稱過長時省略——名稱長度由後端 seed 決定，前端不再自己縮寫。
  Widget _boardSegment() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.creamDeep),
    ),
    child: Row(
      children: [
        for (final board in widget.boards)
          Expanded(child: _boardSegmentTab(board)),
      ],
    ),
  );

  Widget _boardSegmentTab(ForumBoard board) {
    final selected = board.id == _boardId;
    return GestureDetector(
      // 編輯模式不能換看板：後端 PATCH 不接受 board_id。
      onTap: _isEditing ? null : () => setState(() => _boardId = board.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.creamLight : null,
          borderRadius: BorderRadius.circular(9),
          border: selected
              ? Border.all(color: AppColors.creamDeep)
              : Border.all(color: Colors.transparent),
        ),
        alignment: Alignment.center,
        child: Text(
          board.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSerifTc(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.fog,
          ),
        ),
      ),
    );
  }

  Widget _tagSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _tagController,
              maxLength: ForumService.tagNameMax,
              onSubmitted: (_) => _addTag(),
              decoration: const InputDecoration(
                hintText: '加入標籤',
                counterText: '',
                isDense: true,
              ),
            ),
          ),
          TextButton(onPressed: _addTag, child: const Text('加入')),
        ],
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final tag in _tags)
            Chip(
              label: Text('#$tag'),
              onDeleted: () => setState(() => _tags.remove(tag)),
              backgroundColor: AppColors.cream,
            ),
        ],
      ),
      if (_hotTags.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          'HOT · 熱門標籤',
          style: GoogleFonts.crimsonPro(
            fontStyle: FontStyle.italic,
            fontSize: 10,
            color: AppColors.fog,
            letterSpacing: 3.0,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final stat in _hotTags)
              ActionChip(
                label: Text('#${stat.tag.name}'),
                backgroundColor: AppColors.cream,
                onPressed: () {
                  _tagController.text = stat.tag.name;
                  _addTag();
                },
              ),
          ],
        ),
      ],
    ],
  );

  Widget _imageSection() {
    if (_isEditing) {
      final images = widget.editing!.images;
      if (images.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '附圖無法在編輯時變更',
            style: TextStyle(fontSize: 12, color: AppColors.fog),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: images[i],
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    width: 88,
                    height: 88,
                    color: AppColors.creamDeep,
                  ),
                  errorWidget: (_, _, _) => Container(
                    width: 88,
                    height: 88,
                    color: AppColors.creamDeep,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.fog,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(
                '加入圖片（${_images.length}/${ForumService.imageMaxCount}）',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.creamDeep),
              ),
            ),
          ],
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _images[i].bytes,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _images.removeAt(i)),
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.ink,
                        child: Icon(
                          Icons.close,
                          size: 12,
                          color: AppColors.creamLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
