// 活動詳情的地址列可點：開 Google 地圖（手機有裝 App 就開 App，沒裝開瀏覽器）定位到活動。
// 有地圖選點的座標就用座標，沒有就用地址文字搜尋。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/event_model.dart';

/// Google 地圖的搜尋網址；沒有座標也沒有地址時回 null。
@visibleForTesting
Uri? eventMapsUri(EventDetail e) {
  final lat = e.latitude;
  final lng = e.longitude;
  final address = e.address?.trim() ?? '';
  final location = e.location?.trim() ?? '';
  final String query;
  if (lat != null && lng != null) {
    query = '$lat,$lng';
  } else if (address.isNotEmpty) {
    query = address;
  } else if (location.isNotEmpty) {
    query = location;
  } else {
    return null;
  }
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  });
}

/// 包住地址列，點了開地圖；右側加一個開啟的圖示提示可點。
class EventMapLink extends StatelessWidget {
  final EventDetail event;
  final bool seniorMode;
  final Widget child;

  const EventMapLink({
    super.key,
    required this.event,
    required this.seniorMode,
    required this.child,
  });

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } on PlatformException catch (e) {
      debugPrint('EventMapLink: 地圖開啟失敗：$e');
    }
    if (opened) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('無法開啟地圖，請稍後再試')));
  }

  @override
  Widget build(BuildContext context) {
    final uri = eventMapsUri(event);
    if (uri == null) return child;
    return InkWell(
      onTap: () => _open(context, uri),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: child),
          const SizedBox(width: 8),
          Icon(
            Icons.open_in_new,
            size: seniorMode ? 22 : 16,
            color: AppColors.primary,
            semanticLabel: '在地圖上開啟',
          ),
        ],
      ),
    );
  }
}
