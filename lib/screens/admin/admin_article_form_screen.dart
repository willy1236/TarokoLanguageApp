// 文章表單：管理員在 App 內新增文章（存草稿或直接發布），也用來編輯已發布的文章。
//
// 限制（後端現況）：沒有列出草稿／已下架文章的端點，草稿存了之後 App 內找不回來；
// 封面只收已在雲端儲存的 HTTPS 網址，沒有上傳；文章詳情不回作者與部落標籤，
// 編輯模式因此不顯示這兩欄（建立時才能填）。
//
// 分類清單讀 `GET /api/admin/categories/articles`（內部管理.md §6.1），也可以直接輸入
// 新分類，後端會在同一個交易內加進分類表。清單載入成功前不能送出。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../models/article_models.dart';
import '../../models/content_category.dart';
import '../../models/tribe_model.dart';
import '../../services/admin_service.dart';
import '../../services/article_refresh_notifier.dart';
import '../../services/category_service.dart';
import '../../services/user_service.dart';
import '../../shared/utils/utf16_length_limit.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../culture/widgets/article_markdown.dart';
import 'admin_categories_screen.dart' show adminCategoryLabelMax;
import 'admin_error.dart';
import 'widgets/admin_widgets.dart';

class AdminArticleFormScreen extends StatefulWidget {
  /// 不為 null 代表編輯這篇已發布的文章（帶入原值、儲存時只送有改的欄位）。
  final ArticleDetail? editing;

  const AdminArticleFormScreen({super.key, this.editing});

  @override
  State<AdminArticleFormScreen> createState() => _AdminArticleFormScreenState();
}

class _AdminArticleFormScreenState extends State<AdminArticleFormScreen> {
  /// 下拉選單裡「＋新增分類」的值，含控制字元，不會和後端的分類 value 撞名。
  static const _newCategoryOption = '\u0000new';

  late final _title = TextEditingController(text: widget.editing?.title);
  late final _summary = TextEditingController(text: widget.editing?.summary);
  late final _content = TextEditingController(text: widget.editing?.contentMd);
  late final _cover = TextEditingController(
    text: widget.editing?.coverImageUrl,
  );
  final _author = TextEditingController();
  final _newCategory = TextEditingController();

  /// 下拉選中的既有分類 value；新增時等清單載入後預設第一筆。
  late String? _category = widget.editing?.category;

  /// 後台分類清單；null 代表還沒載入成功（載入中或失敗），這時不能送出。
  List<ContentCategory>? _categories;
  Object? _categoriesError;

  /// 選了「＋新增分類」，分類改由 [_newCategory] 輸入。
  bool _typingNewCategory = false;

  int? _tribeId;
  List<Tribe> _tribes = const [];
  bool _preview = false;
  bool _busy = false;

  /// 按過送出後才顯示欄位錯誤，避免一進來就滿版紅字。
  bool _submitted = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (!_isEdit) _loadTribes();
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _summary,
      _content,
      _cover,
      _author,
      _newCategory,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 部落標籤選項；拿不到就不顯示這一欄，不擋整個表單。
  Future<void> _loadTribes() async {
    try {
      final tribes = await UserService.fetchTribes();
      if (mounted) setState(() => _tribes = tribes);
    } catch (e) {
      debugPrint('AdminArticleFormScreen: 部落清單載入失敗：$e');
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesError = null);
    try {
      final list = await AdminService.fetchCategories(CategoryModule.articles);
      if (!mounted) return;
      setState(() {
        _categories = list;
        if (_category == null && list.isNotEmpty) _category = list.first.value;
        // 一個分類都沒有時只能輸入新分類。
        if (list.isEmpty && _category == null) _typingNewCategory = true;
      });
    } catch (e) {
      if (!mounted) return;
      if (handleAdminError(context, e, toast: false)) return;
      setState(() => _categoriesError = e);
    }
  }

  /// 實際要送出的分類 value。輸入的新分類與既有分類的 value 或名稱相同時，用那一筆的 value。
  String? get _selectedCategory {
    if (!_typingNewCategory) return _category;
    final typed = _newCategory.text.trim();
    if (typed.isEmpty) return null;
    for (final c in _categories ?? const <ContentCategory>[]) {
      if (c.value == typed || c.label == typed) return c.value;
    }
    return typed;
  }

