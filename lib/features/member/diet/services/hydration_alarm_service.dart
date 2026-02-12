import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class HydrationAlarmService {
  static final HydrationAlarmService _instance = HydrationAlarmService._internal();
  factory HydrationAlarmService() => _instance;
  HydrationAlarmService._internal();

  final Random _random = Random();

  // Duolingo-style engaging notification messages
  static const List<Map<String, String>> _notificationMessages = [
    // Friendly & Encouraging
    {'title': '💧 Hydration Time!', 'body': 'Your body is calling! Time for some H2O magic ✨'},
    {'title': '🌊 Water Break!', 'body': 'Stay amazing! Drink a glass and keep crushing it 💪'},
    {'title': '💙 Your Body Needs You', 'body': 'Show yourself some love with a refreshing glass of water'},
    {'title': '⭐ You\'re Doing Great!', 'body': 'Keep that streak going! Time to hydrate 🎯'},
    
    // Playful & Fun
    {'title': '🐋 Whale Hello There!', 'body': 'Even whales need water. You do too! 🌊'},
    {'title': '🎉 Hydration Party!', 'body': 'Your cells are throwing a party. Bring the water! 💃'},
    {'title': '🚀 Fuel Up!', 'body': 'Astronauts drink water in space. You can drink it here! 🌌'},
    {'title': '🦄 Unicorn Approved!', 'body': 'Magical beings stay hydrated. Join the club! ✨'},
    {'title': '🎮 Achievement Unlocked!', 'body': 'Drink water to level up your health stats 🏆'},
    
    // Motivational & Inspiring
    {'title': '💪 Strong & Hydrated', 'body': 'Champions drink water. You\'re a champion! 🏅'},
    {'title': '🔥 On Fire!', 'body': 'Keep your winning streak alive! Time to hydrate 💧'},
    {'title': '🌟 Shine Bright!', 'body': 'Hydrated skin glows! Drink up and sparkle ✨'},
    {'title': '🎯 Goal Getter!', 'body': 'You\'re crushing your goals! Don\'t forget to hydrate 💙'},
    
    // Gentle Reminders
    {'title': '💧 Friendly Reminder', 'body': 'Your water bottle misses you! Time for a sip 😊'},
    {'title': '🌸 Self-Care Alert', 'body': 'Taking care of yourself? Start with water 💕'},
    {'title': '☀️ Sunshine & Water', 'body': 'Perfect combo for a perfect you! Drink up 🌈'},
    {'title': '🌺 Wellness Check', 'body': 'Your body deserves the best. Give it some water! 💧'},
    
    // Health Facts & Tips
    {'title': '🧠 Brain Boost!', 'body': 'Water improves focus by 14%! Drink up, genius 🎓'},
    {'title': '💚 Health Tip', 'body': 'Water flushes toxins. Be kind to your kidneys! 🫶'},
    {'title': '⚡ Energy Alert!', 'body': 'Dehydration causes fatigue. Power up with water! 🔋'},
    {'title': '🏃 Performance Boost', 'body': 'Athletes drink water. So should you! 🥇'},
    
    // Time-Based Messages
    {'title': '☕ Better Than Coffee', 'body': 'Water wakes you up naturally! Give it a try 🌅'},
    {'title': '🌙 Evening Hydration', 'body': 'Wind down with water. Your body will thank you! 😌'},
    {'title': '🍽️ Pre-Meal Tip', 'body': 'Drink water before eating. Your digestion loves it! 🥗'},
    
    // Streak & Progress
    {'title': '🔥 Streak Alert!', 'body': 'Don\'t break your hydration streak! Keep going 💪'},
    {'title': '📈 Progress Check', 'body': 'You\'re so close to your goal! One more glass 🎯'},
    {'title': '🏆 Champion Status', 'body': 'Consistency is key! Time for your water ritual 👑'},
    
    // Quirky & Humorous
    {'title': '🐪 Not a Camel?', 'body': 'Then you need water! Camels can wait, you can\'t 😄'},
    {'title': '🌵 Desert Mode: OFF', 'body': 'Stay hydrated and avoid turning into a cactus! 🌊'},
    {'title': '🧊 Ice Ice Baby', 'body': 'Cool down with some refreshing water! ❄️'},
    {'title': '💦 Splash Time!', 'body': 'Make a splash with your hydration game! 🌊'},
    
    // Urgent but Friendly
    {'title': '⏰ Don\'t Forget!', 'body': 'Your water goal is waiting! Let\'s do this 💙'},
    {'title': '🚨 Hydration Alert!', 'body': 'Your body sent an SOS. Water to the rescue! 🆘'},
    {'title': '📢 Important!', 'body': 'You + Water = Unstoppable! Time to drink 💧'},
    
    // Seasonal & Weather
    {'title': '☀️ Hot Day Ahead', 'body': 'Beat the heat with cool, refreshing water! 🧊'},
    {'title': '🌧️ Rainy Day Hydration', 'body': 'Even when it rains, you need to hydrate! ☔'},
    {'title': '❄️ Winter Wellness', 'body': 'Cold weather? Warm or cool water keeps you healthy! 🫖'},
    
    // Empowering Messages
    {'title': '👑 Treat Yourself', 'body': 'Royalty stays hydrated. You deserve the best! 💎'},
    {'title': '🌈 Feel Amazing', 'body': 'Water = instant mood boost! Try it now 😊'},
    {'title': '✨ Glow Up Time', 'body': 'Hydration is the secret to that natural glow! 🌟'},
    {'title': '💝 Love Yourself', 'body': 'Self-care starts with a simple glass of water 🥰'},
  ];

  /// Get a random notification message
  Map<String, String> _getRandomMessage() {
    return _notificationMessages[_random.nextInt(_notificationMessages.length)];
  }

  /// Get a time-appropriate message (morning, afternoon, evening)
  Map<String, String> _getTimeBasedMessage(int hour) {
    if (hour >= 6 && hour < 12) {
      // Morning messages
      final morningMessages = [
        {'title': '🌅 Good Morning!', 'body': 'Start your day right with a glass of water! ☀️'},
        {'title': '☕ Morning Ritual', 'body': 'Water first, everything else second! 💧'},
        {'title': '🌞 Rise & Hydrate', 'body': 'Your body waited all night for this! Drink up 🥤'},
      ];
      return morningMessages[_random.nextInt(morningMessages.length)];
    } else if (hour >= 12 && hour < 17) {
      // Afternoon messages
      final afternoonMessages = [
        {'title': '🌤️ Afternoon Boost', 'body': 'Beat the afternoon slump with water! ⚡'},
        {'title': '☀️ Midday Refresh', 'body': 'Recharge with some H2O magic! 💙'},
        {'title': '🎯 Stay Focused', 'body': 'Water keeps your brain sharp! Time to drink 🧠'},
      ];
      return afternoonMessages[_random.nextInt(afternoonMessages.length)];
    } else if (hour >= 17 && hour < 21) {
      // Evening messages
      final eveningMessages = [
        {'title': '🌆 Evening Hydration', 'body': 'Wind down your day with refreshing water! 🌙'},
        {'title': '✨ Almost There!', 'body': 'Finish strong! Complete your hydration goal 🎯'},
        {'title': '🌃 Night Routine', 'body': 'End your day right with a glass of water 💧'},
      ];
      return eveningMessages[_random.nextInt(eveningMessages.length)];
    } else {
      // Late night/early morning
      return {'title': '🌙 Late Night Sip', 'body': 'Even night owls need water! Quick drink 🦉'};
    }
  }

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await Alarm.init();
      _isInitialized = true;
      debugPrint('HydrationAlarmService initialized');
      // Note: Alarm ring stream listener is handled in main.dart for navigation
    } catch (e) {
      debugPrint('Error initializing Alarm: $e');
    }
  }

  Future<void> scheduleHydrationReminders({
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    int intervalMinutes = 60,
  }) async {
    await initialize();
    
    debugPrint('scheduleHydrationReminders (Pure Alarm) called: Start=${startTime.toString()}, End=${endTime.toString()}, Interval=$intervalMinutes');
    
    // Save settings to SharedPreferences for persistence
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('hydration_start_hour', startTime.hour);
    await prefs.setInt('hydration_start_minute', startTime.minute);
    await prefs.setInt('hydration_end_hour', endTime.hour);
    await prefs.setInt('hydration_end_minute', endTime.minute);
    await prefs.setInt('hydration_interval', intervalMinutes);
    await prefs.setBool('hydration_enabled', true);
    
    // Clear all existing alarms/notifications first
    await cancelReminders();

    final now = DateTime.now();
    
    // Calculate all reminder times for today
    var currentSchedule = DateTime(
      now.year,
      now.month,
      now.day,
      startTime.hour,
      startTime.minute,
    );

    // End boundary for today
    var boundaryEnd = DateTime(
      now.year,
      now.month,
      now.day,
      endTime.hour,
      endTime.minute,
    );

    // If end is before start, it spans to the next day
    if (boundaryEnd.isBefore(currentSchedule)) {
       boundaryEnd = boundaryEnd.add(const Duration(days: 1));
    }

    int id = 0;
    final List<Map<String, dynamic>> scheduledAlarms = [];
    
    while (currentSchedule.isBefore(boundaryEnd) ||
        currentSchedule.isAtSameMomentAs(boundaryEnd)) {
      
      // Schedule for today and let it repeat daily
      DateTime targetTime = DateTime(
        now.year,
        now.month,
        now.day,
        currentSchedule.hour,
        currentSchedule.minute,
      );
      
      // If this time has already passed today, schedule for tomorrow
      if (targetTime.isBefore(now)) {
        targetTime = targetTime.add(const Duration(days: 1));
      }
      
      // Use time-based message for variety
      final message = _getTimeBasedMessage(targetTime.hour);

      await _scheduleRepeatingAlarm(
        id: 100 + id,
        hour: currentSchedule.hour,
        minute: currentSchedule.minute,
        title: message['title']!,
        body: message['body']!,
      );
      
      scheduledAlarms.add({
        'id': 100 + id,
        'hour': currentSchedule.hour,
        'minute': currentSchedule.minute,
      });

      currentSchedule = currentSchedule.add(Duration(minutes: intervalMinutes));
      id++;
      
      // Safety break to prevent infinite loops
      if (id > 48) break; 
    }
    
    // Save scheduled alarm info for recovery
    await prefs.setString('scheduled_alarms', scheduledAlarms.map((a) => '${a['id']},${a['hour']},${a['minute']}').join(';'));
    
    debugPrint('Scheduled $id daily repeating hydration alarms');
  }

  /// Schedule a repeating alarm that fires daily at the same time
  Future<void> _scheduleRepeatingAlarm({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    DateTime targetTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If time has passed today, schedule for tomorrow
    if (targetTime.isBefore(now)) {
      targetTime = targetTime.add(const Duration(days: 1));
    }

    debugPrint('Scheduling DAILY Repeating Alarm: ID=$id at $hour:$minute (next: $targetTime)');

    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: targetTime,
      assetAudioPath: 'assets/sound/beep.mp3',
      loopAudio: false,
      vibrate: true,
      volumeSettings: const VolumeSettings.fixed(),
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        icon: 'ic_launcher',
      ),
      warningNotificationOnKill: true,
      androidFullScreenIntent: false,
    );

    try {
      await Alarm.set(alarmSettings: alarmSettings);
      debugPrint('Successfully scheduled daily repeating Alarm for ID=$id');
    } catch (e) {
      debugPrint('Error scheduling Alarm: $e');
    }
  }

  /// Restore alarms from saved settings (call on app start)
  Future<void> restoreAlarmsFromSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('hydration_enabled') ?? false;
    
    if (!enabled) {
      debugPrint('Hydration reminders not enabled, skipping restore');
      return;
    }

    final startHour = prefs.getInt('hydration_start_hour');
    final startMinute = prefs.getInt('hydration_start_minute');
    final endHour = prefs.getInt('hydration_end_hour');
    final endMinute = prefs.getInt('hydration_end_minute');
    final interval = prefs.getInt('hydration_interval');

    if (startHour == null || startMinute == null || endHour == null || endMinute == null || interval == null) {
      debugPrint('Incomplete hydration settings, cannot restore');
      return;
    }

    debugPrint('Restoring hydration alarms from saved settings');
    
    await scheduleHydrationReminders(
      startTime: TimeOfDay(hour: startHour, minute: startMinute),
      endTime: TimeOfDay(hour: endHour, minute: endMinute),
      intervalMinutes: interval,
    );
  }

  Future<void> _scheduleAlarm({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
  }) async {
    // If time is in the past, schedule for tomorrow
    DateTime targetTime = dateTime;
    if (targetTime.isBefore(DateTime.now())) {
      targetTime = targetTime.add(const Duration(days: 1));
    }

    debugPrint('Scheduling Alarm: ID=$id at $targetTime');

    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: targetTime,
      assetAudioPath: 'assets/sound/beep.mp3', // Ensure this asset exists
      loopAudio: false,
      vibrate: true,
      volumeSettings: const VolumeSettings.fixed(),
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        icon: 'ic_launcher',
      ),
      warningNotificationOnKill: true,
    );

    try {
      await Alarm.set(alarmSettings: alarmSettings);
      debugPrint('Successfully scheduled Alarm for ID=$id');
    } catch (e) {
      debugPrint('Error scheduling Alarm: $e');
    }
  }

  Future<void> cancelReminders() async {
    await initialize();
    
    // Save disabled state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hydration_enabled', false);
    
    // Cancel alarms in our ID range
    for (int i = 0; i < 50; i++) {
      try {
        await Alarm.stop(100 + i);
      } catch (_) {}
    }
    
    // Also cancel standard notifications
    try {
      await NotificationService().cancelReminders();
    } catch (e) {
      debugPrint('Error canceling notifications: $e');
    }
    
    debugPrint('Cancelled existing hydration alarms and notifications');
  }

  Future<void> showTestAlarm() async {
    await initialize();
    final now = DateTime.now();
    final targetTime = now.add(const Duration(seconds: 5));

    final timeStr = "${targetTime.hour > 12 ? targetTime.hour - 12 : (targetTime.hour == 0 ? 12 : targetTime.hour)}:${targetTime.minute.toString().padLeft(2, '0')} ${targetTime.hour >= 12 ? 'PM' : 'AM'}";

    final alarmSettings = AlarmSettings(
      id: 999,
      dateTime: targetTime,
      assetAudioPath: 'assets/sound/beep.mp3',
      loopAudio: false,
      vibrate: true,
      volumeSettings: const VolumeSettings.fixed(),
      notificationSettings: NotificationSettings(
        title: '🔔 Hydration System Test',
        body: 'Hydration system active! Time to drink up 💧',
        icon: 'ic_launcher',
      ),
      warningNotificationOnKill: true,
    );

    await Alarm.set(alarmSettings: alarmSettings);
    debugPrint('Test alarm scheduled for 5 seconds from now at $timeStr');
  }
}
