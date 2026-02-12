import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    try {
      final String timeZoneNameRaw = await FlutterTimezone.getLocalTimezone().then((info) => info.identifier);
      String timeZoneName = timeZoneNameRaw;
      
      // Handle legacy aliases not found in some timezone databases
      if (timeZoneName == 'Asia/Calcutta') {
        timeZoneName = 'Asia/Kolkata';
      }
      
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        debugPrint('Timezone initialized: $timeZoneName');
      } catch (e) {
        debugPrint('Could not find location $timeZoneName, falling back to UTC');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    } catch (e) {
      debugPrint('Error getting local timezone: $e. Defaulting to UTC.');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // Request Android 13+ permissions
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
      
      // Delete old channel to force refresh
      await androidImplementation.deleteNotificationChannel('hydration_channel');
      debugPrint('Old notification channel deleted');
    }

    _isInitialized = true;
    debugPrint('NotificationService initialized');
  }

  Future<void> scheduleHydrationReminders({
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int intervalMinutes = 60,
  }) async {
    await initialize(); // Ensure initialized
    debugPrint('scheduleHydrationReminders called with: Start=${startTime.toString()}, End=${endTime.toString()}, Interval=$intervalMinutes');
    await cancelReminders(); // Clear existing

    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      startTime.hour,
      startTime.minute,
    );

    final endDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      endTime.hour,
      endTime.minute,
    );

    DateTime effectiveEndDateTime = endDateTime;
    if (effectiveEndDateTime.isBefore(scheduledTime)) {
       debugPrint('scheduleHydrationReminders: End time is before start time, adding 1 day to end time.');
       effectiveEndDateTime = effectiveEndDateTime.add(const Duration(days: 1));
       debugPrint('scheduleHydrationReminders: Adjusted end time to $effectiveEndDateTime');
    }

    int id = 0;
    while (scheduledTime.isBefore(effectiveEndDateTime) ||
        scheduledTime.isAtSameMomentAs(effectiveEndDateTime)) {
      
      await _scheduleDailyNotification(
        id: 100 + id, // Unique IDs for hydration
        title: "Time to Hydrate! 💧",
        body: "Stay on track with your water goal. Drink a glass now!",
        time: TimeOfDay.fromDateTime(scheduledTime),
      );

      scheduledTime = scheduledTime.add(Duration(minutes: intervalMinutes));
      id++;
    }
  }

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required TimeOfDay time,
  }) async {
    debugPrint('Scheduling hydration notification: ID=$id at ${time.hour}:${time.minute}');
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfTime(time),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hydration_channel_v2', // NEW CHANNEL ID
            'Hydration Reminders',
            channelDescription: 'Reminders to drink water',
            importance: Importance.max, // Ensure MAX importance
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeats daily at this time
      );
      debugPrint('Successfully scheduled EXACT notification for ID=$id');
    } catch (e) {
      debugPrint('Error scheduling exact alarm: $e');
      // Fallback to inexact if exact fails
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfTime(time),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hydration_channel_v2',
            'Hydration Reminders',
            channelDescription: 'Reminders to drink water',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('Successfully scheduled INEXACT notification (fallback) for ID=$id');
    }
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final DateTime now = DateTime.now();
    final DateTime scheduledDateLocal = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    
    // Convert local DateTime to the timezone aware DateTime
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(scheduledDateLocal, tz.local);
    
    // Add a 2-minute buffer: if the scheduled time is within 2 mins of now, 
    // it's likely too close for the system to fire accurately today, so move to tomorrow.
    final tzNow = tz.TZDateTime.now(tz.local);
    if (scheduledDate.isBefore(tzNow.add(const Duration(minutes: 2)))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelReminders() async {
    await initialize();
    for (int i = 0; i < 50; i++) { // Increased range just in case
      await flutterLocalNotificationsPlugin.cancel(100 + i);
    }
  }

  Future<void> showTestNotification() async {
    await initialize();
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'hydration_channel_v2',
      'Hydration Reminders',
      channelDescription: 'Reminders to drink water',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    
    // Show one immediately
    await flutterLocalNotificationsPlugin.show(
      999,
      'System Check: Hydration 💧',
      'Your water reminders are active and working!',
      notificationDetails,
    );
    
    // And schedule one for 10 seconds later to test 'zonedSchedule'
    await flutterLocalNotificationsPlugin.zonedSchedule(
      998,
      'Test Reminder (10s delay) 💧',
      'This confirms scheduled reminders work!',
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('Test notifications (instant + 10s) requested');
  }
}
