/// audioplayers 會對 URL 做一次 decode 再 encode；若字串裡有「%」但不是合法的
/// percent-encoding（例如檔名本身含有未跳脫的 %），decode 階段就會丟
/// ArgumentError。這裡把不合法的 % 都轉成 %25，讓它視為一般字元。
String sanitizeAudioUrl(String raw) {
  return raw.replaceAllMapped(
    RegExp(r'%(?![0-9A-Fa-f]{2})'),
    (_) => '%25',
  );
}
