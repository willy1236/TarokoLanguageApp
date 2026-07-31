/// audioplayers 會對 URL 做一次 decode 再 encode；若字串裡有「%」但不是合法的
/// percent-encoding（例如檔名本身含有未跳脫的 %），或字串中含有未編碼的非
/// ASCII 字元（例如中文檔名片段），decode 階段就會丟 ArgumentError。
/// 這裡自行把 URL 補成保證可安全 decode 的形式，不依賴套件內部的例外處理。
String sanitizeAudioUrl(String raw) {
  final escaped = raw.replaceAllMapped(
    RegExp(r'%(?![0-9A-Fa-f]{2})'),
    (_) => '%25',
  );
  try {
    if (Uri.decodeFull(escaped) != escaped) {
      // decode 後不同，代表已經是合法的 percent-encoding，原樣使用即可。
      return escaped;
    }
  } on ArgumentError {
    // 含有未編碼的非 ASCII 字元，需要整段重新編碼。
  }
  return Uri.encodeFull(escaped);
}
