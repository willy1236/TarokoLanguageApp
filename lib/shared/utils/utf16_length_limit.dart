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
    final newText = newValue.text;
    final range = _insertedRange(oldValue, newText);
    final head = newText.substring(0, range.start);
    final tail = newText.substring(range.end);
    // 插入點以外的文字本身就超過上限（例如組字中放行的內容），只能整段截斷。
    if (head.length + tail.length > maxLength) {
      final truncated = truncateUtf16(newText, maxLength);
      return TextEditingValue(
        text: truncated,
        selection: TextSelection.collapsed(offset: truncated.length),
      );
    }
    final kept = truncateUtf16(
      newText.substring(range.start, range.end),
      maxLength - head.length - tail.length,
    );
    return TextEditingValue(
      text: '$head$kept$tail',
      selection: TextSelection.collapsed(offset: head.length + kept.length),
    );
  }

  /// 這次插入（或取代）的內容在 [newText] 中的範圍。依序以舊值的組字範圍
  /// （組字結束時文字可能不變）、舊值的選取範圍定位；都對不上才比對新舊
  /// 文字相同的開頭與結尾。
  static TextRange _insertedRange(TextEditingValue oldValue, String newText) {
    final oldText = oldValue.text;

    TextRange? replacing(TextRange oldRange) {
      if (!oldRange.isValid || oldRange.end > oldText.length) return null;
      final end = newText.length - (oldText.length - oldRange.end);
      if (end < oldRange.start ||
          !newText.startsWith(oldText.substring(0, oldRange.start)) ||
          !newText.endsWith(oldText.substring(oldRange.end))) {
        return null;
      }
      return TextRange(start: oldRange.start, end: end);
    }

    final composing = oldValue.composing;
    final selection = oldValue.selection;
    final located =
        (composing.isValid && !composing.isCollapsed
            ? replacing(composing)
            : null) ??
        (selection.isValid
            ? replacing(TextRange(start: selection.start, end: selection.end))
            : null);
    if (located != null) return located;

    var prefix = 0;
    final shorter = min(oldText.length, newText.length);
    while (prefix < shorter &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < shorter - prefix &&
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
    return TextRange(start: prefix, end: newText.length - suffix);
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
  static bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
}

/// 以 UTF-16 單位顯示「目前／上限」的計數器，外觀同 TextField 預設計數器。
/// TextField 會隨 [controller] 變動重建，計數即時更新。深色底的畫面以 [color]
/// 指定未超過上限時的文字顏色。
InputCounterWidgetBuilder utf16CounterBuilder(
  TextEditingController controller,
  int max, {
  Color? color,
}) {
  return (context, {required currentLength, required isFocused, maxLength}) {
    final length = controller.text.length;
    final theme = Theme.of(context);
    return Text(
      '$length/$max',
      style: theme.textTheme.bodySmall?.copyWith(
        color: length > max
            ? theme.colorScheme.error
            : color ?? theme.colorScheme.onSurfaceVariant,
      ),
      semanticsLabel: '已輸入 $length 字，上限 $max 字',
    );
  };
}

/// 送出前的長度檢查。輸入法組字中 formatter 會先放行，這時直接按送出，
/// 內容可能超過上限；超過時提示「[label]不能超過 [max] 字」並回傳 false。
bool withinUtf16Limit(
  BuildContext context,
  String text,
  int max, {
  String label = '內容',
}) {
  if (text.length <= max) return true;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$label不能超過 $max 字')));
  return false;
}
