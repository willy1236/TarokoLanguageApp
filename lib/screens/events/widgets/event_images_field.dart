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
  EventImagesController([List<EventImage> existing = const []])
    : _existing = existing;

  List<EventImage> _existing;
  final Set<int> _removedIds = {};
  final List<Uint8List> _pending = [];
  bool _picking = false;
  bool _disposed = false;

  /// 活動原有的照片（建立活動時為空），依後端順序。
  List<EventImage> get existing => _existing;

  /// 正在開相簿或壓縮選好的照片；這時送出會漏掉還沒加進來的照片。
  bool get picking => _picking;

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

  /// 開相簿挑照片並壓縮，加到待上傳；回傳略過了哪些圖的說明。挑圖失敗（例如
  /// 沒有相簿權限）照常丟出。
  Future<String?> pickMore() async {
    if (_picking || remaining <= 0) return null;
    _picking = true;
    notifyListeners();
    try {
      final picked = await pickImagesForUpload(
        limit: remaining,
        maxBytes: EventService.imageMaxBytes,
      );
      _pending.addAll(picked.images.take(remaining));
      return picked.skippedNotice;
    } finally {
      _picking = false;
      // 壓縮途中按返回，表單已經把 controller 釋放掉。
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 既有照片的網址過期後，換成重新取得的網址（依 id 對應，順序不變）。
  void refreshUrls(List<EventImage> fresh) {
    final urls = {for (final image in fresh) image.id: image.url};
    _existing = [
      for (final image in _existing)
        EventImage(id: image.id, url: urls[image.id] ?? image.url),
    ];
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

  /// 既有照片載入失敗（多半是網址過期）時自動觸發，每個網址一次；呼叫端重新
  /// 取得網址後交給 [EventImagesController.refreshUrls]，自行限制次數。
  final VoidCallback? onExistingExpired;

  /// 使用者點既有照片破圖上的重試；明確的使用者意圖，不該受自動次數上限限制。
  final VoidCallback? onExistingRetryTap;

  const EventImagesField({
    super.key,
    required this.controller,
    required this.seniorMode,
    this.enabled = true,
    this.onExistingExpired,
    this.onExistingRetryTap,
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
  EventImagesController get _c => widget.controller;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    if (_c.picking || !widget.enabled) return;
    if (_c.remaining <= 0) {
      _snack('每場活動最多 ${EventService.imageMaxCount} 張照片');
      return;
    }
    try {
      final notice = await _c.pickMore();
      if (notice != null) _snack(notice);
    } catch (e) {
      debugPrint('EventImagesField: 挑圖失敗：$e');
      _snack('無法開啟相簿，請確認已允許 App 存取照片');
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
                      onExpired: widget.onExistingExpired,
                      onRetryTap: widget.onExistingRetryTap,
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
          child: _c.picking
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
