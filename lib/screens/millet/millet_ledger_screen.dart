import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_format.dart';
import '../../models/millet_transaction.dart';
import '../../services/millet_service.dart';
import '../../shared/widgets/millet_coin_icon.dart';

const _pageSize = 20;

const Map<String, IconData> _reasonIcons = {
  'checkin': Icons.event_available,
  'purchase': Icons.shopping_bag,
};

const Map<String, String> _reasonLabels = {
  'checkin': '每日簽到',
  'purchase': '購買',
  'opening_balance': '期初餘額',
};

class MilletLedgerScreen extends StatefulWidget {
  const MilletLedgerScreen({super.key});

  @override
  State<MilletLedgerScreen> createState() => _MilletLedgerScreenState();
}

class _MilletLedgerScreenState extends State<MilletLedgerScreen> {
  final _scrollController = ScrollController();
  int? _cursor;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _initialLoading = true;
  Object? _error;
  final List<MilletTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      final result = await MilletService.fetchTransactions(limit: _pageSize);
      setState(() {
        _transactions
          ..clear()
          ..addAll(result.transactions);
        _cursor = result.nextCursor;
        _hasMore = result.nextCursor != null;
        _initialLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    setState(() => _loadingMore = true);
    try {
      final result = await MilletService.fetchTransactions(
        before: _cursor,
        limit: _pageSize,
      );
      setState(() {
        _transactions.addAll(result.transactions);
        _cursor = result.nextCursor;
        _hasMore = result.nextCursor != null;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('MilletLedgerScreen._loadNextPage failed: $e');
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text(
          '小米明細',
          style: GoogleFonts.notoSerifTc(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      final isUnauthorized = isAuthError(_error);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isUnauthorized ? '請先登入' : '載入失敗，請稍後再試',
                style: GoogleFonts.notoSerifTc(
                  fontSize: 15,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFirstPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.creamLight,
                ),
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }
    if (_transactions.isEmpty) {
      return Center(
        child: Text(
          '目前沒有小米幣明細',
          style: GoogleFonts.notoSansTc(fontSize: 14, color: AppColors.fog),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _transactions.length + 1,
        itemBuilder: (context, index) {
          if (index == _transactions.length) {
            if (!_loadingMore) return const SizedBox.shrink();
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          final tx = _transactions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MilletRow(transaction: tx),
          );
        },
      ),
    );
  }
}

class _MilletRow extends StatelessWidget {
  final MilletTransaction transaction;

  const _MilletRow({required this.transaction});

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
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle != null
                      ? '$subtitle · ${_timeLabel()}'
                      : _timeLabel(),
                  style: const TextStyle(fontSize: 11, color: AppColors.fog),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : ''}${transaction.delta}',
                style: GoogleFonts.notoSerifTc(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: deltaColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '餘額 ${transaction.balanceAfter}',
                style: const TextStyle(fontSize: 10, color: AppColors.fog),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
