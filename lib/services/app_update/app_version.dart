/// 版本名稱（如 `1.0.1`）加上可有可無的 build number（如 `+8`）。
///
/// 比較規則：先比版本名稱，名稱相同再比 build number；任一邊缺 build number
/// 時視為名稱相同即相等（商店只查得到版本名稱）。
class AppVersion implements Comparable<AppVersion> {
  final List<int> parts;
  final int? build;

  const AppVersion(this.parts, [this.build]);

  /// 解析 `1.0.1`、`1.0.1+8`；格式不對回傳 null。
  static AppVersion? tryParse(String? raw) {
    final text = raw?.trim() ?? '';
    final match = RegExp(r'^(\d+(?:\.\d+)*)(?:\+(\d+))?$').firstMatch(text);
    if (match == null) return null;
    final parts = match.group(1)!.split('.').map(int.parse).toList();
    final build = match.group(2);
    return AppVersion(parts, build == null ? null : int.parse(build));
  }

  @override
  int compareTo(AppVersion other) {
    final length = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < length; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    if (build == null || other.build == null) return 0;
    return build!.compareTo(other.build!);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  String toString() =>
      build == null ? parts.join('.') : '${parts.join('.')}+$build';
}
