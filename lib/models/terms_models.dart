// 同意條款（服務條款/隱私權政策）model。
// 對應 Truku_backend GET/POST /api/terms 的回應形狀。

class TermsDocument {
  final String docType;
  final int version;
  final String title;
  final String contentMd;
  final String publishedAt;
  final bool consented;
  final int? consentedVersion;

  const TermsDocument({
    required this.docType,
    required this.version,
    required this.title,
    required this.contentMd,
    required this.publishedAt,
    required this.consented,
    required this.consentedVersion,
  });

  factory TermsDocument.fromJson(Map<String, dynamic> json) => TermsDocument(
    docType: json['doc_type'] as String,
    version: json['version'] as int,
    title: json['title'] as String,
    contentMd: json['content_md'] as String,
    publishedAt: json['published_at'] as String,
    consented: json['consented'] as bool,
    consentedVersion: json['consented_version'] as int?,
  );
}

class TermsStatus {
  final List<TermsDocument> documents;
  final bool allConsented;

  const TermsStatus({required this.documents, required this.allConsented});

  factory TermsStatus.fromJson(Map<String, dynamic> json) => TermsStatus(
    documents: (json['documents'] as List<dynamic>? ?? [])
        .map((e) => TermsDocument.fromJson(e as Map<String, dynamic>))
        .toList(),
    allConsented: json['all_consented'] as bool? ?? true,
  );
}
