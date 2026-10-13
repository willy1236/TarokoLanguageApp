// 推播導頁的共用登記（refreshable_route.dart）：目標頁在最上層時就地重載，
// 否則疊新頁；登記以 route 為 key，關掉的頁不再被找到。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/navigation/refreshable_route.dart';
import 'package:flutter_application_1/core/navigation/route_stack.dart';

/// 每份頁面的重載紀錄（帶進來的 args），依建立順序排。
final _refreshLog = <List<Object?>>[];

class _Page extends StatefulWidget {
  const _Page(this.label);
  final String label;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with RefreshableRouteMixin {
  final List<Object?> _log = [];

  @override
  void initState() {
    super.initState();
    _refreshLog.add(_log);
  }

  @override
  Future<void> onRouteRefresh(Object? args) async => _log.add(args);

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(widget.label)));
}

Route<void> _pageRoute(String name) => MaterialPageRoute<void>(
  settings: RouteSettings(name: name),
  builder: (_) => _Page(name),
);

void main() {
  final navKey = GlobalKey<NavigatorState>();
  late RouteStack routes;

  setUp(_refreshLog.clear);

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [routes = RouteStack()],
        home: const Scaffold(body: Text('HOME')),
      ),
    );
  }

  Future<void> push(WidgetTester tester, Route<void> route) async {
    navKey.currentState!.push(route);
    await tester.pumpAndSettle();
  }

  group('openOrRefresh', () {
    testWidgets('目標頁在最上層：帶 args 就地重載，不 build、不疊頁', (tester) async {
      await start(tester);
      await push(tester, _pageRoute('a'));
      var built = 0;

      openOrRefresh(
        routes,
        name: 'a',
        build: () {
          built++;
          return _pageRoute('a');
        },
        refreshArgs: 7,
      );
      await tester.pumpAndSettle();

      expect(built, 0);
      expect(_refreshLog, [
        [7],
      ]);
      expect(find.byType(_Page), findsOneWidget);
    });

    testWidgets('上面只蓋著 dialog：仍算在最上層，就地重載，不關 dialog', (tester) async {
      await start(tester);
      await push(tester, _pageRoute('a'));
      showDialog<void>(
        context: navKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('DIALOG')),
      );
      await tester.pumpAndSettle();

      openOrRefresh(routes, name: 'a', build: () => _pageRoute('a'));
      await tester.pumpAndSettle();

      expect(_refreshLog, [
        [null],
      ]);
      expect(find.text('DIALOG'), findsOneWidget);
    });

    testWidgets('最上層是別的頁：push 新頁，不 pop 上層，也不重載下層', (tester) async {
      await start(tester);
      await push(tester, _pageRoute('a'));
      await push(tester, _pageRoute('call'));

      openOrRefresh(routes, name: 'a', build: () => _pageRoute('a'));
      await tester.pumpAndSettle();

      expect(_refreshLog.length, 3);
      expect(_refreshLog.every((log) => log.isEmpty), isTrue);
      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('call'), findsOneWidget);
    });

    testWidgets('Navigator 還沒掛上：略過，不丟例外', (tester) async {
      var built = 0;
      openOrRefresh(
        RouteStack(),
        name: 'a',
        build: () {
          built++;
          return _pageRoute('a');
        },
      );
      expect(built, 0);
    });
  });

  group('RefreshableRouteMixin', () {
    testWidgets('同一頁開了兩份各自登記，關掉上層後重載的是下層那份', (tester) async {
      await start(tester);
      await push(tester, _pageRoute('a'));
      await push(tester, _pageRoute('a'));
      final upper = routes.topPage!;

      navKey.currentState!.pop();
      await tester.pumpAndSettle();

      expect(RefreshableRouteMixin.refresh(upper), isFalse);
      expect(RefreshableRouteMixin.lookup(upper), isNull);
      expect(refreshIfTop(routes, name: 'a', args: 'x'), isTrue);
      await tester.pump();
      expect(_refreshLog, [
        ['x'],
        <Object?>[],
      ]);
    });

    testWidgets('lookup 找得到登記的 State，registeredRoute 是所在的 route', (tester) async {
      await start(tester);
      await push(tester, _pageRoute('a'));
      final top = routes.topPage!;

      final state = RefreshableRouteMixin.lookup(top);
      expect(state, isA<_PageState>());
      expect(state!.registeredRoute, same(top));
    });

    testWidgets('refreshIfTop：最上層不是該頁時回傳 false', (tester) async {
      await start(tester);
      await push(tester, _pageRoute('a'));

      expect(refreshIfTop(routes, name: 'b'), isFalse);
      expect(_refreshLog, [<Object?>[]]);
    });
  });
}
