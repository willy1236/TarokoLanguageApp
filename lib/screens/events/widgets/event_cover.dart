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

/// 依封面狀態建卡片：沒有封面或封面破圖時 [builder] 收到 null，卡片畫沒有封面
/// 的樣子；有封面時收到照片元件（載入中顯示 [placeholder]），由卡片決定擺法。
class EventCover extends StatefulWidget {
  final String? url;
  final Widget placeholder;
  final Widget Function(BuildContext context, Widget? photo) builder;

  const EventCover({
    super.key,
    required this.url,
    required this.builder,
    this.placeholder = const SizedBox.shrink(),
  });

  @override
  State<EventCover> createState() => _EventCoverState();
}

class _EventCoverState extends State<EventCover> {
  bool _failed = false;

  @override
  void didUpdateWidget(EventCover old) {
    super.didUpdateWidget(old);
    // 列表重新整理換了新網址，再試一次。
    if (old.url != widget.url) _failed = false;
  }

  void _onExpired() {
    const EventCoverExpiredNotification().dispatch(context);
    if (mounted) setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    return widget.builder(
      context,
      url == null || _failed
          ? null
          : SignedNetworkImage(
              url: url,
              placeholder: widget.placeholder,
              onExpired: _onExpired,
            ),
    );
  }
}

/// 列表列右側的小方形封面縮圖，自帶與旁邊內容的間距 [padding]。沒有封面或破圖
/// 時連間距都不佔，列和沒有封面時一樣。
class EventCoverThumb extends StatelessWidget {
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
  Widget build(BuildContext context) => EventCover(
    url: url,
    placeholder: const ColoredBox(color: AppColors.creamDeep),
    builder: (context, photo) => photo == null
        ? const SizedBox.shrink()
        : Padding(
            padding: padding,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.square(
                dimension: sizeFor(seniorMode),
                child: photo,
              ),
            ),
          ),
  );
}
