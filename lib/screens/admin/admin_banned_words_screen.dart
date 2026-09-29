// 髒話詞庫：列表（前端搜尋）、新增、刪除。
// 詞庫有 60 秒快取，增刪後後端會清快取，新詞立即生效。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/truku_empty_state.dart';
import 'admin_error.dart';
import 'widgets/admin_widgets.dart';

class AdminBannedWordsScreen extends StatefulWidget {
  const AdminBannedWordsScreen({super.key});

  @override
  State<AdminBannedWordsScreen> createState() => _AdminBannedWordsScreenState();
}

class _AdminBannedWordsScreenState extends State<AdminBannedWordsScreen> {
  final _search = TextEditingController();
  final _newWord = TextEditingController();
  List<AdminBannedWord> _words = [];
  bool _loading = true;
  bool _adding = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _newWord.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _words.isEmpty;
      _error = null;
    });
    try {
      final words = await AdminService.fetchBannedWords();
      if (!mounted) return;
      setState(() {
        _words = words;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (handleAdminError(context, e, toast: false)) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final word = _newWord.text.trim();
    if (word.isEmpty || _adding) return;
    setState(() => _adding = true);
    try {
      final created = await AdminService.addBannedWord(word);
      if (!mounted) return;
      _newWord.clear();
      showAdminMessage(created ? '已新增' : '詞庫已有這個詞');
      await _load();
    } catch (e) {
      if (mounted) handleAdminError(context, e);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _delete(AdminBannedWord word) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '移除這個詞？',
      message: '「${word.word}」移除後就不會再被過濾。',
      confirmText: '移除',
    );
    if (!confirmed || !mounted) return;
    try {
      await AdminService.deleteBannedWord(word.id);
      showAdminMessage('已移除');
      await _load();
    } catch (e) {
      if (mounted) handleAdminError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '髒話詞庫',
    body: (context, senior) {
      if (_loading) return const TrukuLoadingView();
      if (_error != null) {
        return TrukuErrorView(
          error: _error,
          onRetry: _load,
          seniorMode: senior,
        );
      }
      final keyword = _search.text.trim().toLowerCase();
      final shown = [
        for (final w in _words)
          if (keyword.isEmpty || w.word.toLowerCase().contains(keyword)) w,
      ];
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _newWord,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    labelText: '新增詞',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: '新增',
                      icon: const Icon(Icons.add),
                      onPressed: _adding ? null : _add,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: '搜尋詞庫',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? TrukuEmptyState(
                    icon: Icons.search_off,
                    message: keyword.isEmpty ? '詞庫是空的' : '找不到符合的詞',
                    subtitle: '',
                    seniorMode: senior,
                  )
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(
                        shown[i].word,
                        style: AppTypography.bodyLargeStyle(
                          seniorMode: senior,
                          color: AppColors.ink,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: '移除',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(shown[i]),
                      ),
                    ),
                  ),
          ),
        ],
      );
    },
  );
}
