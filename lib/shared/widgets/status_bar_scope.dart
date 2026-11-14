import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 狀態列圖示的明暗。
///
/// 全域預設是深色圖示（[lightBackgroundStyle]，給米白底畫面）；頂端是深色區塊的畫面（登入、
/// 視訊、學習影音、個人頁 hero 等）用 [StatusBarScope.onDark] 包起來改成淺色圖示。
/// 有 AppBar 的畫面不必處理，AppBar 會依自己的底色決定。
///
/// 用 AnnotatedRegion 而不是 `SystemChrome.setSystemUIOverlayStyle`：樣式跟著畫面
/// 在不在畫面上走，切換分頁或離開頁面時不會殘留上一頁的設定。
class StatusBarScope extends StatelessWidget {
  /// 米白底：深色圖示。iOS 的 statusBarBrightness 指的是「底色」明暗，與 Android 相反。
  static const lightBackgroundStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  /// 深色底：淺色圖示。
  static const darkBackgroundStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  final SystemUiOverlayStyle style;
  final Widget child;

  const StatusBarScope.onDark({super.key, required this.child})
    : style = darkBackgroundStyle;

  const StatusBarScope.onLight({super.key, required this.child})
    : style = lightBackgroundStyle;

  @override
  Widget build(BuildContext context) =>
      AnnotatedRegion<SystemUiOverlayStyle>(value: style, child: child);
}
