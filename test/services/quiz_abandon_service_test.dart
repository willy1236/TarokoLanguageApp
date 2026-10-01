// POST /api/quiz/abandon、/api/listening/abandon 的錯誤處理：
// 404 SESSION_NOT_FOUND 代表已經放棄過，視同成功；其他錯誤丟給呼叫端。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/services/learn_service.dart';

import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(stubCommonChannels);
  tearDown(restoreHttp);

  final cases = {'/api/quiz/abandon': LearnService.abandonQuiz};

  for (final MapEntry(key: path, value: abandon) in cases.entries) {
    group(path, () {
      test('帶舊測驗的 session_id 送出', () async {
        Object? body;
        installMockClient({
          path: {'ok': true, 'abandoned_level': '初級'},
        }, onRequest: (r) => body = jsonDecode(r.body));

        await abandon('s-old');

        expect(body, {'session_id': 's-old'});
      });

      test('404 SESSION_NOT_FOUND 視同成功', () async {
        installMockClient({
          path: errorResponse('SESSION_NOT_FOUND', status: 404),
        });

        await expectLater(abandon('s-old'), completes);
      });

      test('409 SESSION_ALREADY_COMPLETED 丟給呼叫端', () async {
        installMockClient({
          path: errorResponse(
            'SESSION_ALREADY_COMPLETED',
            status: 409,
            message: '測驗已完成，不能放棄',
          ),
        });

        await expectLater(
          abandon('s-old'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.isSessionAlreadyCompleted, 'completed', true)
                .having((e) => e.message, 'message', '測驗已完成，不能放棄'),
          ),
        );
      });
    });
  }
}
