import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/notification_summary_service.dart';

import '../helpers/fixtures.dart';

void main() {
  test('解析 summary 並依分頁加總', () {
    final s = NotificationSummary.fromJson({
      // 舊版 App 用的計數，這版不讀。
      'forum': 9,
      'events': 9,
      'messages': 5,
      'friend_requests': 1,
      'inbox': {
        'forum': 3,
        'event': 2,
        'moderation': 1,
        'announcement': 4,
        'total': 10,
      },
      'total': 16,
    });
    expect(s.plaza, 5);
    expect(s.friends, 6);
    expect(s.inbox.moderation, 1);
    expect(s.inbox.announcement, 4);
    expect(s.inbox.total, 10);
    expect(s.total, 16);
  });

  test('錄製的 summary 帶 inbox 各分類未讀', () {
    final json = loadFixtureMap('get_api_notifications_summary.json');
    expect(json['inbox'], isA<Map<String, dynamic>>());
    for (final key in [
      'forum',
      'event',
      'moderation',
      'announcement',
      'total',
    ]) {
      expect((json['inbox'] as Map)[key], isA<num>(), reason: key);
    }
  });

  test('缺欄位視為 0', () {
    final s = NotificationSummary.fromJson({});
    expect(s, NotificationSummary.empty);
  });

  test('徽章文字：後端封頂 100 與加總超過 99 都顯示 99+', () {
    expect(badgeLabel(1), '1');
    expect(badgeLabel(99), '99');
    expect(badgeLabel(100), '99+');
    expect(badgeLabel(150), '99+');
  });
}
