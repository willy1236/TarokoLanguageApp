// 資料來源與授權 model。
// 對應 Truku_backend GET /api/data-sources 的回應形狀
// （見 Truku_backend 說明文件/API/資料來源與授權.md）。

class DataSources {
  /// 區塊標題，例如「資料來源與授權」。
  final String title;

  /// 依後端給的順序排列，筆數不固定。
  final List<DataSource> sources;

  const DataSources({required this.title, required this.sources});

  factory DataSources.fromJson(Map<String, dynamic> json) => DataSources(
    title: json['title'] as String,
    sources: (json['sources'] as List<dynamic>)
        .map((e) => DataSource.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class DataSource {
  /// 穩定識別碼，可當 widget key。
  final String id;
  final String name;

  /// 用在哪些內容，例如「單字」「音檔」。
  final List<String> usedFor;

  /// 授權條款簡稱；沒有適用條款時（如 YouTube 嵌入）為 null。
  final String? license;

  /// 授權方要求的標示文字，必須原樣顯示，不截斷、不改寫。
  final String attribution;
  final List<DataSourceLink> links;

  const DataSource({
    required this.id,
    required this.name,
    required this.usedFor,
    required this.license,
    required this.attribution,
    required this.links,
  });

  factory DataSource.fromJson(Map<String, dynamic> json) => DataSource(
    id: json['id'] as String,
    name: json['name'] as String,
    usedFor: (json['used_for'] as List<dynamic>? ?? const [])
        .cast<String>()
        .toList(),
    license: json['license'] as String?,
    attribution: json['attribution'] as String,
    links: (json['links'] as List<dynamic>? ?? const [])
        .map((e) => DataSourceLink.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class DataSourceLink {
  final String label;
  final String url;

  const DataSourceLink({required this.label, required this.url});

  factory DataSourceLink.fromJson(Map<String, dynamic> json) => DataSourceLink(
    label: json['label'] as String,
    url: json['url'] as String,
  );
}
