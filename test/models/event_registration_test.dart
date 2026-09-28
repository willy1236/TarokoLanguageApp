import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/event_model.dart';

void main() {
  group('EventRegistration.tryFromJson', () {
    test('格式正確時帶出報名時間與 email', () {
      final r = EventRegistration.tryFromJson({
        'joined_at': '2026-11-20T02:30:00Z',
        'contact_email': 'me@example.com',
      });
      expect(r?.joinedAt, DateTime.utc(2026, 11, 20, 2, 30));
      expect(r?.contactEmail, 'me@example.com');
    });

    test('不是物件、joined_at 缺少或格式不對時回 null', () {
      expect(EventRegistration.tryFromJson(null), isNull);
      expect(EventRegistration.tryFromJson('x'), isNull);
      expect(EventRegistration.tryFromJson({'contact_email': 'a@b.c'}), isNull);
      expect(EventRegistration.tryFromJson({'joined_at': 'nope'}), isNull);
      expect(EventRegistration.tryFromJson({'joined_at': 123}), isNull);
    });

    test('contact_email 不是字串時當作沒有，報名時間照留', () {
      final r = EventRegistration.tryFromJson({
        'joined_at': '2026-11-20T02:30:00Z',
        'contact_email': 42,
      });
      expect(r, isNotNull);
      expect(r!.contactEmail, isNull);
    });
  });
}
