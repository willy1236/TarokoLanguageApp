// 活動列表的精選大卡與一般列表列。

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/event_model.dart';
import '../../../shared/widgets/truku_painters.dart';
import '../../../core/constants/app_typography.dart';

// 依分類配色（呼應發起活動表單的分類清單），純視覺區隔用。
Color _categoryColor(String? category) {
  switch (category) {
    case '走讀':
    case '線上':
      return AppColors.moss;
    case '工藝':
      return AppColors.goldDeep;
    case '族語':
    case '音樂':
      return AppColors.primary;
    default:
      return AppColors.inkSoft;
  }
}

// ── 日期/時間格式（後端時間為 UTC，顯示轉本地）────────────────
String _mon(DateTime d) => monthLabel(d);
String _day(DateTime d) => d.day.toString().padLeft(2, '0');
String _wd(DateTime d) => weekdayLabel(d);
String _time(DateTime d) => formatTime(d);

String _statusLabel(EventSummary e) {
  if (e.isJoined) return '已報名';
  if (e.displayStatus == 'ended') return '已結束';
  if (e.displayStatus == 'cancelled') return '已取消';
  if (e.isFull) return '已額滿';
  if (e.registrationOpen) return '報名中';
  return '';
}

/// 列表第一筆的精選大卡（含名額進度與行動按鈕）。
class EventFeaturedCard extends StatelessWidget {
  final EventSummary event;
  final bool seniorMode;
  final ValueChanged<EventSummary> onTap;

  const EventFeaturedCard({
    super.key,
    required this.event,
    required this.seniorMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _buildFeaturedCard(event, seniorMode);

  Widget _buildFeaturedCard(EventSummary e, bool seniorMode) {
    final d = e.startsAt.toLocal();
    final label = _statusLabel(e);
    return GestureDetector(
      onTap: () => onTap(e),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDeep],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: 0.25,
                      child: CustomPaint(
                        painter: TrukuWeavePainter(opacity: 1, scale: 0.7),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 46,
                      child: CustomPaint(
                        painter: TrukuMountainsPainter(
                          color: AppColors.ink,
                          opacity: 0.9,
                        ),
                      ),
                    ),
                    if (label.isNotEmpty)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: AppTypography.micro,
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ink.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _mon(d),
                              style: const TextStyle(
                                fontSize: AppTypography.micro,
                                color: AppColors.gold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              _day(d),
                              style: AppTypography.serif(
                                fontSize: AppTypography.subtitle,
                                fontWeight: FontWeight.w700,
                                color: AppColors.creamLight,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: AppTypography.serif(
                        fontSize: AppTypography.size(AppTypography.title, seniorMode: seniorMode),
                        fontWeight: FontWeight.w600,
                        color: AppColors.creamLight,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Icon(
                          Icons.access_time,
                          color: AppColors.gold,
                          size: seniorMode ? 18 : 11,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text(
                            '${_wd(d)} ${_time(d)}',
                            style: TextStyle(
                              fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                              color: AppColors.creamLight.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.location_on_outlined,
                          color: AppColors.gold,
                          size: seniorMode ? 18 : 11,
                        ),
                        Text(
                          e.location ?? '線上',
                          style: TextStyle(
                            fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                            color: AppColors.creamLight.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildFeaturedCapacityRow(e, seniorMode),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCapacityRow(EventSummary e, bool seniorMode) {
    final max = e.maxParticipants;
    final remaining = max == null
        ? null
        : (max - e.participantCount).clamp(0, max);
    final capacityText = max == null
        ? '${e.participantCount} 人報名 · 不限名額'
        : '${e.participantCount}/$max 人 · 剩 $remaining 個名額';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (max != null)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (e.participantCount / max).clamp(0, 1).toDouble(),
                    minHeight: 6,
                    backgroundColor: AppColors.inkSoft,
                    valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  capacityText,
                  style: TextStyle(
                    fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                    color: AppColors.creamLight.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          )
        else
          Expanded(
            child: Text(
              capacityText,
              style: TextStyle(
                fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                color: AppColors.creamLight.withValues(alpha: 0.7),
              ),
            ),
          ),
        const SizedBox(width: 12),
        _buildCtaButton(e, seniorMode),
      ],
    );
  }

  Widget _buildCtaButton(EventSummary e, bool seniorMode) {
    String text;
    if (e.isJoined) {
      text = '已報名';
    } else if (e.displayStatus == 'ended') {
      text = '已結束';
    } else if (e.displayStatus == 'cancelled') {
      text = '已取消';
    } else if (e.isFull) {
      text = '已額滿';
    } else if (e.registrationOpen) {
      text = '我要參加';
    } else {
      text = '查看';
    }
    return GestureDetector(
      onTap: () => onTap(e),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: seniorMode ? 20 : 16,
          vertical: seniorMode ? 13 : 9,
        ),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: AppTypography.subtitleStyle(seniorMode: seniorMode, color: AppColors.ink),
        ),
      ),
    );
  }
}

/// 精選以外的活動列表。
class EventList extends StatelessWidget {
  final List<EventSummary> events;
  final bool seniorMode;
  final ValueChanged<EventSummary> onTap;

  const EventList({
    super.key,
    required this.events,
    required this.seniorMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _buildList(events, seniorMode);

  Widget _buildList(List<EventSummary> events, bool seniorMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: events
            .skip(1)
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildListTile(e, seniorMode),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildListTile(EventSummary e, bool seniorMode) {
    final d = e.startsAt.toLocal();
    final color = _categoryColor(e.category);
    final capacityText = e.maxParticipants == null
        ? '${e.participantCount} 人報名'
        : '${e.participantCount}/${e.maxParticipants}';
    return GestureDetector(
      onTap: () => onTap(e),
      child: Container(
        padding: EdgeInsets.all(seniorMode ? 16 : 12),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: seniorMode ? 88 : 56,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _mon(d),
                      style: TextStyle(
                        fontSize: AppTypography.size(AppTypography.micro, seniorMode: seniorMode),
                        color: AppColors.gold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _day(d),
                      style: AppTypography.serif(
                        fontSize: AppTypography.size(AppTypography.headline, seniorMode: seniorMode),
                        fontWeight: FontWeight.w700,
                        color: AppColors.creamLight,
                        height: 1,
                      ),
                    ),
                    Text(
                      _wd(d),
                      style: TextStyle(
                        fontSize: AppTypography.size(AppTypography.micro, seniorMode: seniorMode),
                        color: AppColors.creamLight.withValues(alpha: 0.7),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.category != null && !seniorMode)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        e.category!,
                        style: TextStyle(
                          fontSize: AppTypography.micro,
                          color: color,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  if (e.category != null && !seniorMode)
                    const SizedBox(height: 3),
                  Text(
                    e.title,
                    style: AppTypography.serif(
                      fontSize: AppTypography.size(AppTypography.body, seniorMode: seniorMode),
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_time(d)} · ${e.location ?? '線上'}',
                    style: TextStyle(
                      fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                      color: AppColors.fog,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: seniorMode ? 12 : 8),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: seniorMode ? 18 : 11,
                        color: AppColors.inkSoft,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        capacityText,
                        style: TextStyle(
                          fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: seniorMode ? 18 : 14,
                          vertical: seniorMode ? 10 : 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Text(
                          '查看',
                          style: TextStyle(
                            fontSize: AppTypography.size(AppTypography.caption, seniorMode: seniorMode),
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
