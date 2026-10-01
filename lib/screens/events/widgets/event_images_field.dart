// 發起／編輯活動表單的照片欄位。只記下要刪哪些既有照片、要上傳哪些新照片，
// 不打 API——跟其他欄位一樣按「發布／儲存」才送出，按返回就什麼都沒變。

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/event_model.dart';
import '../../../services/event_service.dart';
import '../../../shared/utils/pick_images.dart';
import '../../../shared/widgets/signed_network_image.dart';
import '../../forum/widgets/forum_image_grid.dart';

/// 表單裡照片的編輯狀態：活動原有的照片（可標記刪除）與還沒上傳的新照片。
/// 張數上限算兩者合計，標記刪除的不算。
class EventImagesController extends ChangeNotifier {
  EventImagesController([this.existing = const []]);

  /// 活動原有的照片（建立活動時為空），依後端順序。
  final List<EventImage> existing;
  final Set<int> _removedIds = {};
  final List<Uint8List> _pending = [];

  /// 送出時要刪掉的既有照片 id，依原本順序。
  List<int> get toDelete => [
    for (final image in existing)
      if (_removedIds.contains(image.id)) image.id,
  ];

  /// 送出時要上傳的新照片（已壓成 JPEG），依加入順序。
  List<Uint8List> get toUpload => List.unmodifiable(_pending);

  bool get hasChanges => _removedIds.isNotEmpty || _pending.isNotEmpty;

  /// 送出後會有幾張。
  int get count => existing.length - _removedIds.length + _pending.length;

  int get remaining => EventService.imageMaxCount - count;

  bool isRemoved(EventImage image) => _removedIds.contains(image.id);

  /// 加入新照片，超過上限的部分捨棄。
  void addPending(List<Uint8List> images) {
    _pending.addAll(images.take(remaining));
    notifyListeners();
  }

  void removePending(int index) {
    _pending.removeAt(index);
    notifyListeners();
  }

  /// 標記或取消標記刪除。取消標記會多佔一張，已滿時不能取消，回 false。
  bool toggleRemoved(EventImage image) {
    if (_removedIds.contains(image.id)) {
      if (remaining <= 0) return false;
      _removedIds.remove(image.id);
    } else {
      _removedIds.add(image.id);
    }
    notifyListeners();
    return true;
  }
}

class EventImagesField extends StatefulWidget {
  final EventImagesController controller;
  final bool seniorMode;

  /// 送出中不能再改。
  final bool enabled;

  const EventImagesField({
    super.key,
    required this.controller,
    required this.seniorMode,
    this.enabled = true,
  });

  @override
  State<EventImagesField> createState() => _EventImagesFieldState();
}

/// 欄位裡的一格：既有照片或新照片。
typedef _Item = ({
  EventImage? existing,
  int? pendingIndex,
  ImageProvider image,
});

class _EventImagesFieldState extends State<EventImagesField> {
  bool _picking = false;

  EventImagesController get _c => widget.controller;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    if (_picking || !widget.enabled) return;
    if (_c.remaining <= 0) {
      _snack('每場活動最多 ${EventService.imageMaxCount} 張照片');
      return;
    }
    setState(() => _picking = true);
    try {
      final picked = await pickImagesForUpload(
        limit: _c.remaining,
        maxBytes: EventService.imageMaxBytes,
      );
      final notice = picked.skippedNotice;
      if (notice != null) _snack(notice);
      _c.addPending(picked.images);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _toggleRemoved(EventImage image) {
    if (!widget.enabled) return;
    if (!_c.toggleRemoved(image)) {
      _snack('已達 ${EventService.imageMaxCount} 張上限，先移除一張新照片才能還原');
    }
  }

  List<_Item> _items() => [
    for (final image in _c.existing)
      (
        existing: image,
        pendingIndex: null,
        image: signedImageProvider(image.url),
      ),
    for (var i = 0; i < _c.toUpload.length; i++)
      (existing: null, pendingIndex: i, image: MemoryImage(_c.toUpload[i])),
  ];

  void _preview(List<_Item> items, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForumImageViewer(
          images: [for (final item in items) item.image],
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _c,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final seniorMode = widget.seniorMode;
    final size = seniorMode ? 112.0 : 92.0;
    final items = _items();
    // 封面＝送出後的第一張：第一張沒被標記刪除的。
    final coverIndex = items.indexWhere(
      (item) => item.existing == null || !_c.isRemoved(item.existing!),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: size,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length + (_c.remaining > 0 ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => i == items.length
                ? _buildAddTile(size)
                : _buildThumb(items, i, size, isCover: i == coverIndex),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_c.count}/${EventService.imageMaxCount} 張・第一張是封面',
          style: AppTypography.bodyStyle(
            seniorMode: seniorMode,
            color: AppColors.fog,
          ),
        ),
      ],
    );
  }

  Widget _buildThumb(
    List<_Item> items,
    int index,
    double size, {
    required bool isCover,
  }) {
    final seniorMode = widget.seniorMode;
    final item = items[index];
    final existing = item.existing;
    final removed = existing != null && _c.isRemoved(existing);
    final placeholder = Container(color: AppColors.creamDeep);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => _preview(items, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: existing != null
                  ? SignedNetworkImage(
                      url: existing.url,
                      placeholder: placeholder,
                    )
                  : Image(image: item.image, fit: BoxFit.cover),
            ),
          ),
          if (removed)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.dangerDark, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '將刪除',
                  style: AppTypography.subtitleStyle(
                    seniorMode: seniorMode,
                    color: AppColors.creamLight,
                  ),
                ),
              ),
            ),
          if (isCover)
            Positioned(
              left: 4,
              bottom: 4,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '封面',
                    style: AppTypography.captionStyle(
                      seniorMode: seniorMode,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: _buildCornerButton(
              removed: removed,
              onTap: existing != null
                  ? () => _toggleRemoved(existing)
                  : () => _c.removePending(item.pendingIndex!),
            ),
          ),
        ],
      ),
    );
  }

  /// 右上角：移除（新照片直接拿掉、既有照片標記刪除），已標記的改成還原。
  Widget _buildCornerButton({
    required bool removed,
    required VoidCallback onTap,
  }) {
    final seniorMode = widget.seniorMode;
    final label = removed ? '還原這張照片' : '移除這張照片';
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: widget.enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        // 視覺上的圓鈕小，點擊範圍放大到角落一整塊。
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Tooltip(
            message: label,
            child: Container(
              width: seniorMode ? 30 : 22,
              height: seniorMode ? 30 : 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.ink.withValues(alpha: 0.7),
              ),
              child: Icon(
                removed ? Icons.undo : Icons.close,
                size: seniorMode ? 18 : 14,
                color: AppColors.creamLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddTile(double size) {
    final seniorMode = widget.seniorMode;
    return Semantics(
      button: true,
      label: '新增照片',
      child: GestureDetector(
        onTap: _add,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.creamDeep, width: 1.5),
          ),
          child: _picking
              ? const Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.primary,
                      size: seniorMode ? 30 : 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '新增照片',
                      style: AppTypography.bodyStyle(
                        seniorMode: seniorMode,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
