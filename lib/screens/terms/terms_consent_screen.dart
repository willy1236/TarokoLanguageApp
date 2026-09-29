// 同意條款（服務條款/隱私權政策）畫面。
//
// 兩種用途：
// - 強制同意（readOnly=false，預設）：登入/啟動時偵測到未同意最新版，或
//   ApiClient 攔截到 CONSENT_REQUIRED 時導來這裡，不可滑退，同意後才能繼續。
// - 唯讀檢視（readOnly=true）：profile_screen 的「服務條款與隱私權政策」項目
//   點進來，單純查看目前條款內容，不強制同意、可正常返回。
//
// 讀取都走單份端點 GET /api/terms/:doc_type（tos、privacy 並行抓；尚未發布的
// 404 TERMS_NOT_FOUND 略過）。
// - 唯讀：兩份以 TabBar 在同一頁分頁顯示。
// - 強制同意：只留尚未同意最新版的文件，一次顯示一份（第 N 份／共 M 份），
//   捲到底解鎖「同意《…》」，按下即送 POST /api/terms/:doc_type/consent，成功才進下一份。

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/terms_models.dart';
import '../../services/fcm_service.dart';
import '../../services/terms_service.dart';
import '../../services/user_service.dart';
import '../../core/constants/app_typography.dart';
import '../../shared/widgets/app_back_button.dart';

class TermsConsentScreen extends StatefulWidget {
  final bool readOnly;

  const TermsConsentScreen({super.key, this.readOnly = false});

  @override
  State<TermsConsentScreen> createState() => _TermsConsentScreenState();
}

class _TermsConsentScreenState extends State<TermsConsentScreen> {
  static const _docTypes = ['tos', 'privacy'];

  /// 唯讀模式為全部已發布文件；強制模式只含尚未同意最新版的文件。
  List<TermsDocument> _documents = const [];

  /// 強制模式目前在第幾份（從 0 起算）。
  int _step = 0;

  String? _error;
  bool _loading = true;
  bool _submitting = false;

  /// 已捲到底、可以同意的 doc_type。
  final Set<String> _readToEnd = {};

  /// 捲動到距底部這個距離內就算讀完，避免差幾 px 卡住。
  static const double _endThreshold = 24;

  bool _onScroll(TermsDocument doc, ScrollMetrics metrics) {
    if (!_readToEnd.contains(doc.docType) &&
        metrics.extentAfter <= _endThreshold) {
      setState(() => _readToEnd.add(doc.docType));
    }
    return false;
  }

