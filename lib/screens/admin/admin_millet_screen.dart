// 小米幣查帳：以好友碼查人後，顯示對帳結果與明細（捲到底載下一頁）。
// 使用者反映小米幣不對時用；唯讀，後端不記操作紀錄。

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../models/admin_models.dart';
import '../../models/millet_transaction.dart';
import '../../services/admin_service.dart';
import '../millet/widgets/millet_transaction_row.dart';
import 'admin_error.dart';
import 'widgets/admin_user_lookup.dart';
import 'widgets/admin_widgets.dart';

class AdminMilletScreen extends StatefulWidget {
  const AdminMilletScreen({super.key});

  @override
  State<AdminMilletScreen> createState() => _AdminMilletScreenState();
}

class _AdminMilletScreenState extends State<AdminMilletScreen> {
  final _scroll = ScrollController();
  AdminUserLookup? _user;
  AdminMilletReconcile? _reconcile;
  final List<MilletTransaction> _transactions = [];
  String? _cursor;
  bool _loading = false;
  bool _loadingMore = false;

  /// 換對象時加一：上一位對象晚回來的回應直接丟掉。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onUserChanged(AdminUserLookup? user) {
    final generation = ++_generation;
    setState(() {
      _user = user;
      _reconcile = null;
      _transactions.clear();
      _cursor = null;
      _loading = user != null;
      _loadingMore = false;
    });
    if (user != null) _loadFirst(user.uid, generation);
  }

  Future<void> _loadFirst(int uid, int generation) async {
    try {
      final (reconcile, page) = await (
        AdminService.reconcileMillet(uid),
        AdminService.fetchMilletTransactions(uid),
      ).wait;
      if (!mounted || generation != _generation) return;
      setState(() {
        _reconcile = reconcile;
        _transactions.addAll(page.transactions);
        _cursor = page.pageInfo.nextCursor;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
      final error = e is ParallelWaitError ? _firstError(e) : e;
      handleAdminError(context, error);
    }
  }

  static Object _firstError(ParallelWaitError e) {
    final (a, b) = e.errors as (AsyncError?, AsyncError?);
    return (a ?? b)!.error;
  }

  Future<void> _loadMore() async {
    final user = _user;
    final cursor = _cursor;
    if (user == null || cursor == null || _loading || _loadingMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final page = await AdminService.fetchMilletTransactions(
        user.uid,
        cursor: cursor,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _transactions.addAll(page.transactions);
        _cursor = page.pageInfo.nextCursor;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _loadingMore = false);
      handleAdminError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '小米幣查帳',
    body: (context, senior) => ListView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        AdminUserLookupPanel(seniorMode: senior, onChanged: _onUserChanged),
        if (_loading) _spinner(),
        if (_reconcile != null) _reconcileCard(_reconcile!, senior),
        if (_user != null && !_loading && _reconcile != null) ...[
          if (_transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: Text(
                  '沒有小米幣明細',
                  style: AppTypography.bodyStyle(
                    seniorMode: senior,
                    color: AppColors.fog,
                  ),
                ),
              ),
            ),
          for (final tx in _transactions)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                10,
              ),
              child: MilletTransactionRow(transaction: tx),
            ),
          if (_loadingMore) _spinner(),
        ],
      ],
    ),
  );

  Widget _spinner() => const Padding(
    padding: EdgeInsets.all(AppSpacing.md),
    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
  );

  Widget _reconcileCard(AdminMilletReconcile r, bool senior) => AdminCard(
    seniorMode: senior,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '對帳結果',
                style: AppTypography.titleStyle(
                  seniorMode: senior,
                  color: AppColors.ink,
                ),
              ),
            ),
            AdminBadge(
              r.ok ? '一致' : '不一致',
              color: r.ok ? AppColors.online : AppColors.danger,
              seniorMode: senior,
            ),
          ],
        ),
        AdminInfoRow('帳本加總', '${r.ledgerSum}', seniorMode: senior),
        AdminInfoRow('目前餘額', '${r.userMillet}', seniorMode: senior),
        if (!r.ok)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '差額 ${r.userMillet - r.ledgerSum}：有餘額變動沒有寫進帳本，請回報後端檢查。',
              style: AppTypography.bodyStyle(
                seniorMode: senior,
                color: AppColors.danger,
              ),
            ),
          ),
      ],
    ),
  );
}
