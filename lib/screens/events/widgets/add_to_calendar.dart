// 活動詳情的「加入日曆」：手機開系統日曆的新增畫面，讓使用者確認後存進自己的
// 日曆；Web 與沒有日曆 App 的 Android 改開 Google Calendar 的新增事件頁。
// 只是一次性帶入，活動之後改時間或取消不會同步，靠既有的活動變更推播告知。

import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/platform/platform_features.dart';
import '../../../models/event_model.dart';

/// 已取消、已結束的活動不提供加入日曆。
bool canAddToCalendar(EventDetail e) =>
    e.displayStatus != 'cancelled' && e.displayStatus != 'ended';

/// 舊活動沒有結束時間時，日曆事件以開始後 2 小時為結束。
const _fallbackDuration = Duration(hours: 2);

DateTime _endOf(EventDetail e) => e.endsAt ?? e.startsAt.add(_fallbackDuration);

/// 日曆的地點欄：地址為主；舊活動地點與地址分開填、互不包含時兩個都帶。
String? _placeOf(EventDetail e) {
  final location = e.location?.trim() ?? '';
  final address = e.address?.trim() ?? '';
  if (address.isEmpty) return location.isEmpty ? null : location;
  if (location.isEmpty || address.contains(location)) return address;
  return '$location $address';
}

/// 說明欄最後附上 App 名稱與活動編號，使用者從日曆看到時知道回哪裡查。
String _detailsOf(EventDetail e, {int? maxDescription}) {
  var description = e.description?.trim() ?? '';
  // 以字元（grapheme）截斷，emoji 才不會被切成半個。
  if (maxDescription != null &&
      description.characters.length > maxDescription) {
    description = '${description.characters.take(maxDescription)}…';
  }
  final footer = '在「語見・太魯閣」App 的活動查看詳情：${e.title}（活動編號 ${e.id}）';
  return description.isEmpty ? footer : '$description\n\n$footer';
}

/// Google Calendar 的網址有長度上限，說明太長時截斷。
const _urlDescriptionMax = 500;

/// Google Calendar 新增事件頁。`dates` 用 UTC 的 `yyyyMMddTHHmmssZ`，
/// 不受使用者所在時區影響。
@visibleForTesting
Uri googleCalendarUri(EventDetail e) {
  String utc(DateTime t) {
    final u = t.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}'
        'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  }

  final place = _placeOf(e);
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': e.title,
    'dates': '${utc(e.startsAt)}/${utc(_endOf(e))}',
    'location': ?place,
    'details': _detailsOf(e, maxDescription: _urlDescriptionMax),
  });
}

/// 打開新增日曆事件的畫面。只有完全打不開時回 false；使用者在系統畫面按取消
/// 不算失敗，不必提示。
Future<bool> addEventToCalendar(EventDetail e) async {
  if (PlatformFeatures.supportsNativeCalendar) {
    try {
      final opened = await cal.Add2Calendar.addEvent2Cal(
        cal.Event(
          title: e.title,
          description: _detailsOf(e),
          location: _placeOf(e),
          startDate: e.startsAt,
          endDate: _endOf(e),
        ),
      );
      // iOS 回 false 是使用者取消或沒授權；Android 回 false 才是找不到日曆 App。
      if (opened || defaultTargetPlatform == TargetPlatform.iOS) return true;
    } on PlatformException catch (err) {
      debugPrint('addEventToCalendar: 系統日曆開啟失敗，改開 Google Calendar：$err');
    }
  }
  try {
    return await launchUrl(
      googleCalendarUri(e),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  } on PlatformException catch (err) {
    debugPrint('addEventToCalendar: Google Calendar 開啟失敗：$err');
    return false;
  }
}

/// 時間列旁的「加入日曆」按鈕。
class AddToCalendarButton extends StatelessWidget {
  final EventDetail event;
  final bool seniorMode;

  const AddToCalendarButton({
    super.key,
    required this.event,
    required this.seniorMode,
  });

  Future<void> _onTap(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await addEventToCalendar(event)) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('無法開啟日曆，請稍後再試')));
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _onTap(context),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: EdgeInsets.symmetric(horizontal: seniorMode ? 12 : 8),
        minimumSize: Size(0, seniorMode ? 48 : 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(Icons.event_available_outlined, size: seniorMode ? 22 : 16),
      label: Text(
        '加入日曆',
        style: AppTypography.captionStyle(
          seniorMode: seniorMode,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
