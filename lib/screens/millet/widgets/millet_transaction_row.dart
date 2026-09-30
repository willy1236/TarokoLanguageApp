// 小米幣明細的一列：使用者自己的明細頁與後台查帳共用。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/millet_transaction.dart';
import '../../../shared/widgets/millet_coin_icon.dart';

const Map<String, IconData> _reasonIcons = {
  'checkin': Icons.event_available,
  'purchase': Icons.shopping_bag,
};

const Map<String, String> _reasonLabels = {
  'checkin': '每日簽到',
  'purchase': '購買',
  'opening_balance': '期初餘額',
};

class MilletTransactionRow extends StatelessWidget {
  final MilletTransaction transaction;

  const MilletTransactionRow({super.key, required this.transaction});

  String? _subtitle() {
    switch (transaction.reason) {
      case 'purchase':
      case 'checkin':
        return transaction.refId;
      default:
        return null;
    }
  }

  String _timeLabel() {
    final dt = DateTime.tryParse(transaction.createdAt);
    if (dt == null) return transaction.createdAt;
    return formatDateTime(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle();
    final isCredit = transaction.isCredit;
    final deltaColor = isCredit ? AppColors.online : AppColors.danger;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamDeep),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: _reasonIcons[transaction.reason] != null
                ? Icon(
                    _reasonIcons[transaction.reason],
                    size: 16,
                    color: AppColors.primary,
                  )
                : const MilletCoinIcon(size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reasonLabels[transaction.reason] ?? transaction.reason,
                  style: AppTypography.serif(
                    fontSize: AppTypography.body,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle != null
                      ? '$subtitle · ${_timeLabel()}'
                      : _timeLabel(),
                  style: const TextStyle(
                    fontSize: AppTypography.caption,
                    color: AppColors.fog,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : ''}${transaction.delta}',
                style: AppTypography.serif(
                  fontSize: AppTypography.bodyLarge,
                  fontWeight: FontWeight.w700,
                  color: deltaColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '餘額 ${transaction.balanceAfter}',
                style: const TextStyle(
                  fontSize: AppTypography.micro,
                  color: AppColors.fog,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
