// 對應 /api/millet/transactions
// 規格參考：說明文件/API/小米幣帳本.md

// id／next_cursor 對應資料庫 BIGSERIAL，pg driver 會回傳字串以避免精度遺失
int? _parseId(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

class MilletTransaction {
  final int id;
  final int delta;
  final String reason; // 'checkin' | 'purchase' | 'opening_balance'
  final String? refId;
  final int balanceAfter;
  final String createdAt;

  const MilletTransaction({
    required this.id,
    required this.delta,
    required this.reason,
    required this.refId,
    required this.balanceAfter,
    required this.createdAt,
  });

  bool get isCredit => delta >= 0;

  factory MilletTransaction.fromJson(Map<String, dynamic> json) {
    return MilletTransaction(
      id: _parseId(json['id']) ?? 0,
      delta: json['delta'] as int? ?? 0,
      reason: json['reason'] as String? ?? '',
      refId: json['ref_id'] as String?,
      balanceAfter: json['balance_after'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class MilletTransactionListResult {
  final List<MilletTransaction> transactions;
  final int? nextCursor;

  const MilletTransactionListResult({
    required this.transactions,
    required this.nextCursor,
  });

  factory MilletTransactionListResult.fromJson(Map<String, dynamic> json) {
    return MilletTransactionListResult(
      transactions: (json['transactions'] as List<dynamic>? ?? [])
          .map((e) => MilletTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: _parseId(json['next_cursor']),
    );
  }
}
