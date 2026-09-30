import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/millet_transaction.dart';
import '../../services/millet_service.dart';
import 'widgets/millet_transaction_row.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/truku_empty_state.dart';
import '../../core/constants/app_typography.dart';
import '../../shared/widgets/app_back_button.dart';

const _pageSize = 20;

class MilletLedgerScreen extends StatefulWidget {
  const MilletLedgerScreen({super.key});

  @override
  State<MilletLedgerScreen> createState() => _MilletLedgerScreenState();
}

class _MilletLedgerScreenState extends State<MilletLedgerScreen> {
  final _scrollController = ScrollController();
  String? _cursor;
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
    if (_loadingMore || _cursor == null) return;
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
      if (!mounted) return;
      setState(() {
        _transactions
          ..clear()
          ..addAll(result.transactions);
        _cursor = result.pageInfo.nextCursor;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
        cursor: _cursor,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _transactions.addAll(result.transactions);
        _cursor = result.pageInfo.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('MilletLedgerScreen._loadNextPage failed: $e');
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        leading: const AppBackButton(),
        backgroundColor: AppColors.creamLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text(
          '小米明細',
          style: AppTypography.serif(
            fontSize: AppTypography.subtitle,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) return const TrukuLoadingView();
    if (_error != null) {
      return TrukuErrorView(error: _error, onRetry: _loadFirstPage);
    }
    if (_transactions.isEmpty) {
      return TrukuEmptyState(
        icon: Icons.receipt_long_outlined,
        message: '目前沒有小米幣明細',
        subtitle: '每日簽到、兌換商品的收支會記錄在這裡。',
        seniorMode: seniorModeController.enabled,
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
            child: MilletTransactionRow(transaction: tx),
          );
        },
      ),
    );
  }
}
