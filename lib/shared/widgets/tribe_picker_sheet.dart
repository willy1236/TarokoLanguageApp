import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../models/tribe_model.dart';
import '../../services/user_service.dart';

// 部落 picker 用「不設定部落」選項的 sentinel id，真實 tribes.id 皆為正整數，不會衝突。
const int kClearTribeId = -1;

/// 部落選擇 bottom sheet，供個人頁編輯部落、首次完善資料、搜尋篩選共用。
/// [allowClear] 為 false 時不顯示「不設定部落」選項（首次完善資料流程部落為必填）。
/// [ethnicGroup] 為 null 時列出所有族群的部落（搜尋篩選用途）。
class TribePickerSheet extends StatefulWidget {
  final String? ethnicGroup;
  final bool allowClear;
  const TribePickerSheet({super.key, this.ethnicGroup, this.allowClear = true});

  @override
  State<TribePickerSheet> createState() => _TribePickerSheetState();
}

class _TribePickerSheetState extends State<TribePickerSheet> {
  final _searchController = TextEditingController();
  List<Tribe>? _tribes;
  String? _error;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _keyword = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final tribes = await UserService.fetchTribes(
        ethnicGroup: widget.ethnicGroup,
      );
      if (mounted) setState(() => _tribes = tribes);
    } catch (e, st) {
      debugPrint('Failed to load tribes: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) setState(() => _error = '載入部落清單失敗，請稍後再試');
    }
  }

  List<Tribe> get _filtered {
    final tribes = _tribes ?? const [];
    if (_keyword.isEmpty) return tribes;
    return tribes
        .where(
          (t) =>
              t.name.contains(_keyword) ||
              t.county.contains(_keyword) ||
              t.township.contains(_keyword),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  '選擇部落',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜尋部落、縣市或鄉鎮',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.creamLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error!, style: TextStyle(color: AppColors.fog)),
      );
    }
    if (_tribes == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      );
    }
    final tribes = _filtered;
    if (tribes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('找不到符合的部落', style: TextStyle(color: AppColors.fog)),
      );
    }
    final clearOptionCount = widget.allowClear ? 1 : 0;
    return ListView.separated(
      shrinkWrap: true,
      itemCount: tribes.length + clearOptionCount,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        color: AppColors.creamDeep,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (ctx, i) {
        if (widget.allowClear && i == 0) {
          return ListTile(
            title: Text(
              '不設定部落',
              style: GoogleFonts.notoSerifTc(
                fontSize: 14,
                color: AppColors.fog,
                letterSpacing: 0.5,
              ),
            ),
            onTap: () => Navigator.pop(
              context,
              const Tribe(
                id: kClearTribeId,
                ethnicGroup: '',
                name: '',
                nameTruku: '',
                county: '',
                township: '',
              ),
            ),
          );
        }
        final tribe = tribes[i - clearOptionCount];
        return ListTile(
          title: Text(
            tribe.name,
            style: GoogleFonts.notoSerifTc(
              fontSize: 14,
              color: AppColors.ink,
              letterSpacing: 0.5,
            ),
          ),
          subtitle: Text(
            '${tribe.county}${tribe.township} · ${tribe.nameTruku}',
            style: TextStyle(fontSize: 11, color: AppColors.fog),
          ),
          onTap: () => Navigator.pop(context, tribe),
        );
      },
    );
  }
}
