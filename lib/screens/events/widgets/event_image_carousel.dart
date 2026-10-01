// 活動詳情頂端的圖片輪播。發起人直接在上面新增、刪除，當下就送出——活動開始、
// 取消、結束後不能再進編輯頁，這裡是補照片的唯一入口。

import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../models/event_model.dart';
import '../../../services/account_lock_controller.dart';
import '../../../services/event_service.dart';
import '../../../shared/utils/pick_images.dart';
import '../../../shared/widgets/confirm_dialog.dart';

enum _Busy { uploading, deleting }

class EventImageCarousel extends StatefulWidget {
  final int eventId;
  final List<EventImage> images;

  /// 發起人才有新增、刪除。
  final bool canEdit;
  final bool seniorMode;

  /// 沒有圖片時鋪在底下的背景，也是照片載入中的佔位。
  final Widget background;

  /// 上傳或刪除成功後，後端回的該活動全部圖片。
  final ValueChanged<List<EventImage>> onImagesChanged;

  /// 疊在照片上的內容。[controls] 是頁數指示與發起人的新增、刪除按鈕，由呼叫端
  /// 決定擺放位置；其餘疊上去的文字要包 IgnorePointer，才不會吃掉左右滑。
  final Widget Function(BuildContext context, Widget controls) overlayBuilder;

  const EventImageCarousel({
    super.key,
    required this.eventId,
    required this.images,
    required this.canEdit,
    required this.seniorMode,
    required this.background,
    required this.onImagesChanged,
    required this.overlayBuilder,
  });

  @override
  State<EventImageCarousel> createState() => _EventImageCarouselState();
}

class _EventImageCarouselState extends State<EventImageCarousel> {
  var _controller = PageController();
  int _index = 0;
  _Busy? _busy;

  /// 上傳、刪除後要停的頁；等呼叫端換上新清單時才換頁。
  int? _pendingPage;

