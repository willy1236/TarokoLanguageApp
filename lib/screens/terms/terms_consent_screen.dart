// 同意條款（服務條款/隱私權政策）畫面。
//
// 兩種用途：
// - 強制同意（readOnly=false，預設）：登入/啟動時偵測到未同意最新版，或
//   ApiClient 攔截到 CONSENT_REQUIRED 時導來這裡，不可滑退，同意後才能繼續。
// - 唯讀檢視（readOnly=true）：profile_screen 的「隱私權政策」項目點進來，
//   單純查看目前條款內容，不強制同意、可正常返回。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/terms_models.dart';
import '../../services/terms_service.dart';

class TermsConsentScreen extends StatefulWidget {
  final bool readOnly;

  const TermsConsentScreen({super.key, this.readOnly = false});

  @override
  State<TermsConsentScreen> createState() => _TermsConsentScreenState();
}

class _TermsConsentScreenState extends State<TermsConsentScreen> {
  TermsStatus? _status;
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await TermsService.fetchStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
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
      await TermsService.consent();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/home', (route) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('送出失敗，請稍後再試');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
          automaticallyImplyLeading: readOnly,
          title: Text(
            '服務條款與隱私權政策',
            style: GoogleFonts.notoSerifTc(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
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
    final documents = _status?.documents ?? [];
    if (documents.isEmpty) {
      return Center(
        child: Text(
          '目前沒有條款內容',
          style: TextStyle(fontSize: 14, color: AppColors.fog),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            itemCount: documents.length,
            separatorBuilder: (_, _) => const SizedBox(height: 24),
            itemBuilder: (context, i) => _buildDocument(documents[i]),
          ),
        ),
        if (!readOnly) _buildAgreeBar(),
      ],
    );
  }

  Widget _buildDocument(TermsDocument doc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          doc.title,
          style: GoogleFonts.notoSerifTc(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '第 ${doc.version} 版',
          style: TextStyle(fontSize: 12, color: AppColors.fog),
        ),
        const SizedBox(height: 12),
        Text(
          doc.contentMd,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: AppColors.ink.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  Widget _buildAgreeBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.cream,
        border: Border(top: BorderSide(color: AppColors.creamDeep)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _agree,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '我已閱讀並同意',
                    style: GoogleFonts.notoSerifTc(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
