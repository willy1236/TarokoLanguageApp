// 記錄根 Navigator 目前的 route 堆疊，讓 App 層（例如點通知導頁）知道使用者
// 現在看的是哪一頁。Navigator 本身不提供往下查看 route 的 API。

import 'package:flutter/widgets.dart';

class RouteStack extends NavigatorObserver {
  final List<Route<dynamic>> _routes = [];

  /// 最上層的整頁 route。dialog、bottom sheet 這類 PopupRoute 蓋在頁面上時，
  /// 使用者仍在底下那一頁，所以略過。
  Route<dynamic>? get topPage {
    for (final route in _routes.reversed) {
      if (route is! PopupRoute) return route;
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (newRoute == null) {
      if (i >= 0) _routes.removeAt(i);
    } else if (i >= 0) {
      _routes[i] = newRoute;
    } else {
      _routes.add(newRoute);
    }
  }
}

/// 掛在根 MaterialApp 的 navigatorObservers。
final routeStack = RouteStack();
