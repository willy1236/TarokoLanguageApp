import 'package:flutter/material.dart';

/// 可點擊的區塊：按下時淡出的回饋＋button 無障礙語意。
///
/// 取代裸的 `GestureDetector(onTap:, child:)`。卡片、chip 的外框是有底色的
/// Container，InkWell 的水波紋會被蓋在底下看不到，所以用透明度做按壓回饋。
///
/// 語意：[child] 裡的文字會合併成 button 的 label；只有 icon、沒有文字的
/// 區塊要傳 [semanticLabel]。[onTap] 為 null 時是停用狀態（不回應、語意為 disabled）。
class Pressable extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 有明確選取狀態的元件（篩選 chip、分頁）才傳；null 表示沒有選取概念。
  final bool? selected;

  /// 開關類元件才傳，語意會是 toggled 而不是 selected。
  final bool? toggled;

  /// 取代子孫文字的朗讀內容；沒有文字的 icon 按鈕必傳。
  final String? semanticLabel;
  final HitTestBehavior? behavior;
  final Widget child;

  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.selected,
    this.toggled,
    this.semanticLabel,
    this.behavior,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down != value && mounted) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: widget.selected,
        toggled: widget.toggled,
        label: widget.semanticLabel,
        excludeSemantics: widget.semanticLabel != null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: GestureDetector(
          behavior: widget.behavior,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: enabled ? (_) => _setDown(true) : null,
          onTapUp: (_) => _setDown(false),
          onTapCancel: () => _setDown(false),
          child: AnimatedOpacity(
            opacity: _down ? 0.6 : 1.0,
            duration: const Duration(milliseconds: 80),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
