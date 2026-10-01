// 活動卡片的封面：大卡鋪滿的照片與列表列右側的小方形縮圖，加上網址過期時
// 讓列表重新整理一次的機制。
//
// 封面網址 15 分鐘到期。破圖時卡片先退回沒有封面的樣子，並往上發出
// [EventCoverExpiredNotification]；包住列表的 [EventCoverRefresher] 收到後重載
// 一次換新網址，一段時間內只重載一次，不會因為整頁封面一起過期而連續重打。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/signed_network_image.dart';

/// 某張封面載入失敗（多半是網址過期）。
class EventCoverExpiredNotification extends Notification {
  const EventCoverExpiredNotification();
}

/// 包住一份活動列表：底下有封面過期時呼叫 [onRefresh]，[cooldown] 內最多一次。
class EventCoverRefresher extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Duration cooldown;

  const EventCoverRefresher({
    super.key,
    required this.onRefresh,
    required this.child,
    this.cooldown = const Duration(minutes: 5),
  });

  @override
  State<EventCoverRefresher> createState() => _EventCoverRefresherState();
}

class _EventCoverRefresherState extends State<EventCoverRefresher> {
  DateTime? _lastRefresh;

  bool _onExpired(EventCoverExpiredNotification _) {
    final now = DateTime.now();
    final last = _lastRefresh;
    if (last == null || now.difference(last) >= widget.cooldown) {
      _lastRefresh = now;
      widget.onRefresh();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<EventCoverExpiredNotification>(
        onNotification: _onExpired,
        child: widget.child,
      );
}

/// 鋪滿的封面照片（精選大卡、廣場小卡）。載入中與破圖時顯示 [placeholder]，
/// 也就是沒有封面時原本的樣子。
class EventCoverImage extends StatelessWidget {
  final String url;
  final Widget placeholder;

  const EventCoverImage({
    super.key,
    required this.url,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) => SignedNetworkImage(
    url: url,
    placeholder: placeholder,
    onExpired: () => const EventCoverExpiredNotification().dispatch(context),
  );
}

/// 列表列右側的小方形封面縮圖，自帶與旁邊內容的間距 [padding]。沒有封面或破圖
/// 時連間距都不佔，列和沒有封面時一樣。
class EventCoverThumb extends StatefulWidget {
  final String? url;
  final bool seniorMode;
  final EdgeInsets padding;

  const EventCoverThumb({
    super.key,
    required this.url,
    required this.seniorMode,
    this.padding = const EdgeInsets.only(left: 10),
  });

  static double sizeFor(bool seniorMode) => seniorMode ? 72 : 56;

  @override
  State<EventCoverThumb> createState() => _EventCoverThumbState();
}

class _EventCoverThumbState extends State<EventCoverThumb> {
  bool _failed = false;

  @override
  void didUpdateWidget(EventCoverThumb old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _failed = false;
  }

  void _onExpired() {
    const EventCoverExpiredNotification().dispatch(context);
    if (mounted) setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    if (url == null || _failed) return const SizedBox.shrink();
    final size = EventCoverThumb.sizeFor(widget.seniorMode);
    return Padding(
      padding: widget.padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox.square(
          dimension: size,
          child: SignedNetworkImage(
            url: url,
            placeholder: const ColoredBox(color: AppColors.creamDeep),
            onExpired: _onExpired,
          ),
        ),
      ),
    );
  }
}
