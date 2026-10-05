// 發布新版條款：選服務條款或隱私權政策、貼上標題與全文、預覽、發布。
// 版本號由後端自動遞增；發布後所有使用者下次使用都要重新同意，所以發布前一定二次確認。

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/network/api_client.dart';
import '../../services/admin_service.dart';
import '../../services/terms_service.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../terms/widgets/terms_document_view.dart';
import 'admin_error.dart';
import 'widgets/admin_widgets.dart';

const _docLabels = {'tos': '服務條款', 'privacy': '隱私權政策'};

class AdminTermsPublishScreen extends StatefulWidget {
  const AdminTermsPublishScreen({super.key});

  @override
  State<AdminTermsPublishScreen> createState() =>
      _AdminTermsPublishScreenState();
}

class _AdminTermsPublishScreenState extends State<AdminTermsPublishScreen> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  String _docType = 'tos';

  /// 目前線上的版本號；該類型還沒發布過時為 0，預覽會顯示「第 1 版」。
  int _currentVersion = 0;
  bool _loadingCurrent = true;

  /// 讀取目前版本失敗（不是「尚未發布」的 404）：版本號不明，確認框不寫推算的版本號，
  /// 並提供重試。
  Object? _versionError;
  bool _preview = false;
  bool _busy = false;
  bool _submitted = false;

  /// 切換類型時晚回來的舊回應直接丟掉。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  /// 標題帶入目前線上版本的標題；查不到就留空讓管理員自己填。
  /// 404 TERMS_NOT_FOUND＝還沒發布過，版本視為 0；其他錯誤記到 [_versionError]，
  /// 不擋發布（版本號由後端遞增），但確認框不寫推算的版本號。
  /// [keepTitle] 為 true 時不覆寫管理員已填的標題（重試用）。
  Future<void> _loadCurrent({bool keepTitle = false}) async {
    final generation = ++_generation;
    setState(() {
      _loadingCurrent = true;
      _versionError = null;
    });
    var title = '';
    var version = 0;
    Object? error;
    try {
      final doc = (await TermsService.fetchDocument(_docType)).document;
      title = doc.title;
      version = doc.version;
    } catch (e) {
      if (!(e is ApiException && e.isTermsNotFound)) {
        debugPrint('AdminTermsPublishScreen: 讀取目前條款失敗：$e');
        error = e;
      }
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      if (!keepTitle || _title.text.trim().isEmpty) _title.text = title;
      _currentVersion = version;
      _versionError = error;
      _loadingCurrent = false;
    });
  }

  void _selectDocType(String docType) {
    if (docType == _docType) return;
    setState(() => _docType = docType);
    _loadCurrent();
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty && _content.text.trim().isNotEmpty;

  Future<void> _publish() async {
    setState(() => _submitted = true);
    if (!_valid) return;
    final label = _docLabels[_docType]!;
    final confirmed = await showConfirmDialog(
      context,
      title: '發布新版$label？',
      message:
          '發布後所有使用者下次使用都要重新同意這份$label。\n\n'
          '${_versionError == null ? '版本號會自動遞增為第 ${_currentVersion + 1} 版' : '版本號會自動遞增'}，發布後無法收回。',
      confirmText: '發布',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final version = await AdminService.publishTerms(
        _docType,
        _title.text,
        _content.text,
      );
      if (!mounted) return;
      await showAdminInfoDialog(
        context,
        title: '已發布',
        message: '$label新版本號：第 $version 版。',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      handleAdminError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => AdminScaffold(
    title: '發布條款',
    actions: [
      IconButton(
        tooltip: _preview ? '回到編輯' : '預覽',
        icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility_outlined),
        onPressed: () => setState(() => _preview = !_preview),
      ),
    ],
    body: (context, senior) => _preview ? _previewView() : _form(),
    bottom: (context, senior) => AdminActionBar(
      children: [
        FilledButton(
          onPressed: _busy || _loadingCurrent ? null : _publish,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.creamLight,
          ),
          child: const Text('發布'),
        ),
      ],
    ),
  );

  /// 預覽用使用者看到的條款頁樣式（淺色底）。
  Widget _previewView() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
    child: TermsDocumentView(
      title: _title.text.trim(),
      // 讀取中或讀不到目前版本時不寫推算的版本號，和確認框一致。
      version: _versionError == null && !_loadingCurrent
          ? _currentVersion + 1
          : null,
      contentMd: _content.text,
    ),
  );

  Widget _form() => ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      SegmentedButton<String>(
        segments: [
          for (final e in _docLabels.entries)
            ButtonSegment(value: e.key, label: Text(e.value)),
        ],
        selected: {_docType},
        onSelectionChanged: (s) => _selectDocType(s.first),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _title,
        // 讀取中不可輸入：回應回來會覆寫標題，先打的字會被吃掉。
        enabled: !_loadingCurrent,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: '標題',
          helperText: _loadingCurrent ? '讀取目前版本…' : null,
          errorText: _submitted && _title.text.trim().isEmpty ? '標題必填' : null,
          border: const OutlineInputBorder(),
        ),
      ),
      if (_versionError != null) _versionErrorRow(),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _content,
        minLines: 12,
        maxLines: null,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: '全文（Markdown，貼上）',
          alignLabelWithHint: true,
          errorText: _submitted && _content.text.trim().isEmpty ? '全文必填' : null,
          border: const OutlineInputBorder(),
        ),
      ),
    ],
  );

  Widget _versionErrorRow() => Row(
    children: [
      Expanded(
        child: Text(
          '讀取目前版本失敗，發布後的版本號以系統為準',
          style: AppTypography.captionStyle(color: AppColors.danger),
        ),
      ),
      TextButton(
        onPressed: () => _loadCurrent(keepTitle: true),
        child: const Text('重試'),
      ),
    ],
  );
}
