// 輸入框字數上限改以 UTF-16 單位計算，與後端 JS 的 `.length` 一致。
//
// TextField 的 maxLength 以字形叢集計數，emoji 算 1，後端卻算 2：前端顯示未滿、
// 送出後才被 400 退回。有後端長度上限的輸入框改用這組，不要再設 maxLength：
//
//   TextField(
//     controller: controller,
//     inputFormatters: [Utf16LengthLimitingTextInputFormatter(500)],
//     buildCounter: utf16CounterBuilder(controller, 500),
//   )
//
// 中文、族語字母都在 BMP 內，一字仍算 1，計數與原本相同。

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 把 [text] 截到不超過 [max] 個 UTF-16 單位，只在字形叢集邊界切，
/// 不會把 emoji 切成半個（亂碼）。
String truncateUtf16(String text, int max) {
  if (text.length <= max) return text;
  final buffer = StringBuffer();
  var length = 0;
  for (final char in text.characters) {
    if (length + char.length > max) break;
    buffer.write(char);
    length += char.length;
  }
  return buffer.toString();
}

/// 以 UTF-16 單位限制長度的 formatter。超過上限時只截「這次新插入的那一段」，
/// 游標在中間輸入也不會吃掉結尾原有的字。組字中（注音、倉頡等輸入法）先不截，
/// 選字完成後才截，避免打斷輸入法。
class Utf16LengthLimitingTextInputFormatter extends TextInputFormatter {
  final int maxLength;

  const Utf16LengthLimitingTextInputFormatter(this.maxLength);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= maxLength) return newValue;
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final oldText = oldValue.text;
    final newText = newValue.text;

    // 新舊文字相同的開頭與結尾之間，就是這次插入（或取代）的內容。
    var prefix = 0;
    final maxPrefix = min(oldText.length, newText.length);
    while (prefix < maxPrefix &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    final maxSuffix = min(oldText.length, newText.length) - prefix;
    while (suffix < maxSuffix &&
        oldText.codeUnitAt(oldText.length - 1 - suffix) ==
            newText.codeUnitAt(newText.length - 1 - suffix)) {
      suffix++;
    }
    // 不從 surrogate pair 中間切開。
    if (prefix > 0 && _isHighSurrogate(newText.codeUnitAt(prefix - 1))) {
      prefix--;
    }
    if (suffix > 0 &&
        _isLowSurrogate(newText.codeUnitAt(newText.length - suffix))) {
      suffix--;
    }

    final head = newText.substring(0, prefix);
    final tail = newText.substring(newText.length - suffix);
    final inserted = newText.substring(prefix, newText.length - suffix);
    final room = max(0, maxLength - head.length - tail.length);
    final kept = truncateUtf16(inserted, room);
    final cursor = head.length + kept.length;
    return TextEditingValue(
      text: '$head$kept$tail',
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
  static bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
}

/// 以 UTF-16 單位顯示「目前／上限」的計數器，外觀同 TextField 預設計數器。
/// TextField 會隨 [controller] 變動重建，計數即時更新。
InputCounterWidgetBuilder utf16CounterBuilder(
  TextEditingController controller,
  int max,
) {
  return (context, {required currentLength, required isFocused, maxLength}) {
    final length = controller.text.length;
    final theme = Theme.of(context);
    return Text(
      '$length/$max',
      style: theme.textTheme.bodySmall?.copyWith(
        color: length > max
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
      ),
      semanticsLabel: '已輸入 $length 字，上限 $max 字',
    );
  };
}
