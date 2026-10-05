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
import '../../shared/utils/cursor_pager.dart';
import '../../shared/utils/pager_scroll_loader.dart';
import '../../shared/widgets/load_more_retry.dart';

const _pageSize = 20;

class MilletLedgerScreen extends StatefulWidget {
  const MilletLedgerScreen({super.key});

  @override
  State<MilletLedgerScreen> createState() => _MilletLedgerScreenState();
}

class _MilletLedgerScreenState extends State<MilletLedgerScreen> {
  final _scrollController = ScrollController();
  late final PagerScrollLoader _scrollLoader;
  final _pager = CursorPager<MilletTransaction>(
    fetch: (cursor) async {
      final result = await MilletService.fetchTransactions(
        cursor: cursor,
        limit: _pageSize,
      );
      return (result.transactions, result.pageInfo);
    },
    idOf: (tx) => tx.id,
  );

  @override
  void initState() {
    super.initState();
    _scrollLoader = PagerScrollLoader(
      controller: _scrollController,
      pager: _pager,
      nearEndExtent: 200,
    );
    _pager.refresh();
  }

  @override
  void dispose() {
    _scrollLoader.dispose();
    _scrollController.dispose();
    _pager.dispose();
    super.dispose();
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
      body: ListenableBuilder(
        listenable: Listenable.merge([seniorModeController, _pager]),
        builder: (context, _) => _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final transactions = _pager.items;
    if (_pager.loading) return const TrukuLoadingView();
    if (_pager.error != null) {
      return TrukuErrorView(error: _pager.error, onRetry: _pager.refresh);
    }
    if (transactions.isEmpty) {
      return TrukuEmptyState(
        icon: Icons.receipt_long_outlined,
        message: '目前沒有小米幣明細',
        subtitle: '每日簽到、兌換商品的收支會記錄在這裡。',
        seniorMode: seniorModeController.enabled,
      );
    }
    return RefreshIndicator(
      onRefresh: _pager.refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: transactions.length + 1,
        itemBuilder: (context, index) {
          if (index == transactions.length) {
            if (_pager.loadMoreFailed) {
              return LoadMoreRetry(
                onRetry: _pager.retryLoadMore,
                color: AppColors.primary,
                seniorMode: seniorModeController.enabled,
              );
            }
            if (!_pager.loadingMore) return const SizedBox.shrink();
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          final tx = transactions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MilletTransactionRow(transaction: tx),
          );
        },
      ),
    );
  }
}
