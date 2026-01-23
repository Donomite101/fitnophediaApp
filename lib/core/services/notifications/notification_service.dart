// lib/core/notifications/notification_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz; // timezone import

class NotificationService {
  // <-- made public so other modules can use it: NotificationService.fln
  static final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();

  static const String _fcmCacheKey = 'cached_fcm_token';
  static const String _fcmStoredOnceKey = 'fcm_stored_once';

  /// Call once on app startup (after WidgetsBinding.ensureInitialized())
  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await fln.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Local notification tapped: ${details.payload}');
      },
    );

    final androidImplementation = fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  static Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    try {
      const android = AndroidNotificationDetails(
        'fitnophedia_channel_01',
        'General',
        channelDescription: 'General notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );
      const ios = DarwinNotificationDetails();
      const detail = NotificationDetails(android: android, iOS: ios);
      await fln.show(id, title, body, detail, payload: payload);
    } catch (e) {
      debugPrint('showLocal error: $e');
    }
  }

  /// Schedule at a local DateTime (caller supplies local DateTime)
  static Future<void> scheduleAt({
    required int id,
    required DateTime scheduledLocal,
    required String title,
    required String body,
    String? payload,
    tz.TZDateTime? tzDateTime, // optional if caller computed TZ DT
  }) async {
    try {
      final when = tzDateTime ?? tz.TZDateTime.from(scheduledLocal, tz.local);
      final android = AndroidNotificationDetails('fitnophedia_channel_01', 'General');
      final ios = DarwinNotificationDetails();
      final details = NotificationDetails(android: android, iOS: ios);

      await fln.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('scheduleAt error: $e');
    }
  }

  // FCM token helpers (unchanged)
  static Future<void> cacheFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmCacheKey, token);
  }

  static Future<String?> getCachedFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fcmCacheKey);
  }

  static Future<void> storeFcmTokenToFirestore({
    required String gymId,
    required String memberId,
    CollectionReference? rootRef,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_fcmCacheKey);
      if (token == null || token.isEmpty) return;

      final ref = rootRef ?? FirebaseFirestore.instance.collection('gyms');
      final memberRef = ref.doc(gymId).collection('members').doc(memberId);
      await memberRef.set({'fcmToken': token}, SetOptions(merge: true));
      await prefs.setBool(_fcmStoredOnceKey, true);
      debugPrint('FCM token stored to firestore for $gymId/$memberId');
    } catch (e) {
      debugPrint('storeFcmTokenToFirestore error: $e');
    }
  }

  static Future<void> ensureTokenSaved({String? gymId, String? memberId}) async {
    try {
      final fcm = FirebaseMessaging.instance;
      final token = await fcm.getToken();
      if (token != null) {
        await cacheFcmToken(token);
        if (gymId != null && memberId != null) {
          await storeFcmTokenToFirestore(gymId: gymId, memberId: memberId);
        }
      }
    } catch (e) {
      debugPrint('ensureTokenSaved error: $e');
    }
  }
}
