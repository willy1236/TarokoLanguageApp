// 別人的暱稱旁附好友碼末 4 碼（例如「阿華 #K7Q2」）。暱稱不要求唯一，
// 同名的人靠末碼區分，也比較不容易被冒充。自己的暱稱不附，由呼叫端傳 null。
// 規格：Truku_backend 說明文件/前端交接/2026-09-28_前端待辦.md A3

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// 好友碼末 4 碼轉大寫；沒有好友碼時回 null，不出現孤立的 `#`。
String? friendCodeTag(String? friendCode) {
  final code = friendCode?.trim() ?? '';
  if (code.isEmpty) return null;
  final tail = code.length > 4 ? code.substring(code.length - 4) : code;
  return '#${tail.toUpperCase()}';
}

/// 暱稱與淡色末碼的 [TextSpan]，給暱稱只是整句一部分的地方（例如「阿華 回覆了你的貼文」）。
/// 末碼沿用 [style] 的字級，顏色淡化；[style] 沒有顏色時退回 [AppColors.fog]。
TextSpan nicknameSpan(String nickname, String? friendCode, {TextStyle? style}) {
  final tag = friendCodeTag(friendCode);
  return TextSpan(
    text: nickname,
    style: style,
    children: [
      if (tag != null) TextSpan(text: ' $tag', style: _tagStyle(style)),
    ],
  );
}

TextStyle _tagStyle(TextStyle? style) => TextStyle(
  color: style?.color?.withValues(alpha: 0.55) ?? AppColors.fog,
  fontWeight: FontWeight.w400,
  letterSpacing: 0.4,
);

/// 單獨顯示暱稱的 [Text]，用法同 `Text(nickname, style: ...)`，多一個 [friendCode]。
///
/// 末碼獨立排版、不參與截斷：暱稱過長時只截暱稱，否則故意取長名字就能把末碼
/// 擠出畫面，失去防冒充的作用。
class NicknameText extends StatelessWidget {
  final String nickname;
  final String? friendCode;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const NicknameText(
    this.nickname, {
    super.key,
    required this.friendCode,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final name = Text(
      nickname,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
    final tag = friendCodeTag(friendCode);
    if (tag == null) return name;
    final resolved = DefaultTextStyle.of(context).style.merge(style);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(child: name),
        Text(
          ' $tag',
          style: resolved.merge(_tagStyle(resolved)),
          maxLines: 1,
          softWrap: false,
        ),
      ],
    );
  }
}
