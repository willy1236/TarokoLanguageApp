import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/account_service.dart';
import 'package:flutter_application_1/services/auth_service.dart';

void main() {
  test('active 帳號回應沒有 account_state，視為 active 並帶 user', () {
    final r = LoginResult.fromJson({
      'session_token': 't',
      'expires_at': '2026-10-01T00:00:00Z',
      'user': {'uid': 1},
      'is_new_user': false,
    });
    expect(r.isActive, isTrue);
    expect(r.isPendingDeletion, isFalse);
    expect(r.user, {'uid': 1});
    expect(r.purgeAt, isNull);
  });

  test('刪除中帳號回應：account_state + purge_at，沒有 user', () {
    final r = LoginResult.fromJson({
      'session_token': 't',
      'expires_at': '2026-10-01T00:00:00Z',
      'account_state': 'pending_deletion',
      'purge_at': '2026-10-30T00:00:00.000Z',
      'uid': 7,
    });
    expect(r.isPendingDeletion, isTrue);
    expect(r.isActive, isFalse);
    expect(r.user, isNull);
    expect(r.purgeAt, DateTime.utc(2026, 10, 30).toLocal());
  });

  test('daysUntilPurge 無條件進位、過期為 0', () {
    final now = DateTime(2026, 9, 15, 12);
    expect(daysUntilPurge(DateTime(2026, 9, 16, 12), now: now), 1);
    expect(daysUntilPurge(DateTime(2026, 9, 16, 13), now: now), 2);
    expect(daysUntilPurge(DateTime(2026, 9, 15), now: now), 0);
  });
}
