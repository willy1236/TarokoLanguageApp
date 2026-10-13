// 編輯活動回應的 notify_limited：同一場活動 24 小時內修改通知已推滿 3 次時為 true，
// 活動照常更新但參加者收不到推播。欄位依 前端待辦 2026-10-11 手寫，未錄 fixture——
// PATCH /api/events/:id 會改到真的活動，限流路徑也要當天第 4 次修改才出現。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/models/event_draft.dart';
import 'package:flutter_application_1/models/event_model.dart';
import 'package:flutter_application_1/services/event_service.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  final startsAt = DateTime.now().add(const Duration(days: 7));
  EventDetail detail({String reminderNote = '帶水'}) => EventDetail(
    id: 1,
    title: '走讀',
    description: '說明',
    startsAt: startsAt,
    location: '部落',
    address: '秀林鄉',
    reminderNote: reminderNote,
    status: 'active',
  );
  final original = detail();
  final changed = EventDraft.fromDetail(detail(reminderNote: '帶雨衣'));

  test('回應帶 notify_limited: true 時解析為受限', () async {
    installMockClient({
      '/api/events/1': jsonResponse({
        'ok': true,
        'notified': 0,
        'notify_limited': true,
      }),
    });

    final updated = await EventService.updateEvent(1, changed, original);

    expect(updated.notifyLimited, isTrue);
  });

  test('回應沒有 notify_limited 欄位時視為未受限', () async {
    installMockClient({
      '/api/events/1': jsonResponse({'ok': true, 'notified': 3}),
    });

    final updated = await EventService.updateEvent(1, changed, original);

    expect(updated.notifyLimited, isFalse);
  });

  test('沒有變更時不送 PATCH，視為未受限', () async {
    var requests = 0;
    installMockClient(const {}, onRequest: (_) => requests++);

    final updated = await EventService.updateEvent(
      1,
      EventDraft.fromDetail(original),
      original,
    );

    expect(requests, 0);
    expect(updated.notifyLimited, isFalse);
  });
}
