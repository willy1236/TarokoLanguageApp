// 後台表單共用的分類欄位：下拉列出後台分類清單，最後一項「＋新增分類」切成文字輸入。
// 文章表單、影片資訊欄位共用，兩邊的「新增分類」規則一致。
//
// 清單讀 `GET /api/admin/categories/{module}`（內部管理.md §6.1）。輸入的新分類由後端在
// 送出的同一個交易內加進分類表；送出成功後要不要刷新 [CategoryService] 由呼叫端依
// [AdminCategoryController.isNew] 決定，元件不自己判斷。

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../models/content_category.dart';
import '../../../services/admin_service.dart';
import '../../../services/category_service.dart';
import '../../../shared/utils/utf16_length_limit.dart';
import '../admin_error.dart';

/// 分類欄位的狀態與取值。由呼叫端建立、dispose；同一個 controller 只接一個 [AdminCategoryField]。
class AdminCategoryController extends ChangeNotifier {
  final _newCategory = TextEditingController();

  /// 下拉選中的既有分類 value。
  String? _selected;

  /// 後台分類清單；null 代表還沒載入成功（載入中或失敗）。
  List<ContentCategory>? _categories;
  Object? _error;

  /// 選了「＋新增分類」，分類改由 [_newCategory] 輸入。
  bool _typingNew = false;

  /// 呼叫過 [validate] 後才顯示「必填」，避免一進來就滿版紅字。
  bool _submitted = false;

  bool _initialized = false;

  /// 分類清單已載入成功。
  bool get isLoaded => _categories != null;

  /// 實際要送出的分類 value：下拉選的值，或輸入的新名稱；未選為 null。
  /// 輸入的新分類與既有分類的 value 或名稱相同時，用那一筆的 value。
  String? get value {
    if (!_typingNew) return _selected;
    final typed = _newCategory.text.trim();
    if (typed.isEmpty) return null;
    for (final c in _categories ?? const <ContentCategory>[]) {
      if (c.value == typed || c.label == typed) return c.value;
    }
    return typed;
  }

  /// 送出的分類不在後台清單裡（後端會自動加進分類表）。
  bool get isNew {
    final v = value;
    final list = _categories ?? const <ContentCategory>[];
    return v != null && !list.any((c) => c.value == v);
  }

  /// 標記為已送出（之後欄位會顯示「必填」錯誤），回傳錯誤文字；沒問題回 null。
  /// 清單還沒載入成功時回「載入中／載入失敗」的提示，呼叫端可用 [isLoaded] 區分。
  String? validate() {
    _submitted = true;
    notifyListeners();
    if (_categories == null) {
      return _error == null ? '分類清單載入中，請稍候' : '分類清單載入失敗，請先重試';
    }
    return _typingNew ? _newCategoryError : _selectError;
  }

  String? get _newCategoryError {
    if (!_typingNew) return null;
    final typed = _newCategory.text.trim();
    if (typed.length > categoryLabelMax) {
      return '分類名稱最多 $categoryLabelMax 字';
    }
    return _submitted && typed.isEmpty ? '分類名稱必填' : null;
  }

  String? get _selectError =>
      _submitted && !_typingNew && _selected == null ? '分類必填' : null;

  void _init(String? initial) {
    if (_initialized) return;
    _initialized = true;
    _selected = initial;
  }

  void _setLoading() {
    _error = null;
    notifyListeners();
  }

  void _setLoaded(List<ContentCategory> list, {required bool selectFirst}) {
    _categories = list;
    if (selectFirst && _selected == null && list.isNotEmpty) {
      _selected = list.first.value;
    }
    // 一個分類都沒有時只能輸入新分類。
    if (list.isEmpty && _selected == null) _typingNew = true;
    notifyListeners();
  }

  void _setError(Object e) {
    _error = e;
    notifyListeners();
  }

  void _choose(String option) {
    _typingNew = option == AdminCategoryField._newCategoryOption;
    if (!_typingNew) _selected = option;
    notifyListeners();
  }

  @override
  void dispose() {
    _newCategory.dispose();
    super.dispose();
  }
}

class AdminCategoryField extends StatefulWidget {
  /// 下拉選單裡「＋新增分類」的值，含控制字元，不會和後端的分類 value 撞名。
  static const _newCategoryOption = '\u0000new';

  final CategoryModule module;

  /// 編輯模式的原分類；不在清單裡也照樣選中並顯示名稱。
  final String? initial;
  final AdminCategoryController controller;

  /// 清單載入後、沒有 [initial] 時預設選第一筆。false 時要管理員自己選。
  final bool selectFirst;
  final bool seniorMode;

  const AdminCategoryField({
    super.key,
    required this.module,
    this.initial,
    required this.controller,
    this.selectFirst = true,
    this.seniorMode = false,
  });

  @override
  State<AdminCategoryField> createState() => _AdminCategoryFieldState();
}

class _AdminCategoryFieldState extends State<AdminCategoryField> {
  AdminCategoryController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c._init(widget.initial);
    // ListView 捲出畫面或切預覽再回來會重建元件，清單已在 controller 裡就不重打。
    if (!_c.isLoaded) _load();
  }

  Future<void> _load() async {
    _c._setLoading();
    try {
      final list = await AdminService.fetchCategories(widget.module);
      if (!mounted) return;
      _c._setLoaded(list, selectFirst: widget.selectFirst);
    } catch (e) {
      if (!mounted) return;
      if (handleAdminError(context, e, toast: false)) return;
      _c._setError(e);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _c,
    builder: (context, _) {
      final categories = _c._categories;
      if (categories == null) return _status();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _fields(categories),
      );
    },
  );

  List<Widget> _fields(List<ContentCategory> categories) {
    final original = widget.initial;
    final originalMissing =
        original != null && !categories.any((c) => c.value == original);
    return [
      DropdownButtonFormField<String>(
        initialValue: _c._typingNew
            ? AdminCategoryField._newCategoryOption
            : _c._selected,
        decoration: InputDecoration(
          labelText: '分類（必填）',
          errorText: _c._selectError,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final c in categories)
            DropdownMenuItem(value: c.value, child: Text(c.label)),
          // 編輯時原分類不在清單裡也照樣選中，不默默換掉。
          if (originalMissing)
            DropdownMenuItem(
              value: original,
              child: Text(CategoryService.labelOf(widget.module, original)),
            ),
          const DropdownMenuItem(
            value: AdminCategoryField._newCategoryOption,
            child: Text('＋新增分類'),
          ),
        ],
        onChanged: (v) {
          if (v != null) _c._choose(v);
        },
      ),
      if (_c._typingNew) ...[
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _c._newCategory,
          autofocus: categories.isNotEmpty,
          inputFormatters: const [
            Utf16LengthLimitingTextInputFormatter(categoryLabelMax),
          ],
          buildCounter: utf16CounterBuilder(_c._newCategory, categoryLabelMax),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: '新分類名稱',
            helperText: '送出後會加進分類清單',
            errorText: _c._newCategoryError,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    ];
  }

  /// 分類清單還沒拿到：載入中，或失敗＋重試。
  Widget _status() {
    final failed = _c._error != null;
    final senior = widget.seniorMode;
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
                onPressed: _load,
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
