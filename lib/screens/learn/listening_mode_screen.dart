import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../models/level_info.dart';
import '../../services/learn_service.dart';
import '../../shared/widgets/truku_widgets.dart';
import 'listening_quiz_screen.dart';

class _ModeOption {
  final String value;
  final String title;
  final String subtitle;

  const _ModeOption({
    required this.value,
    required this.title,
    required this.subtitle,
  });
}

const List<_ModeOption> _modeOptions = [
  _ModeOption(
    value: 'word_to_zh',
    title: '詞彙聽力．聽音辨義',
    subtitle: '聽 Truku 發音，選中文意思',
  ),
  _ModeOption(
    value: 'word_to_truku',
    title: '詞彙聽力．聽音辨詞',
    subtitle: '聽 Truku 發音，選正確 Truku 拼寫',
  ),
  _ModeOption(
    value: 'sentence_to_zh',
    title: '句子聽力．聽音辨義',
    subtitle: '聽 Truku 句子，選中文意思',
  ),
];

class ListeningModeScreen extends StatefulWidget {
  const ListeningModeScreen({super.key});

  @override
  State<ListeningModeScreen> createState() => _ListeningModeScreenState();
}

class _ListeningModeScreenState extends State<ListeningModeScreen> {
  late Future<List<LevelInfo>> _levelsFuture;
  String? _selectedMode;
  String? _selectedLevel;

  @override
  void initState() {
    super.initState();
    _levelsFuture = LearnService.fetchLevels();
  }

  void _start() {
    final mode = _selectedMode;
    final level = _selectedLevel;
    if (mode == null || level == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListeningQuizScreen(mode: mode, level: level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      body: SafeArea(
        child: FutureBuilder<List<LevelInfo>>(
          future: _levelsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (snapshot.hasError) {
              return _buildError(snapshot.error);
            }
            final levels = snapshot.data ?? const [];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildSectionLabel('選擇模式'),
                const SizedBox(height: 10),
                for (final option in _modeOptions) ...[
                  _ModeCard(
                    option: option,
                    selected: _selectedMode == option.value,
                    onTap: () => setState(() => _selectedMode = option.value),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 12),
                _buildSectionLabel('選擇級別'),
                const SizedBox(height: 10),
                if (levels.isEmpty)
                  Text(
                    '目前沒有可用的級別',
                    style: GoogleFonts.notoSansTc(fontSize: 14, color: AppColors.fog),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final level in levels)
                        _LevelChip(
                          level: level,
                          selected: _selectedLevel == level.level,
                          onTap: () =>
                              setState(() => _selectedLevel = level.level),
                        ),
                    ],
                  ),
                const SizedBox(height: 28),
                _buildStartButton(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: AppColors.ink),
        ),
        const SizedBox(width: 12),
        Text(
          '聽力測驗',
          style: GoogleFonts.notoSerifTc(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        const TrukuDiamond(size: 12, color: AppColors.primary, filled: true),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.notoSerifTc(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    final enabled = _selectedMode != null && _selectedLevel != null;
    return GestureDetector(
      onTap: enabled ? _start : null,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary : AppColors.creamDeep,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            '開始測驗',
            style: GoogleFonts.notoSerifTc(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: enabled ? AppColors.creamLight : AppColors.fog,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(Object? error) {
    final isUnauthorized = error is ApiException && error.isUnauthorized;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          isUnauthorized ? '請先登入' : '載入失敗，請稍後再試',
          style: GoogleFonts.notoSerifTc(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final _ModeOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.cream : AppColors.creamLight,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: selected ? AppColors.primary : AppColors.creamDeep,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              option.title,
              style: GoogleFonts.notoSerifTc(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              option.subtitle,
              style: GoogleFonts.notoSansTc(fontSize: 12, color: AppColors.fog),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final LevelInfo level;
  final bool selected;
  final VoidCallback onTap;

  const _LevelChip({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.creamLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.creamDeep,
            width: 1,
          ),
        ),
        child: Text(
          level.level,
          style: GoogleFonts.notoSerifTc(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.creamLight : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
