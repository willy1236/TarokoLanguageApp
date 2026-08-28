// 活動通知：發起人對「我有參加」的活動發出的提醒，彙整成一份通知清單。
//
// 後端沒有跨活動的通知收件匣，這裡用 GET /api/events（isJoined 篩出我參加的）
// 逐一打 GET /api/events/:id/reminders 湊出來，只留已送出（status == sent）的。

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_format.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/senior_mode_controller.dart';
import 'event_detail_screen.dart';

class _NotificationItem {
  final EventSummary event;
  final EventReminder reminder;
  const _NotificationItem(this.event, this.reminder);

  DateTime get sortKey => reminder.sentAt ?? reminder.scheduledAt;
}

class EventNotificationsScreen extends StatefulWidget {
  const EventNotificationsScreen({super.key});

  @override
  State<EventNotificationsScreen> createState() =>
      _EventNotificationsScreenState();
}

class _EventNotificationsScreenState extends State<EventNotificationsScreen> {
  bool _loading = true;
  Object? _error;
  List<_NotificationItem> _items = const [];

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
      final events = await EventService.fetchEvents(scope: 'all', pageSize: 50);
      final joined = events.where((e) => e.isJoined).toList();
      final remindersByEvent = await Future.wait(
        joined.map(
          (e) => EventService.fetchReminders(e.id).catchError(
            (_) => const <EventReminder>[],
          ),
        ),
      );
      final items = <_NotificationItem>[];
      for (var i = 0; i < joined.length; i++) {
        for (final reminder in remindersByEvent[i]) {
          if (reminder.status == 'sent') {
            items.add(_NotificationItem(joined[i], reminder));
          }
        }
      }
      items.sort((a, b) => b.sortKey.compareTo(a.sortKey));
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: seniorModeController,
      builder: (context, _) => _buildScaffold(seniorModeController.enabled),
    );
  }

  Widget _buildScaffold(bool seniorMode) {
    return Scaffold(
      backgroundColor: AppColors.creamLight,
      appBar: AppBar(
        backgroundColor: AppColors.creamLight,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(
          '活動通知',
          style: GoogleFonts.notoSerifTc(
            fontSize: seniorMode ? 20 : 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: _buildBody(seniorMode),
      ),
    );
  }

  Widget _buildBody(bool seniorMode) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      final message = _error is ApiException
          ? (_error as ApiException).message
          : '發生錯誤，請稍後再試';
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 90),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_off,
                  size: seniorMode ? 56 : 40,
                  color: AppColors.fog,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: seniorMode ? 18 : 13,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(onPressed: _load, child: const Text('重試')),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Column(
              children: [
                Icon(
                  Icons.notifications_none,
                  size: seniorMode ? 60 : 44,
                  color: AppColors.fog,
                ),
                const SizedBox(height: 12),
                Text(
                  '還沒有收到活動通知',
                  style: GoogleFonts.notoSerifTc(
                    fontSize: seniorMode ? 22 : 16,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '報名的活動有新消息時會顯示在這裡',
                  style: TextStyle(
                    fontSize: seniorMode ? 16 : 12,
                    color: AppColors.fog,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildTile(_items[i], seniorMode),
    );
  }

  Widget _buildTile(_NotificationItem item, bool seniorMode) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(eventId: item.event.id),
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(seniorMode ? 18 : 14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.creamDeep),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: seniorMode ? 20 : 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: seniorMode ? 16 : 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.reminder.message,
              style: GoogleFonts.notoSerifTc(
                fontSize: seniorMode ? 20 : 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatDateTime(
                (item.reminder.sentAt ?? item.reminder.scheduledAt).toLocal(),
              ),
              style: TextStyle(
                fontSize: seniorMode ? 14 : 11,
                color: AppColors.fog,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
