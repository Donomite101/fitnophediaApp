import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:math';

class NoticeNotificationService {
  static final NoticeNotificationService _instance = NoticeNotificationService._internal();
  factory NoticeNotificationService() => _instance;
  NoticeNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final Random _random = Random();

  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap - navigate to notices screen
        // This will be handled by the main app
      },
    );

    // Request permissions for Android 13+
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  /// Show immediate notification for a new notice
  Future<void> showNoticeNotification({
    required String noticeId,
    required String title,
    required String message,
    required String priority,
  }) async {
    final notificationId = _generateNotificationId(noticeId);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'gym_notices',
      'Gym Notices',
      channelDescription: 'Important announcements from your gym',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: 'ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Add emoji based on priority
    final emoji = _getPriorityEmoji(priority);
    final formattedTitle = '$emoji $title';

    await _notificationsPlugin.show(
      notificationId,
      formattedTitle,
      message,
      details,
      payload: 'notice:$noticeId',
    );
  }

  /// Listen to new notices and show notifications
  Stream<void> listenToNotices(String gymId, String memberId) async* {
    final noticesStream = FirebaseFirestore.instance
        .collection('gyms')
        .doc(gymId)
        .collection('notices')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();

    // Track last seen notice to avoid duplicate notifications
    DateTime? lastSeenTime;

    await for (final snapshot in noticesStream) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          // Check if notice is active and not archived
          final isActive = data['isActive'] ?? true;
          final isArchived = data['isArchived'] ?? false;
          
          if (!isActive || isArchived) continue;

          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          
          // Only notify for notices created after we started listening
          // and not for old notices loaded on initial snapshot
          if (createdAt != null) {
            if (lastSeenTime == null) {
              // First load - set baseline but don't notify
              lastSeenTime = createdAt;
              continue;
            }

            if (createdAt.isAfter(lastSeenTime)) {
              // This is a new notice!
              await showNoticeNotification(
                noticeId: change.doc.id,
                title: data['title'] ?? 'New Notice',
                message: data['message'] ?? '',
                priority: data['priority'] ?? 'medium',
              );
              
              lastSeenTime = createdAt;
            }
          }
        }
      }
      
      yield null;
    }
  }

  String _getPriorityEmoji(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return '🚨';
      case 'medium':
        return '📢';
      case 'low':
        return '💬';
      default:
        return '📌';
    }
  }

  int _generateNotificationId(String noticeId) {
    // Generate a consistent ID from the notice ID
    // Use first 8 characters of notice ID hash
    return noticeId.hashCode.abs() % 100000 + 50000; // Range: 50000-150000
  }

  /// Cancel a specific notice notification
  Future<void> cancelNoticeNotification(String noticeId) async {
    final notificationId = _generateNotificationId(noticeId);
    await _notificationsPlugin.cancel(notificationId);
  }

  /// Cancel all notice notifications
  Future<void> cancelAllNoticeNotifications() async {
    // Cancel notifications in the notice range (50000-150000)
    for (int i = 50000; i < 150000; i += 1000) {
      await _notificationsPlugin.cancel(i);
    }
  }
}