  /// 包住單份文件的捲動區，偵測是否已捲到底；內容不足一頁時首次排版就算讀完。
  Widget _trackScroll(TermsDocument doc, Widget child) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onScroll(doc, n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onScroll(doc, n.metrics),
        child: child,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<TermsDocumentStatus?> _fetchDocument(String docType) async {
    try {
      return await TermsService.fetchDocument(docType);
    } on ApiException catch (e) {
      if (e.isTermsNotFound) return null;
      rethrow;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait(_docTypes.map(_fetchDocument));
      final fetched = [
        for (final r in results)
          if (r != null) r.document,
      ];
      final pending = widget.readOnly
          ? fetched
          : fetched.where((d) => !d.consented).toList();
      // 全都已同意（例如中途離開再回來）就不必停在這個畫面。
      if (!widget.readOnly && fetched.isNotEmpty && pending.isEmpty) {
        await _finish();
        return;
      }
      if (!mounted) return;
      setState(() {
        _documents = pending;
        _readToEnd.clear();
        _step = 0;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '載入失敗，請稍後再試';
        _loading = false;
      });
    }
  }

  Future<void> _agree() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await TermsService.consentDocument(_documents[_step]);
      if (_step < _documents.length - 1) {
        if (!mounted) return;
        setState(() => _step++);
      } else if (result.allConsented) {
        await _finish();
      } else {
        // 送出期間另一份又出了新版，重新載入剩下要同意的。
        if (!mounted) return;
        await _load();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isTermsVersionOutdated) {
        _reloadOutdated(e);
      } else if (e.isVersionRequired) {
        _showError('請更新 App 到最新版');
      } else {
        _showError(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('送出失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 全部同意完成：進首頁；新帳號會先被擋在同意條款，同意後要接續完善資料，
  /// 查不到就照舊進首頁。
  Future<void> _finish() async {
    var profileCompleted = true;
    try {
      profileCompleted = (await UserService.fetchMe()).profileCompleted;
    } catch (e) {
      debugPrint('TermsConsentScreen: fetchMe 失敗，略過完善資料檢查：$e');
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      profileCompleted ? '/home' : '/complete-profile',
      (route) => false,
    );
    // 冷啟動被條款擋下時，splash 沒處理通知深連結，同意進首頁後補上。
    if (profileCompleted) FcmService.consumePendingInitialMessage();
  }

  /// 閱讀期間後台發布了新版：目前這份換成回應附的最新條款，需重新捲到底才能同意。
  void _reloadOutdated(ApiException e) {
    final body = e.body;
    if (body == null || body['documents'] is! List) {
      _showError(e.message);
      _load();
      return;
    }
    final current = _documents[_step];
    final latest = TermsStatus.fromJson(
      body,
    ).documents.where((d) => d.docType == current.docType).firstOrNull;
    if (latest == null || latest.consented) {
      _showError(e.message);
      _load();
      return;
    }
    setState(() {
      _documents = [..._documents]..[_step] = latest;
      _readToEnd.remove(current.docType);
    });
    _showError(e.message);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.readOnly;
    return PopScope(
      canPop: readOnly,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          elevation: 0,
          foregroundColor: AppColors.ink,
          automaticallyImplyLeading: false,
          leading: readOnly ? const AppBackButton() : null,
          title: Text(
            '服務條款與隱私權政策',
            style: AppTypography.titleStyle(color: AppColors.ink),
          ),
        ),
        body: SafeArea(child: _buildBody(readOnly)),
      ),
    );
  }

  Widget _buildBody(bool readOnly) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('重試')),
            ],
          ),
        ),
      );
    }
    if (_documents.isEmpty) {
      return Center(
        child: Text(
          '目前沒有條款內容',
          style: TextStyle(fontSize: AppTypography.body, color: AppColors.fog),
        ),
      );
    }
    if (!readOnly) return _buildStep();
    final documents = _documents;
    if (documents.length == 1) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: _buildDocument(documents.first),
      );
    }
    return DefaultTabController(
      length: documents.length,
      child: Column(
        children: [
          TabBar(
            labelColor: AppColors.ink,
            unselectedLabelColor: AppColors.fog,
            indicatorColor: AppColors.gold,
            labelStyle: AppTypography.serif(
              fontSize: AppTypography.body,
              fontWeight: FontWeight.w600,
            ),
            tabs: documents.map((doc) => Tab(text: doc.title)).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: documents
                  .map(
                    (doc) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: _buildDocument(doc, showTitle: false),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 強制同意：一次一份，上方顯示進度，底部按鈕捲到底才解鎖。
  Widget _buildStep() {
    final doc = _documents[_step];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '第 ${_step + 1} 份／共 ${_documents.length} 份',
              style: AppTypography.captionStyle(color: AppColors.fog),
            ),
          ),
        ),
        Expanded(
          child: _trackScroll(
            doc,
            SingleChildScrollView(
              key: ValueKey('${doc.docType}_${doc.version}'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: _buildDocument(doc),
            ),
          ),
        ),
        _buildAgreeBar(doc),
      ],
    );
  }

  /// doc.title 已在 Tab 標籤或上方顯示過一次，若 contentMd 開頭是重複的同名
  /// 標題行則去掉，避免畫面看到兩次「織語者 服務條款」。
  String _stripLeadingTitle(String contentMd, String title) {
    final lines = contentMd.split('\n');
    if (lines.isEmpty) return contentMd;
    final firstLine = lines.first.replaceFirst(RegExp(r'^#+\s*'), '').trim();
    if (firstLine != title.trim()) return contentMd;
    return lines.skip(1).join('\n').trimLeft();
  }

  Widget _buildDocument(TermsDocument doc, {bool showTitle = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            doc.title,
            style: AppTypography.serif(
              fontSize: AppTypography.subtitle,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          '第 ${doc.version} 版',
          style: TextStyle(
            fontSize: AppTypography.caption,
            color: AppColors.fog,
          ),
        ),
        const SizedBox(height: 12),
        MarkdownBody(
          data: _stripLeadingTitle(doc.contentMd, doc.title),
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              fontSize: AppTypography.body,
              height: 1.6,
              color: AppColors.ink.withValues(alpha: 0.85),
            ),
            h1: AppTypography.serif(
              fontSize: AppTypography.subtitle,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
            h1Padding: const EdgeInsets.only(top: 16, bottom: 4),
            h2: AppTypography.titleStyle(color: AppColors.ink),
            h2Padding: const EdgeInsets.only(top: 16, bottom: 4),
            h3: AppTypography.titleStyle(color: AppColors.ink),
            strong: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
            // 預設 blockquote 底色跟著 dark theme 變深，粗體的 ink 字會看不到。
            blockquote: TextStyle(
              fontSize: AppTypography.body,
              height: 1.6,
              color: AppColors.ink.withValues(alpha: 0.85),
            ),
            blockquotePadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            blockquoteDecoration: BoxDecoration(
              color: AppColors.creamDeep,
              border: const Border(
                left: BorderSide(color: AppColors.gold, width: 4),
              ),
            ),
            listBullet: TextStyle(
              fontSize: AppTypography.body,
              color: AppColors.ink.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgreeBar(TermsDocument doc) {
    final unlocked = _readToEnd.contains(doc.docType);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.cream,
        border: Border(top: BorderSide(color: AppColors.creamDeep)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!unlocked) ...[
              Text(
                '請先閱讀至《${doc.title}》最下方',
                textAlign: TextAlign.center,
                style: AppTypography.captionStyle(color: AppColors.fog),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_submitting || !unlocked) ? null : _agree,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: AppColors.creamDeep,
                  disabledForegroundColor: AppColors.fog,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        '同意《${doc.title}》',
                        style: AppTypography.titleStyle(
                          color: unlocked ? AppColors.ink : AppColors.fog,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
