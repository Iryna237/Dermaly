import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'models/app_notification.dart';
import 'services/notification_log.dart';

/// Centre de notifications, ouvert depuis la cloche de l'accueil.
///
/// Les notifications sont marquées comme lues dès l'ouverture : c'est ce qui
/// fait disparaître le point de la cloche.
class NotificationsPage extends StatefulWidget {
  /// Texte affiché quand le journal est vide : le contenu diffère entre le
  /// patient (rappels de routine et de scan) et le dermatologue (demandes).
  final String emptyMessage;

  const NotificationsPage({
    super.key,
    this.emptyMessage =
        'Your routine reminders and monthly scan reminders will show up here.',
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // Flux créé une seule fois : le recréer à chaque build relance la lecture Firestore
  late final Stream<List<AppNotification>> _notifications = NotificationLog.watch();

  @override
  void initState() {
    super.initState();
    // Ouvrir la page vaut lecture ; l'échec est sans gravité, le point restera
    NotificationLog.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.darkPurple, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.darkPurple,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notifications,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildMessage(
              Icons.cloud_off_rounded,
              'Unable to load your notifications',
              snapshot.error.toString(),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            );
          }

          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return _buildMessage(
              Icons.notifications_none_rounded,
              'No notification yet',
              widget.emptyMessage,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildTile(notifications[index]),
          );
        },
      ),
    );
  }

  Widget _buildTile(AppNotification notification) {
    final icon = notification.isRequest
        ? Icons.person_add_alt_1_rounded
        : notification.isMessage
            ? Icons.chat_bubble_rounded
            : notification.isScan
                ? Icons.camera_alt_rounded
                : (notification.isMorning
                    ? Icons.wb_sunny_rounded
                    : Icons.nights_stay_rounded);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Le non-lu se distingue par un fond teinté, pas par un second point
        color: notification.read ? AppColors.white : AppColors.softPurple.withAlpha(90),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.softGrey),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.softPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryPurple, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: notification.read ? FontWeight.w600 : FontWeight.bold,
                    color: AppColors.darkPurple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: const TextStyle(fontSize: 13, color: AppColors.greyText, height: 1.3),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDate(notification.date),
                  style: const TextStyle(fontSize: 11, color: AppColors.greyText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(IconData icon, String title, String details) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.softPurple,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppColors.primaryPurple),
            ),
            const SizedBox(height: 25),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkPurple,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              details,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.greyText, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// « Today, 8:00 AM » pour le jour même, la date complète au-delà
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final time = '$hour:${date.minute.toString().padLeft(2, '0')} '
        '${date.hour >= 12 ? 'PM' : 'AM'}';

    final sameDay = date.year == now.year && date.month == now.month && date.day == now.day;
    if (sameDay) return 'Today, $time';

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    if (isYesterday) return 'Yesterday, $time';

    return '${_months[date.month - 1]} ${date.day}, $time';
  }
}
