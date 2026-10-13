// 點通知導頁的共用規則：目標頁已是最上層的整頁（上面只蓋著 dialog 也算）時
// 就地重載，否則疊一份新的。不 pop 回已開著的那份：它可能被通話、響鈴畫面蓋住，
// pop 會拆掉通話。
//
// 目標頁的 State 接上 [RefreshableRouteMixin]，就會以所在的 route 登記，
// 導頁時用 [openOrRefresh]（或只要重載的 [refreshIfTop]）找到它。

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'route_stack.dart';

/// 可被推播就地重載的頁面。以所在的 route 為 key 登記：同一頁開了兩份時各自
/// 登記，關掉上層那份不影響下層。
mixin RefreshableRouteMixin<W extends StatefulWidget> on State<W> {
  static final Map<Route<dynamic>, RefreshableRouteMixin> _registry = {};

  Route<dynamic>? _registeredRoute;

  /// 這一頁所在、用來登記的 route；第一次 [didChangeDependencies] 之前為 null。
  Route<dynamic>? get registeredRoute => _registeredRoute;

  /// 導頁時人已在這一頁：就地重載。[args] 由各頁自訂（論壇是要捲去的留言 id，
  /// 收件匣是要切去的分類）。
  Future<void> onRouteRefresh(Object? args);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && _registeredRoute == null) {
      _registeredRoute = route;
      _registry[route] = this;
    }
  }

  @override
  void dispose() {
    final route = _registeredRoute;
    if (route != null && identical(_registry[route], this)) {
      _registry.remove(route);
    }
    super.dispose();
  }

  /// [route] 上登記的頁面；沒有登記（不是可重載的頁、或已關掉）時為 null。
  static RefreshableRouteMixin? lookup(Route<dynamic> route) =>
      _registry[route];

  /// 重載 [route] 上登記的頁面；找不到登記時回傳 false。
  static bool refresh(Route<dynamic> route, [Object? args]) {
    final state = _registry[route];
    if (state == null) return false;
    unawaited(state.onRouteRefresh(args));
    return true;
  }
}

/// 最上層的整頁是 [name] 時就地重載並回傳 true（頁面沒登記時不做事，仍回傳
/// true，不另外疊頁）；否則回傳 false，由呼叫端決定要不要開新頁。
bool refreshIfTop(RouteStack routes, {required String name, Object? args}) {
  final top = routes.topPage;
  if (top == null || top.settings.name != name) return false;
  RefreshableRouteMixin.refresh(top, args);
  return true;
}

/// 點通知導頁：最上層的整頁是 [name] 時就地重載（帶 [refreshArgs]），否則
/// push [build] 建出的新頁。Navigator 還沒掛上時略過。
void openOrRefresh(
  RouteStack routes, {
  required String name,
  required Route<dynamic> Function() build,
  Object? refreshArgs,
}) {
  if (refreshIfTop(routes, name: name, args: refreshArgs)) return;
  final nav = routes.navigator;
  if (nav == null) {
    debugPrint('openOrRefresh: Navigator 尚未掛上，導頁被忽略（$name）');
    return;
  }
  nav.push(build());
}