  /// 送出的分類不在後台清單裡（後端會自動加進分類表）。
  bool get _isNewCategory {
    final value = _selectedCategory;
    final list = _categories ?? const <ContentCategory>[];
    return value != null && !list.any((c) => c.value == value);
  }

  String? get _newCategoryError {
    if (!_typingNewCategory) return null;
    final typed = _newCategory.text.trim();
    if (typed.length > adminCategoryLabelMax) {
      return '分類名稱最多 $adminCategoryLabelMax 字';
    }
    return _submitted && typed.isEmpty ? '分類名稱必填' : null;
  }

  String? get _titleError =>
      _submitted && _title.text.trim().isEmpty ? '標題必填' : null;
  String? get _contentError =>
      _submitted && _content.text.trim().isEmpty ? '內文必填' : null;
  String? get _coverError {
    final v = _cover.text.trim();
    if (v.isEmpty || v.startsWith('https://')) return null;
    return '封面網址必須以 https:// 開頭';
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty &&
      _content.text.trim().isNotEmpty &&
      _coverError == null &&
      _selectedCategory != null &&
      _newCategoryError == null;

  Future<void> _save({required bool publish}) async {
    setState(() => _submitted = true);
    if (_categories == null) {
      showAdminMessage(
        _categoriesError == null ? '分類清單載入中，請稍候' : '分類清單載入失敗，請先重試',
      );
      return;
    }
    if (!_valid) return;
    if (_isEdit) return _saveEdit();
    if (!publish) {
      final ok = await showConfirmDialog(
        context,
        title: '存成草稿？',
        message: '草稿目前無法在 App 內找回（後端沒有列出草稿的功能）。確定要存成草稿？',
        confirmText: '存草稿',
      );
      if (!ok || !mounted) return;
    }
    final isNewCategory = _isNewCategory;
    setState(() => _busy = true);
    try {
      await AdminService.createArticle(
        title: _title.text,
        category: _selectedCategory!,
        contentMd: _content.text,
        summary: _summary.text,
        coverImageUrl: _cover.text,
        author: _author.text,
        tribeId: _tribeId,
        publish: publish,
      );
      // 文化頁活在 IndexedStack 內不會自己重抓，發布的文章要通知它刷新。
      if (publish) ArticleRefreshNotifier.bump();
      if (isNewCategory) _refreshAppCategories();
      showAdminMessage(publish ? '已發布' : '草稿已儲存');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      handleAdminError(context, e);
    }
  }

  /// 編輯只送有改的欄位；摘要、封面清空時送 null 讓後端清掉。
  Future<void> _saveEdit() async {
    final original = widget.editing!;
    final category = _selectedCategory!;
    String? nullIfBlank(String v) => v.trim().isEmpty ? null : v.trim();
    final fields = <String, Object?>{
      if (_title.text.trim() != original.title) 'title': _title.text.trim(),
      if (category != original.category) 'category': category,
      if (_content.text != original.contentMd) 'content_md': _content.text,
      if (nullIfBlank(_summary.text) != original.summary)
        'summary': nullIfBlank(_summary.text),
      if (nullIfBlank(_cover.text) != original.coverImageUrl)
        'cover_image_url': nullIfBlank(_cover.text),
    };
    if (fields.isEmpty) {
      showAdminMessage('沒有變更');
      return;
    }
    final isNewCategory = _isNewCategory;
    setState(() => _busy = true);
    try {
      await AdminService.updateArticle(original.id, fields);
      if (isNewCategory) _refreshAppCategories();
      showAdminMessage('已儲存');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      handleAdminError(context, e);
    }
  }

  /// 後端已把新分類加進分類表：刷新前台快取，讓文化頁拿得到它的名稱。失敗不影響送出結果。
  void _refreshAppCategories() {
    CategoryService.fetch(CategoryModule.articles, refresh: true).then<void>(
      (_) {},
      onError: (Object e) =>
          debugPrint('AdminArticleFormScreen: 前台分類快取刷新失敗：$e'),
    );
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: _isEdit ? '編輯文章' : '新增文章',
    actions: [
      IconButton(
        tooltip: _preview ? '回到編輯' : '預覽',
        icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility_outlined),
        onPressed: () => setState(() => _preview = !_preview),
      ),
    ],
    body: (context, senior) => _preview ? _previewView(senior) : _form(senior),
    bottom: (context, senior) => AdminActionBar(
      children: _isEdit
          ? [
              FilledButton(
                onPressed: _busy ? null : () => _save(publish: true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.creamLight,
                ),
                child: const Text('儲存'),
              ),
            ]
          : [
              OutlinedButton(
                onPressed: _busy ? null : () => _save(publish: false),
                child: const Text('存草稿'),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _save(publish: true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.creamLight,
                ),
                child: const Text('發布'),
              ),
            ],
    ),
  );

