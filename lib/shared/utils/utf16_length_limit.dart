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

/// 以 UTF-16 單位限制長度的 formatter。組字中（注音、倉頡等輸入法）先不截，
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
    final truncated = truncateUtf16(newValue.text, maxLength);
    return TextEditingValue(
      text: truncated,
      selection: newValue.selection.copyWith(
        baseOffset: newValue.selection.baseOffset.clamp(0, truncated.length),
        extentOffset: newValue.selection.extentOffset.clamp(
          0,
          truncated.length,
        ),
      ),
    );
  }
}

/// 以 UTF-16 單位顯示「目前／上限」的計數器，外觀同 TextField 預設計數器。
/// TextField 會隨 [controller] 變動重建，計數即時更新。
InputCounterWidgetBuilder utf16CounterBuilder(
  TextEditingController controller,
  int max, {
  TextStyle? style,
}) {
  return (context, {required currentLength, required isFocused, maxLength}) {
    final length = controller.text.length;
    final theme = Theme.of(context);
    return Text(
      '$length/$max',
      style:
          style ??
          theme.textTheme.bodySmall?.copyWith(
            color: length > max ? theme.colorScheme.error : null,
          ),
      semanticsLabel: '已輸入 $length 字，上限 $max 字',
    );
  };
}
