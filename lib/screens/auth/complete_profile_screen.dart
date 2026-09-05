// 首次登入完善個人資料（issue #43）。
// 登入後端回傳 profile_completed=false 時導向此畫面，填妥必填欄位並呼叫
// POST /api/me/complete-profile 後才能進入首頁。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/tribe_model.dart';
import '../../services/senior_mode_controller.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/truku_painters.dart';
import '../../shared/widgets/tribe_picker_sheet.dart';

// 目前僅太魯閣族一個族群，勾選「是否原住民」時固定送這個族群，見
// profile_screen.dart 的 _defaultEthnicGroup 同款規則。
const String _defaultEthnicGroup = '太魯閣族';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _displayNameController = TextEditingController();
  final _tribalNameController = TextEditingController();
  bool _isIndigenous = false;
  Tribe? _tribe;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // 預填 Google 帳號名稱，讓使用者可直接確認或修改，不用從空白開始打。
    final googleName = FirebaseAuth.instance.currentUser?.displayName;
    if (googleName != null && googleName.isNotEmpty) {
      _displayNameController.text = googleName;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _tribalNameController.dispose();
    super.dispose();
  }

  Future<void> _pickTribe() async {
    final tribe = await showModalBottomSheet<Tribe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TribePickerSheet(
        ethnicGroup: _defaultEthnicGroup,
        allowClear: false,
      ),
    );
    if (tribe == null) return;
    setState(() => _tribe = tribe);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      _showError('請輸入中文姓名');
      return;
    }
    if (_isIndigenous && _tribe == null) {
      _showError('請選擇部落');
      return;
    }
    setState(() => _submitting = true);
    try {
      await UserService.completeProfile(
        displayName: displayName,
        isIndigenous: _isIndigenous,
        ethnicGroup: _isIndigenous ? _defaultEthnicGroup : null,
        tribeId: _isIndigenous ? _tribe?.id : null,
        tribalName: _tribalNameController.text.trim().isEmpty
            ? null
            : _tribalNameController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('送出失敗，請稍後再試：$e');
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.midnight,
                    AppColors.primaryDeep,
                    AppColors.primary,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: TrukuWeavePainter(color: AppColors.gold, opacity: 0.12),
            ),
          ),
          SafeArea(
            child: ListenableBuilder(
              listenable: seniorModeController,
              builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                final seniorMode = seniorModeController.enabled;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 64, // 扣掉上下 padding
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'MHUWAY SU · 歡迎加入',
                          style: GoogleFonts.crimsonPro(
                            fontStyle: FontStyle.italic,
                            fontSize: seniorMode ? 14 : 11,
                            color: AppColors.gold,
                            letterSpacing: 3.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '完善你的個人資料',
                          style: GoogleFonts.notoSerifTc(
                            fontSize: seniorMode ? 26 : 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.creamLight,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '這些資料會用於配對語伴與活動報名資格判斷',
                          style: TextStyle(
                            fontSize: seniorMode ? 16 : 12,
                            color: AppColors.cream.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          controller: _displayNameController,
                          labelTriku: 'HANGAN · 中文姓名',
                          hint: '請輸入姓名',
                          seniorMode: seniorMode,
                        ),
                        const SizedBox(height: 16),
                        _buildSwitchRow(seniorMode),
                        const SizedBox(height: 16),
                        _buildSeniorModeRow(),
                        if (_isIndigenous) ...[
                          const SizedBox(height: 16),
                          _buildTribeRow(seniorMode),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _tribalNameController,
                            labelTriku: '族語名字（選填）',
                            hint: '例如 Apyang Imiq',
                            seniorMode: seniorMode,
                          ),
                        ],
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: seniorMode ? 60 : 52,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _submit,
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.ink,
                                    ),
                                  )
                                : Text(
                                    '完　成',
                                    style: GoogleFonts.notoSerifTc(
                                      fontSize: seniorMode ? 20 : 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 4,
                                      color: AppColors.ink,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelTriku,
    required String hint,
    bool seniorMode = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.creamLight.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.cream.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelTriku,
            style: TextStyle(
              fontSize: seniorMode ? 13 : 10,
              color: AppColors.cream.withValues(alpha: 0.65),
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            style: TextStyle(
              fontSize: seniorMode ? 19 : 15,
              color: AppColors.creamLight,
              letterSpacing: 0.8,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(
                color: AppColors.cream.withValues(alpha: 0.35),
                fontSize: seniorMode ? 19 : 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(bool seniorMode) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.creamLight.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.cream.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '是否原住民',
                  style: TextStyle(
                    fontSize: seniorMode ? 18 : 14,
                    color: AppColors.creamLight,
                  ),
                ),
              ),
              Switch(
                value: _isIndigenous,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => setState(() {
                  _isIndigenous = v;
                  if (!v) {
                    _tribe = null;
                    _tribalNameController.clear();
                  }
                }),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              '設定後無法自行更改，如需更正請聯繫管理員',
              style: TextStyle(
                fontSize: seniorMode ? 14 : 11,
                color: AppColors.cream.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeniorModeRow() {
    final seniorMode = seniorModeController.enabled;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.creamLight.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.cream.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '精簡模式',
                  style: TextStyle(
                    fontSize: seniorMode ? 18 : 14,
                    color: AppColors.creamLight,
                  ),
                ),
              ),
              Switch(
                value: seniorMode,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => seniorModeController.setEnabled(v),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text(
              '放大文字與簡化畫面，適合長輩或視力不便使用者',
              style: TextStyle(
                fontSize: seniorMode ? 14 : 11,
                color: AppColors.cream.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTribeRow(bool seniorMode) {
    return InkWell(
      onTap: _pickTribe,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.creamLight.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.cream.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '部落',
              style: TextStyle(
                fontSize: seniorMode ? 13 : 10,
                color: AppColors.cream.withValues(alpha: 0.65),
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _tribe?.name ?? '請選擇部落',
                    style: TextStyle(
                      fontSize: seniorMode ? 19 : 15,
                      color: _tribe == null
                          ? AppColors.cream.withValues(alpha: 0.35)
                          : AppColors.creamLight,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.cream.withValues(alpha: 0.5),
                  size: seniorMode ? 22 : 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
