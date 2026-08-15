import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/forum/forum_compose_screen.dart';

void main() {
  String? check({
    int? boardId = 1,
    String title = '標題',
    String body = '內文',
    List<String> tags = const [],
  }) =>
      forumComposeError(boardId: boardId, title: title, body: body, tags: tags);

  test('全部合法時回傳 null', () {
    expect(check(), isNull);
  });

  test('沒選看板', () {
    expect(check(boardId: null), '請選擇看板');
  });

  test('標題空白或只有空格', () {
    expect(check(title: '   '), '請填寫標題');
  });

  test('標題超過 120 字', () {
    expect(check(title: 'a' * 121), '標題不能超過 120 字');
  });

  test('內文空白', () {
    expect(check(body: ''), '請填寫內文');
  });

  test('內文超過 5000 字', () {
    expect(check(body: 'a' * 5001), '內文不能超過 5000 字');
  });

  test('標籤超過 5 個', () {
    expect(check(tags: ['1', '2', '3', '4', '5', '6']), '標籤最多 5 個');
  });

  test('單一標籤超過 20 字', () {
    expect(check(tags: ['a' * 21]), '每個標籤不能超過 20 字');
  });
}