  /// 預覽：深色底、和文章詳情頁同樣的 Markdown 樣式。
  Widget _previewView(bool senior) => Container(
    color: AppColors.midnight,
    width: double.infinity,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title.text.trim().isEmpty ? '（尚未填標題）' : _title.text.trim(),
            style: AppTypography.headlineStyle(
              seniorMode: senior,
              color: AppColors.creamLight,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ArticleMarkdown(data: _content.text, seniorMode: senior),
        ],
      ),
    ),
  );

  Widget _form(bool senior) => ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      TextField(
        controller: _title,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: '標題（必填）',
          errorText: _titleError,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      ..._categoryFields(senior),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _summary,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: '摘要',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _content,
        minLines: 10,
        maxLines: null,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: '內文（Markdown，必填）',
          alignLabelWithHint: true,
          errorText: _contentError,
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _cover,
        keyboardType: TextInputType.url,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: '封面圖網址',
          helperText: '需先上傳到雲端儲存',
          errorText: _coverError,
          border: const OutlineInputBorder(),
        ),
      ),
      if (!_isEdit) ...[
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _author,
          inputFormatters: const [Utf16LengthLimitingTextInputFormatter(100)],
          decoration: const InputDecoration(
            labelText: '作者',
            border: OutlineInputBorder(),
          ),
        ),
        if (_tribes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int?>(
            initialValue: _tribeId,
            decoration: const InputDecoration(
              labelText: '部落標籤',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('不標')),
              for (final t in _tribes)
                DropdownMenuItem<int?>(value: t.id, child: Text(t.name)),
            ],
            onChanged: (v) => setState(() => _tribeId = v),
          ),
        ],
      ],
    ],
  );

  /// 分類：下拉列出後台清單，最後一項「＋新增分類」切成文字輸入。
  List<Widget> _categoryFields(bool senior) {
    final categories = _categories;
    if (categories == null) return [_categoryStatus(senior)];
    final original = widget.editing?.category;
    final originalMissing =
        original != null && !categories.any((c) => c.value == original);
    return [
      DropdownButtonFormField<String>(
        initialValue: _typingNewCategory ? _newCategoryOption : _category,
        decoration: const InputDecoration(
          labelText: '分類（必填）',
          border: OutlineInputBorder(),
        ),
        items: [
          for (final c in categories)
            DropdownMenuItem(value: c.value, child: Text(c.label)),
          // 編輯時原分類不在清單裡也照樣選中，不默默換掉。
          if (originalMissing)
            DropdownMenuItem(
              value: original,
              child: Text(
                CategoryService.labelOf(CategoryModule.articles, original),
              ),
            ),
          const DropdownMenuItem(
            value: _newCategoryOption,
            child: Text('＋新增分類'),
          ),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _typingNewCategory = v == _newCategoryOption;
            if (!_typingNewCategory) _category = v;
          });
        },
      ),
      if (_typingNewCategory) ...[
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _newCategory,
          autofocus: categories.isNotEmpty,
          inputFormatters: const [
            Utf16LengthLimitingTextInputFormatter(adminCategoryLabelMax),
          ],
          buildCounter: utf16CounterBuilder(
            _newCategory,
            adminCategoryLabelMax,
          ),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: '新分類名稱',
            helperText: '送出後會加進分類清單',
            errorText: _newCategoryError,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    ];
  }

  /// 分類清單還沒拿到：載入中，或失敗＋重試。
  Widget _categoryStatus(bool senior) {
    final failed = _categoriesError != null;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: '分類（必填）',
        errorText: failed ? '分類載入失敗' : null,
        border: const OutlineInputBorder(),
      ),
      child: failed
          ? Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _loadCategories,
                child: Text(
                  '重試',
                  style: AppTypography.bodyLargeStyle(
                    seniorMode: senior,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          : Text(
              '分類載入中…',
              style: AppTypography.bodyStyle(
                seniorMode: senior,
                color: AppColors.fog,
              ),
            ),
    );
  }
}
