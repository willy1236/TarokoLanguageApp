// 後台影片的資訊欄位組：標題、說明、分類（含新增）、相關部落。
// YouTube 上架、上傳檔案、編輯影片共用（後台影片 T-03、T-04、T-07）。
//
// 呼叫端只做三件事：建立並 dispose [AdminVideoMetaController]、送出前呼叫
// [AdminVideoMetaController.validate]、通過後讀 [AdminVideoMetaController.value]。
// 送出成功且 [AdminVideoMetaController.isNewCategory] 為 true 時，由呼叫端刷新
// `CategoryService.fetch(CategoryModule.videos, refresh: true)`。

import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../models/admin_video_meta.dart';
import '../../../models/content_category.dart';
import '../../../models/tribe_model.dart';
import '../../../services/user_service.dart';
import '../../../shared/utils/utf16_length_limit.dart';
import '../../../shared/widgets/related_tribe_field.dart';
import 'admin_category_field.dart';

/// 影片資訊欄位的狀態與取值。由呼叫端建立、dispose；同一個 controller 只接一個 [AdminVideoMetaFields]。
class AdminVideoMetaController extends ChangeNotifier {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = AdminCategoryController();
  TribeTag? _tribe;

  /// 由 [AdminVideoMetaFields.titleRequired] 同步進來。
  bool _titleRequired = true;

  /// 呼叫過 [validate] 後才顯示「必填」，避免一進來就滿版紅字。
  bool _submitted = false;
  bool _initialized = false;

  /// 逐欄顯示錯誤，全部通過回 true。
  bool validate() {
    _submitted = true;
    final categoryError = _category.validate();
    notifyListeners();
    return _titleError == null &&
        _descriptionError == null &&
        categoryError == null;
  }

  /// 目前填的值。只能在 [validate] 回 true 之後讀；分類還沒選時丟 [StateError]。
  AdminVideoMeta get value {
    final category = _category.value;
    if (category == null) {
      throw StateError('AdminVideoMetaController.value：分類未選，請先通過 validate()');
    }
    return AdminVideoMeta(
      title: _blankToNull(_title.text),
      description: _blankToNull(_description.text),
      category: category,
      tribeId: _tribe?.id,
    );
  }

  /// 選的分類是新輸入、不在清單裡的（送出成功後呼叫端要刷新影音分類快取）。
  bool get isNewCategory => _category.isNew;

  String? get _titleError {
    final title = _title.text.trim();
    if (title.length > adminVideoTitleMax) {
      return '標題最多 $adminVideoTitleMax 字';
    }
    return _submitted && _titleRequired && title.isEmpty ? '標題必填' : null;
  }

  String? get _descriptionError =>
      _description.text.length > adminVideoDescriptionMax
      ? '說明最多 $adminVideoDescriptionMax 字'
      : null;

  void _init(AdminVideoMeta? initial) {
    if (_initialized) return;
    _initialized = true;
    _title.text = initial?.title ?? '';
    _description.text = initial?.description ?? '';
    final tribeId = initial?.tribeId;
    if (tribeId != null) {
      // 先只有 id，名稱查到再補上（同發起活動頁的編輯模式）。
      _tribe = TribeTag(id: tribeId, name: '');
      _loadTribeName(tribeId);
    }
  }

  Future<void> _loadTribeName(int id) async {
    try {
      final name = await UserService.tribeName(id);
      if (name == null || _tribe?.id != id) return;
      _setTribe(TribeTag(id: id, name: name));
    } catch (e) {
      debugPrint('AdminVideoMetaFields: 部落名稱載入失敗（忽略）：$e');
    }
  }

  bool _disposed = false;

  void _setTribe(TribeTag? tribe) {
    if (_disposed) return;
    _tribe = tribe;
    notifyListeners();
  }

  void _changed() => notifyListeners();

  static String? _blankToNull(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  @override
  void dispose() {
    _disposed = true;
    _title.dispose();
    _description.dispose();
    _category.dispose();
    super.dispose();
  }
}

class AdminVideoMetaFields extends StatefulWidget {
  /// 編輯模式帶入的原值；只在第一次建立時套用。
  final AdminVideoMeta? initial;
  final AdminVideoMetaController controller;

  /// false 時標題可留空（YouTube 可嵌入的影片由後端帶入標題）。可隨時切換。
  final bool titleRequired;
  final bool seniorMode;

  const AdminVideoMetaFields({
    super.key,
    this.initial,
    required this.controller,
    this.titleRequired = true,
    this.seniorMode = false,
  });

  @override
  State<AdminVideoMetaFields> createState() => _AdminVideoMetaFieldsState();
}

class _AdminVideoMetaFieldsState extends State<AdminVideoMetaFields> {
  AdminVideoMetaController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c._init(widget.initial);
    _c._titleRequired = widget.titleRequired;
  }

  @override
  void didUpdateWidget(AdminVideoMetaFields old) {
    super.didUpdateWidget(old);
    // 接著就會 build，不必另外 notify；之後呼叫 validate() 也會用新值。
    _c._titleRequired = widget.titleRequired;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _c,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _c._title,
          inputFormatters: const [
            Utf16LengthLimitingTextInputFormatter(adminVideoTitleMax),
          ],
          buildCounter: utf16CounterBuilder(_c._title, adminVideoTitleMax),
          onChanged: (_) => _c._changed(),
          decoration: InputDecoration(
            labelText: widget.titleRequired ? '標題（必填）' : '標題',
            errorText: _c._titleError,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _c._description,
          minLines: 3,
          maxLines: null,
          buildCounter: utf16CounterBuilder(
            _c._description,
            adminVideoDescriptionMax,
          ),
          onChanged: (_) => _c._changed(),
          decoration: InputDecoration(
            labelText: '說明',
            alignLabelWithHint: true,
            errorText: _c._descriptionError,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AdminCategoryField(
          module: CategoryModule.videos,
          initial: widget.initial?.category,
          controller: _c._category,
          selectFirst: false,
          seniorMode: widget.seniorMode,
        ),
        const SizedBox(height: AppSpacing.md),
        RelatedTribeField(
          tribe: _c._tribe,
          onChanged: _c._setTribe,
          seniorMode: widget.seniorMode,
        ),
      ],
    ),
  );
}
