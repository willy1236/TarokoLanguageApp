// 契約工具自身的測試。
//
// 這層不驗任何端點，只驗「expectShape 會在該紅的時候紅、不該紅的時候不紅」，
// 以及 maskPii 遮罩後仍保留結構與型別（fixture 要能餵進 model.fromJson）。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../integration_test/helpers/contract.dart';

void main() {
  group('expectShape', () {
    test('必要欄位齊全且型別正確時通過', () {
      expectShape(
        {'uid': 1, 'created_at': '2026-01-01T00:00:00Z'},
        {'uid': F.number, 'created_at': F.string},
      );
    });

    test('缺少必要欄位會失敗', () {
      expect(
        () => expectShape({'uid': 1}, {'uid': F.number, 'created_at': F.string}),
        throwsA(isA<TestFailure>()),
      );
    });

    test('型別不符會失敗', () {
      expect(
        () => expectShape({'uid': '1'}, {'uid': F.number}),
        throwsA(isA<TestFailure>()),
      );
    });

    test('必要欄位為 null 預設失敗，列入 nullable 後通過', () {
      expect(
        () => expectShape({'total': null}, {'total': F.number}),
        throwsA(isA<TestFailure>()),
      );
      expectShape({'total': null}, {'total': F.number},
          nullable: {'total'});
    });

    test('後端多回欄位不會失敗（只提醒）', () {
      expectShape(
        {'uid': 1, 'brand_new_field': 'x'},
        {'uid': F.number},
      );
    });

    test('選填欄位缺席通過，存在但型別錯會失敗', () {
      expectShape({'uid': 1}, {'uid': F.number},
          optional: {'role': F.string});
      expect(
        () => expectShape({'uid': 1, 'role': 3}, {'uid': F.number},
            optional: {'role': F.string}),
        throwsA(isA<TestFailure>()),
      );
    });

    test('F.any 只要 key 存在就通過（涵蓋 event id 字串/數字兩種型態）', () {
      expectShape({'id': '42'}, {'id': F.any});
      expectShape({'id': 42}, {'id': F.any});
    });

    test('非 object 會失敗', () {
      expect(
        () => expectShape([1, 2], {'uid': F.number}),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  group('expectEachShape', () {
    test('空清單通過（資料庫本來就可能是空的）', () {
      expectEachShape(<dynamic>[], {'id': F.number});
    });

    test('任一筆不合就失敗', () {
      expect(
        () => expectEachShape(
          [
            {'id': 1},
            {'title': 'x'},
          ],
          {'id': F.number},
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  group('expectErrorShape', () {
    test('合法錯誤信封通過，錯誤碼可比對', () {
      final res = http.Response(
        jsonEncode({
          'error': {'code': 'NOT_FOUND', 'message': '找不到'},
        }),
        404,
        // 不指定 charset 的話 http.Response 會用 latin1 編碼，中文訊息會丟例外；
        // 真實後端回應本來就帶 utf-8，這裡比照。
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      expectErrorShape(res);
      expectErrorShape(res, code: 'NOT_FOUND');
      expect(
        () => expectErrorShape(res, code: 'OTHER'),
        throwsA(isA<TestFailure>()),
      );
    });

    test('沒有 error 信封會失敗', () {
      expect(
        () => expectErrorShape(http.Response(jsonEncode({'msg': 'x'}), 404)),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  group('maskPii', () {
    test('遮罩個資但保留型別與結構', () {
      final masked = maskPii({
        'uid': 7,
        'email': 'real@gmail.com',
        'display_name': '真實姓名',
        'friend_code': 'ABCD1234',
        'nested': [
          {'email': 'other@gmail.com', 'keep': 'ok'},
        ],
      }) as Map<String, dynamic>;

      expect(masked['uid'], 7);
      expect(masked['email'], 'redacted@example.com');
      expect(masked['display_name'], '測試使用者');
      expect(masked['friend_code'], 'TESTCODE');
      expect((masked['nested'] as List).first['email'], 'redacted@example.com');
      expect((masked['nested'] as List).first['keep'], 'ok');
    });

    test('null 值不會被換成字串（型別必須保持）', () {
      final masked = maskPii({'display_name': null}) as Map<String, dynamic>;
      expect(masked['display_name'], isNull);
    });

    test('使用者產生的內容整欄換掉，不留真實發文', () {
      final masked = maskPii({
        'title': '官方活動整理｜布洛灣景觀復原行動',
        'body': '這是某位使用者真的發過的內文。',
        'content_md': '# 服務條款\n\n如有問題請來信 someone@gmail.com。',
      }) as Map<String, dynamic>;

      expect(masked['title'], '測試標題');
      expect(masked['body'], '測試內文');
      expect(masked['content_md'], '測試內文');
    });

    // 下面兩支用不在名單裡的欄位名，測的是兜底那層：
    // 後端哪天多回一個沒人想到的欄位，個資也不該漏出去。
    test('沒列在名單裡的欄位，內文裡的 email 仍會被遮', () {
      final masked = maskPii({
        'some_new_field': '有問題請來信 someone@gmail.com 與我們聯繫。',
      }) as Map<String, dynamic>;

      expect(masked['some_new_field'], contains('redacted@example.com'));
      expect(masked['some_new_field'], isNot(contains('someone@gmail.com')));
      // 只換掉 email 本身，其餘原樣保留。
      expect(masked['some_new_field'], contains('與我們聯繫'));
    });

    test('沒列在名單裡的欄位，內文裡的電話仍會被遮', () {
      final masked = maskPii({'some_new_field': '報名請撥 0912-345678'})
          as Map<String, dynamic>;
      expect(masked['some_new_field'], '報名請撥 0900000000');
    });

    test('UUID 裡長得像電話的片段不會被誤遮', () {
      const uuid = 'aec52c55-fc91-415a-be04-9204538467df';
      final masked = maskPii({'session_id': uuid}) as Map<String, dynamic>;
      expect(masked['session_id'], uuid);
    });

    test('ISO 時間字串不會被誤遮', () {
      const at = '2026-09-04T05:28:38.406Z';
      final masked = maskPii({'created_at': at}) as Map<String, dynamic>;
      expect(masked['created_at'], at);
    });
  });

  group('fixtureName', () {
    test('由 method 與 path 產生檔名', () {
      expect(fixtureName('GET', '/api/me'), 'get_api_me.json');
      expect(fixtureName('POST', '/api/quiz/start'), 'post_api_quiz_start.json');
    });

    test('query 變體各自成檔', () {
      expect(
        fixtureName('GET', '/api/videos?sort=popular'),
        'get_api_videos_sort_popular.json',
      );
      expect(
        fixtureName('GET', '/api/videos'),
        isNot(fixtureName('GET', '/api/videos?sort=popular')),
      );
    });
  });
}
