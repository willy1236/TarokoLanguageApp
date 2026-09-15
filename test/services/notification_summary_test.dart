import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/notification_summary_service.dart';

void main() {
  test('解析 summary 並依分頁加總', () {
    final s = NotificationSummary.fromJson({
      'forum': 3,
      'events': 2,
      'messages': 5,
      'friend_requests': 1,
      'total': 11,
    });
    expect(s.plaza, 5);
    expect(s.friends, 6);
    expect(s.total, 11);
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
