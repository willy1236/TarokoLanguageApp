// 搜尋頁尚未搜尋時的建議面板：「最近搜尋」＋「熱門」關鍵字，點一下直接搜尋。
// 兩者都拿不到（或都是空的）時退回原本的提示文字，不影響搜尋本身。

import 'package:flutter/material.dart';

import '../../core/constants/app_typography.dart';
import '../../services/search_assist_service.dart';
import 'module_search_bar.dart';

class SearchSuggestions extends StatefulWidget {
  final SearchModule module;
  final SearchBarPalette palette;
  final bool seniorMode;
  final ValueChanged<String> onSelected;

  /// 沒有任何建議時顯示的提示文字。
  final String placeholder;

  const SearchSuggestions({
    super.key,
    required this.module,
    required this.palette,
    required this.seniorMode,
    required this.onSelected,
    required this.placeholder,
  });

  @override
  State<SearchSuggestions> createState() => _SearchSuggestionsState();
}

class _SearchSuggestionsState extends State<SearchSuggestions> {
  List<String> _history = const [];
  List<String> _popular = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 各自失敗不互相影響：歷史拿不到仍可顯示熱門，反之亦然。
    final results = await Future.wait([
      SearchAssistService.history(widget.module).catchError((_) => <String>[]),
      SearchAssistService.popular(widget.module).catchError((_) => <String>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _history = results[0];
      _popular = results[1];
    });
  }

  Future<void> _clearHistory() async {
    final previous = _history;
    setState(() => _history = const []);
    try {
      await SearchAssistService.clearHistory();
    } catch (_) {
      if (!mounted) return;
      setState(() => _history = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('清除失敗，請稍後再試')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final seniorMode = widget.seniorMode;
    if (_history.isEmpty && _popular.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          widget.placeholder,
          style: AppTypography.serif(
            color: palette.soft,
            fontSize: seniorMode
                ? AppTypography.bodyLarge + AppTypography.seniorStep
                : null,
          ),
        ),
      );
    }
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_history.isNotEmpty) ...[
            _sectionHeader(
              '最近搜尋',
              trailing: TextButton(
                onPressed: _clearHistory,
                child: Text(
                  '清除',
                  style: AppTypography.bodyStyle(
                    seniorMode: seniorMode,
                    color: palette.soft,
                  ),
                ),
              ),
            ),
            _chips(_history, icon: Icons.history_rounded),
            const SizedBox(height: 16),
          ],
          if (_popular.isNotEmpty) ...[
            _sectionHeader('熱門搜尋'),
            _chips(_popular, icon: Icons.trending_up_rounded),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {Widget? trailing}) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.subtitleStyle(
                seniorMode: widget.seniorMode,
                color: widget.palette.foreground,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _chips(List<String> keywords, {required IconData icon}) {
    final palette = widget.palette;
    final seniorMode = widget.seniorMode;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final q in keywords)
          ActionChip(
            avatar: Icon(icon, size: seniorMode ? 20 : 14, color: palette.soft),
            label: Text(q),
            backgroundColor: palette.chipBackground,
            side: BorderSide(color: palette.chipBorder),
            labelStyle: AppTypography.bodyStyle(
              seniorMode: seniorMode,
              color: palette.foreground,
            ),
            onPressed: () => widget.onSelected(q),
          ),
      ],
    );
  }
}
