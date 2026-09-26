// 學習影音的本週精選輪播：外層重建（例如首頁簽到）不會讓它跳回第一張；
// 不在畫面上時停止自動翻頁，回來時從原本那張重新計時。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:flutter_application_1/core/network/api_client.dart';
import 'package:flutter_application_1/screens/culture/culture_screen.dart';

import '../helpers/widget_test_helpers.dart';

const _interval = Duration(seconds: 5);

/// 精選（sort=weekly_popular）與一般列表用不同標題，才分得出畫面上是哪一塊。
MockClient _client() => MockClient((request) async {
  final featured = request.url.queryParameters['sort'] == 'weekly_popular';
  final prefix = featured ? '精選' : '一般';
  switch (request.url.path) {
    case '/api/videos':
      return jsonResponse({
        'videos': [
          for (var i = 1; i <= 3; i++)
            {'id': i, 'title': '$prefix影片$i', 'category': 'culture'},
        ],
      });
    case '/api/articles':
      return jsonResponse({
        'articles': [
          for (var i = 1; i <= 3; i++)
            {'id': i, 'title': '$prefix文章$i', 'category': 'culture'},
        ],
      });
  }
  return jsonResponse({}, status: 404);
});

/// 模擬 MainContainer：[rebuild] 重建整棵樹（像簽到後的 setState），
/// [setActive] 切換輪播所在分頁是否在畫面上。
class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool active = true;
  int rebuilds = 0;

  void rebuild() => setState(() => rebuilds++);
  void setActive(bool value) => setState(() => active = value);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(body: CultureScreen(active: active)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    stubSecureStorage();
    ApiClient.httpClient = _client();
  });
  tearDown(restoreHttp);

  Future<_HostState> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(const _Host());
    await tester.pumpAndSettle();
    expect(find.text('精選影片1'), findsOneWidget);
    return tester.state<_HostState>(find.byType(_Host));
  }

  Future<void> waitOneTurn(WidgetTester tester) async {
    await tester.pump(_interval);
    await tester.pumpAndSettle();
  }

  // 測試結束時拆掉畫面，輪播的 Timer 才會取消。
  Future<void> teardownHost(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox());

  testWidgets('外層重建時，輪播仍停在原本那張', (tester) async {
    final host = await pumpHost(tester);
    await waitOneTurn(tester);
    expect(find.text('精選影片2'), findsOneWidget);

    host.rebuild();
    await tester.pumpAndSettle();
    expect(find.text('精選影片2'), findsOneWidget);

    await teardownHost(tester);
  });

  testWidgets('不在畫面上時停止翻頁，回來後從原本那張重新計時', (tester) async {
    final host = await pumpHost(tester);
    await waitOneTurn(tester);
    expect(find.text('精選影片2'), findsOneWidget);

    host.setActive(false);
    await tester.pumpAndSettle();
    await waitOneTurn(tester);
    await waitOneTurn(tester);
    expect(find.text('精選影片2'), findsOneWidget);

    host.setActive(true);
    await tester.pumpAndSettle();
    await tester.pump(_interval - const Duration(seconds: 1));
    expect(find.text('精選影片2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('精選影片3'), findsOneWidget);

    await teardownHost(tester);
  });
}
