// 帳號暫時無法使用的好友進不了公開檔案，只能從好友列表解除。

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_application_1/screens/friends/friends_list_screen.dart';

import '../helpers/fixtures.dart';
import '../helpers/flow_test_helpers.dart';
import '../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> seen;

  setUp(() {
    stubCommonChannels();
    seen = [];
    installMockClient({
      '/api/friends': loadSpecFixtureMap('get_api_friends.json'),
      '/api/friends/messages': {'conversations': []},
      '/api/shop/items': {'items': []},
      '/api/friends/CCCC2345': {'ok': true},
    }, onRequest: seen.add);
  });
  tearDown(restoreHttp);

  testWidgets('確認後以好友碼解除，並從列表移除', (tester) async {
    await tester.pumpWidget(wrapScreen(const FriendsListScreen()));
    await pumpFrames(tester);
    expect(find.text('暫時無法使用'), findsOneWidget);

    await tester.tap(find.byTooltip('刪除好友'));
    await pumpFrames(tester);
    await tester.tap(find.text('刪除'));
    await pumpFrames(tester);

    expect(seen.where((r) => r.method == 'DELETE').map((r) => r.url.path), [
      '/api/friends/CCCC2345',
    ]);
    expect(find.text('暫時無法使用'), findsNothing);
    // 暱稱旁附好友碼末碼，是 rich text。
    expect(find.textContaining('阿華', findRichText: true), findsOneWidget);
  });

  testWidgets('取消就不送出', (tester) async {
    await tester.pumpWidget(wrapScreen(const FriendsListScreen()));
    await pumpFrames(tester);

    await tester.tap(find.byTooltip('刪除好友'));
    await pumpFrames(tester);
    await tester.tap(find.text('取消'));
    await pumpFrames(tester);

    expect(seen.where((r) => r.method == 'DELETE'), isEmpty);
    expect(find.text('暫時無法使用'), findsOneWidget);
  });

  testWidgets('沒有好友碼就不顯示刪除鈕', (tester) async {
    final json = loadSpecFixtureMap('get_api_friends.json');
    for (final f in (json['friends'] as List).cast<Map<String, dynamic>>()) {
      if (f['unavailable'] == true) f['friend_code'] = null;
    }
    installMockClient({
      '/api/friends': json,
      '/api/friends/messages': {'conversations': []},
      '/api/shop/items': {'items': []},
    });

    await tester.pumpWidget(wrapScreen(const FriendsListScreen()));
    await pumpFrames(tester);

    expect(find.text('暫時無法使用'), findsOneWidget);
    expect(find.byTooltip('刪除好友'), findsNothing);
  });
}
