// 文章／影音搜尋共用骨架：關鍵字／時間區間／部落，三者皆選填、可任意組合。
// 兩個搜尋頁只差在呼叫的 API、提示文案與結果卡片，其餘（分頁、請求世代、
// 錯誤與空狀態）集中在這裡，避免同一個 race condition 修兩次。
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../models/tribe_model.dart';
import '../../services/senior_mode_controller.dart';
import '../../shared/widgets/module_search_bar.dart';

/// 一頁搜尋結果：本頁項目與符合條件的總筆數。
typedef CultureSearchPage<T> = ({List<T> items, int total});

typedef CultureSearchFetch<T> =
    Future<CultureSearchPage<T>> Function({
      String? q,
      String? range,
      int? tribeId,
      required int page,
    });

class CultureSearchScreen<T> extends StatefulWidget {
  const CultureSearchScreen({
    super.key,
    required this.hint,
    required this.emptyText,
    required this.fetch,
    required this.itemBuilder,
  });

  final String hint;
  final String emptyText;
  final CultureSearchFetch<T> fetch;
  final Widget Function(T item, bool seniorMode) itemBuilder;

  @override
  State<CultureSearchScreen<T>> createState() => _CultureSearchScreenState<T>();
}

class _CultureSearchScreenState<T> extends State<CultureSearchScreen<T>> {
  final _controller = TextEditingController();
  String? _q;
  String? _range;
  Tribe? _tribe;

  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  List<T> _items = [];
  bool _searched = false;

  /// 請求世代：每次新查詢遞增，回應套用前比對。快速切換部落/時間篩選時，
  /// 較晚送出但先回應的舊查詢不能覆蓋新結果。
  int _reqGen = 0;

  bool get _hasMore => _items.length < _total;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<CultureSearchPage<T>> _fetch(int page) =>
      widget.fetch(q: _q, range: _range, tribeId: _tribe?.id, page: page);

  Future<void> _search() async {
    final gen = ++_reqGen;
    setState(() {
      _loadingMore = false; // 飛行中的分頁請求已過期，不能再 append 進新清單
      _q = _controller.text.trim();
      _searched = true;
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final res = await _fetch(1);
      if (!mounted || gen != _reqGen) return;
      setState(() {
        _items = res.items;
        _total = res.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _reqGen) return;
      setState(() {
        _error = e is ApiException ? e.message : '搜尋失敗，請稍後再試';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final gen = _reqGen;
    setState(() => _loadingMore = true);
    try {
      final res = await _fetch(_page + 1);
      if (!mounted || gen != _reqGen) return;
      setState(() {
        _items = [..._items, ...res.items];
        _page += 1;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && gen == _reqGen) setState(() => _loadingMore = false);
    }
  }

  void _onTribeSelected(Tribe? tribe) {
    setState(() => _tribe = tribe);
    _search();
  }

  void _setRange(String? range) {
    setState(() => _range = range);
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildScaffold(seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(bool seniorMode) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: ModuleSearchAppBar(
        controller: _controller,
        hint: widget.hint,
        onSubmit: _search,
        palette: SearchBarPalette.dark,
        seniorMode: seniorMode,
        titleFontSize: AppTypography.title,
      ),
      body: Column(
        children: [
          ModuleSearchFilterRow(
            range: _range,
            onRangeSelected: _setRange,
            tribe: _tribe,
            onTribeSelected: _onTribeSelected,
            palette: SearchBarPalette.dark,
            seniorMode: seniorMode,
            chipFontSize: AppTypography.subtitle,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _error!,
                style: TextStyle(
                  color: AppColors.fog,
                  fontSize: seniorMode ? AppTypography.title : null,
                ),
              ),
            ),
          if (!_searched && _error == null)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                '輸入關鍵字或選擇篩選條件開始搜尋',
                style: GoogleFonts.notoSerifTc(
                  color: AppColors.fog,
                  fontSize: seniorMode ? AppTypography.title : null,
                ),
              ),
            ),
          if (_searched) Expanded(child: _resultList(seniorMode)),
        ],
      ),
    );
  }

  Widget _resultList(bool seniorMode) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          widget.emptyText,
          style: TextStyle(
            color: AppColors.fog,
            fontSize: seniorMode ? AppTypography.title : null,
          ),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 200) _loadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            );
          }
          return widget.itemBuilder(_items[i], seniorMode);
        },
      ),
    );
  }
}
