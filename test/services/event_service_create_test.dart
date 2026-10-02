// 發起活動回應的 tribe_notify_limited：24 小時內部落推播已推滿 3 次時為 true，
// 活動照常建立。欄位依規格 活動提醒.md §1.2 手寫，未錄 fixture——
// POST /api/events 會建立真的活動，限流路徑也要當天第 4 次才出現。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/event_draft.dart';
import 'package:flutter_application_1/services/event_service.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  final draft = EventDraft(
    title: '豐年祭',
    description: '一起來',
    address: '花蓮縣秀林鄉部落廣場',
    startsAt: DateTime.now().add(const Duration(days: 7)),
    tribeId: 1,
    notifyTribe: true,
  );

  test('回應帶 tribe_notify_limited: true 時解析為受限', () async {
    installMockClient({
      '/api/events': jsonResponse({
        'id': 42,
        'notify_tribe': true,
        'tribe_notified': 0,
        'tribe_notify_limited': true,
      }, status: 201),
    });

    final created = await EventService.createEvent(draft);

    expect(created.id, 42);
    expect(created.tribeNotifyLimited, isTrue);
  });

  test('回應沒有 tribe_notify_limited 欄位時視為未受限', () async {
    installMockClient({
      '/api/events': jsonResponse({'id': 7}, status: 201),
    });

    final created = await EventService.createEvent(draft);

    expect(created.id, 7);
    expect(created.tribeNotifyLimited, isFalse);
  });
}
