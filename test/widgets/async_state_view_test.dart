import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/shared/widgets/async_state_view.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('TrukuErrorView', () {
    testWidgets('401 顯示請先登入', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrukuErrorView(
            error: ApiException(
              statusCode: 401,
              code: 'UNAUTHORIZED',
              message: 'x',
            ),
            onRetry: () {},
          ),
        ),
      );
      expect(find.text('請先登入'), findsOneWidget);
    });

    testWidgets('ApiException 顯示後端訊息，其他錯誤顯示 fallback', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TrukuErrorView(
            error: ApiException(statusCode: 500, code: 'X', message: '伺服器忙碌'),
          ),
        ),
      );
      expect(find.text('伺服器忙碌'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(TrukuErrorView(error: StateError('boom'), fallback: '載入失敗')),
      );
      expect(find.text('載入失敗'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('onRetry 為 null 時不顯示重試；有給則可點', (tester) async {
      await tester.pumpWidget(_wrap(const TrukuErrorView(message: 'm')));
      expect(find.text('重試'), findsNothing);

      var retried = 0;
      await tester.pumpWidget(
        _wrap(TrukuErrorView(message: 'm', onRetry: () => retried++)),
      );
      await tester.tap(find.text('重試'));
      expect(retried, 1);
    });
  });

  group('AsyncStateView', () {
    testWidgets('載入中 → 資料', (tester) async {
      final c = Completer<List<int>>();
      await tester.pumpWidget(
        _wrap(
          AsyncStateView<List<int>>(
            future: c.future,
            builder: (_, data) => Text('n=${data.length}'),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      c.complete([1, 2]);
      await tester.pump();
      expect(find.text('n=2'), findsOneWidget);
    });

    testWidgets('空資料顯示 empty', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AsyncStateView<List<int>>(
            future: Future.value(const []),
            builder: (_, _) => const Text('data'),
            isEmpty: (d) => d.isEmpty,
            empty: const Text('空'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('空'), findsOneWidget);
    });

    testWidgets('失敗顯示錯誤與重試', (tester) async {
      final c = Completer<int>();
      await tester.pumpWidget(
        _wrap(
          AsyncStateView<int>(
            future: c.future,
            builder: (_, _) => const Text('data'),
            onRetry: () {},
          ),
        ),
      );
      c.completeError(
        ApiException(statusCode: 500, code: 'X', message: '壞了'),
      );
      await tester.pump();
      expect(find.text('壞了'), findsOneWidget);
      expect(find.text('重試'), findsOneWidget);
    });
  });
}