  @override
  void didUpdateWidget(EventImageCarousel old) {
    super.didUpdateWidget(old);
    // 重新整理後圖片變少：停在最後一張，不讓指示顯示超出張數。
    final last = widget.images.length - 1;
    if (_index > last) _index = max(last, 0);
    final page = _pendingPage;
    if (page == null || widget.images == old.images) return;
    _pendingPage = null;
    _index = min(page, max(last, 0));
    // 換一個從目標頁開始的 controller：同一輪重建裡 PageView 還沒算好新的
    // 捲動範圍，在舊的上面 jumpToPage 會被夾回舊的最後一頁。
    final previous = _controller;
    _controller = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    if (_busy != null) return;
    final remaining = EventService.imageMaxCount - widget.images.length;
    if (remaining <= 0) {
      _snack('每場活動最多 ${EventService.imageMaxCount} 張照片，要新增請先刪除');
      return;
    }
    if (blockIfReadOnly()) return;
    // 從開相簿就算進行中：選完還要逐張壓縮，張數多時要好幾秒。
    setState(() => _busy = _Busy.uploading);
    try {
      final picked = await pickImagesForUpload(
        limit: remaining,
        maxBytes: EventService.imageMaxBytes,
      );
      final notice = picked.skippedNotice;
      if (notice != null) _snack(notice);
      if (picked.images.isEmpty || !mounted) return;
      final firstNew = widget.images.length;
      final images = await EventService.uploadImages(
        widget.eventId,
        picked.images,
      );
      if (!mounted) return;
      _pendingPage = firstNew;
      widget.onImagesChanged(images);
    } catch (e) {
      _snack(apiErrorMessage(e, fallback: '上傳失敗，請稍後再試'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _deleteCurrent() async {
    if (_busy != null || widget.images.isEmpty) return;
    final index = min(_index, widget.images.length - 1);
    final target = widget.images[index];
    final confirmed = await showConfirmDialog(
      context,
      title: '刪除這張照片？',
      message: index == 0 && widget.images.length > 1
          ? '這張是封面，刪除後由下一張當封面。'
          : '刪除後無法復原。',
      cancelText: '取消',
      confirmText: '刪除',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = _Busy.deleting);
    try {
      final images = await EventService.deleteImage(widget.eventId, target.id);
      if (!mounted) return;
      // 停在相鄰的一張：原位置換成下一張；刪的是最後一張就往前一張。
      _pendingPage = index;
      widget.onImagesChanged(images);
    } catch (e) {
      _snack(apiErrorMessage(e, fallback: '刪除失敗，請稍後再試'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (images.isEmpty)
          widget.background
        else
          PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => CachedNetworkImage(
              imageUrl: images[i].url,
              fit: BoxFit.cover,
              placeholder: (_, _) => widget.background,
              errorWidget: (_, _, _) => widget.background,
            ),
          ),
        widget.overlayBuilder(context, _buildControls()),
      ],
    );
  }

  Widget _buildControls() {
    final images = widget.images;
    final seniorMode = widget.seniorMode;
    final children = <Widget>[
      if (images.length > 1)
        _Chip(
          seniorMode: seniorMode,
          child: Text(
            '${min(_index, images.length - 1) + 1}／${images.length}',
            style: AppTypography.bodyStyle(
              seniorMode: seniorMode,
              color: AppColors.creamLight,
            ),
          ),
        ),
      if (widget.canEdit && images.isEmpty)
        _Chip(
          seniorMode: seniorMode,
          onTap: _busy == null ? _add : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _busy == _Busy.uploading
                  ? _Spinner(seniorMode: seniorMode)
                  : Icon(
                      Icons.add_photo_alternate_outlined,
                      size: seniorMode ? 22 : 18,
                      color: AppColors.creamLight,
                    ),
              const SizedBox(width: 6),
              Text(
                _busy == _Busy.uploading ? '上傳中…' : '新增照片',
                style: AppTypography.bodyStyle(
                  seniorMode: seniorMode,
                  color: AppColors.creamLight,
                ),
              ),
            ],
          ),
        ),
      if (widget.canEdit && images.isNotEmpty) ...[
        _RoundButton(
          tooltip: images.length >= EventService.imageMaxCount
              ? '已達 ${EventService.imageMaxCount} 張上限'
              : '新增照片',
          icon: Icons.add_photo_alternate_outlined,
          busy: _busy == _Busy.uploading,
          // 滿 6 張時看起來停用，但仍可點，點了說明上限。
          dimmed: images.length >= EventService.imageMaxCount,
          onTap: _busy == null ? _add : null,
          seniorMode: seniorMode,
        ),
        _RoundButton(
          tooltip: '刪除這張照片',
          icon: Icons.delete_outline,
          busy: _busy == _Busy.deleting,
          onTap: _busy == null ? _deleteCurrent : null,
          seniorMode: seniorMode,
        ),
      ],
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// 疊在照片上的半透明深色膠囊。
class _Chip extends StatelessWidget {
  final bool seniorMode;
  final Widget child;
  final VoidCallback? onTap;

  const _Chip({required this.seniorMode, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.ink.withValues(alpha: 0.55),
    shape: const StadiumBorder(),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: seniorMode ? 14 : 10,
          vertical: seniorMode ? 8 : 5,
        ),
        child: child,
      ),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool busy;
  final bool dimmed;
  final VoidCallback? onTap;
  final bool seniorMode;

  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.busy,
    required this.onTap,
    required this.seniorMode,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = seniorMode ? 48.0 : 40.0;
    final faded = dimmed || (onTap == null && !busy);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.ink.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: busy
                  ? _Spinner(seniorMode: seniorMode)
                  : Icon(
                      icon,
                      semanticLabel: tooltip,
                      size: seniorMode ? 26 : 20,
                      color: AppColors.creamLight.withValues(
                        alpha: faded ? 0.4 : 1,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  final bool seniorMode;
  const _Spinner({required this.seniorMode});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: seniorMode ? 20 : 16,
    child: const CircularProgressIndicator(
      strokeWidth: 2,
      color: AppColors.creamLight,
    ),
  );
}
