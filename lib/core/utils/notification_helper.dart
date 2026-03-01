import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationHelper {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// General method to queue a notification on the server
  static Future<void> push({
    required String? token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    if (token == null || token.isEmpty) {
      debugPrint("⚠️ Cannot push notification: Token is null or empty");
      return;
    }

    try {
      await _db.collection('push_notifications').add({
        'token': token,
        'title': title,
        'body': body,
        'data': data ?? {},
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ Notification queued for token: ${token.substring(0, min(token.length, 10))}...");
    } catch (e) {
      debugPrint("❌ Error queuing notification: $e");
    }
  }

  /// Notify all members of a gym (e.g., when a notice is posted)
  static Future<void> notifyGymMembers({
    required String gymId,
    required String title,
    required String body,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      // 1. Get all members of this gym who have FCM tokens
      final membersSnap = await _db
          .collection('users')
          .where('gymId', isEqualTo: gymId)
          .where('role', isEqualTo: 'member')
          .get();

      debugPrint("📡 Sending broadcast to ${membersSnap.docs.length} members...");

      for (var doc in membersSnap.docs) {
        final data = doc.data();
        String? token;
        
        if (data['fcmToken'] is String) {
          token = data['fcmToken'];
        } else if (data['fcmTokens'] is List && (data['fcmTokens'] as List).isNotEmpty) {
          token = (data['fcmTokens'] as List).first.toString();
        } else if (data['token'] is String) {
          token = data['token'];
        }

        if (token != null && token.isNotEmpty) {
          await push(
            token: token,
            title: title,
            body: body,
            data: {
              'gymId': gymId,
              'type': 'broadcast',
              ...?extraData,
            },
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Error broadcasting to members: $e");
    }
  }

  /// Send a dynamic engagement notification based on user streak
  static Future<void> sendEngagementNudge(String? token, {int streak = 0}) async {
    if (token == null) return;
    
    final random = Random();
    final List<Map<String, String>> presets = [
      {
        'title': streak > 0 ? "Don't break your streak! 🔥" : "Start your streak! 🚀",
        'body': streak > 0 
            ? "Your $streak-day workout streak is at risk. 5 minutes is all it takes to keep it alive!"
            : "The best time to start was yesterday, the second best time is NOW. Let's get that first day!"
      },
      {
        'title': "Ready for your next PR? 💪",
        'body': "Your muscles are rested and ready. Let's hit the gym and beat your personal best today!"
      },
      {
        'title': "The weights are missing you... 🥺",
        'body': "The bench press is feeling lonely. Come back and show it some love!"
      },
      {
        'title': "Your future self will thank you 🙌",
        'body': "A 30-minute workout is only 2% of your day. No excuses!"
      },
    ];

    final preset = presets[random.nextInt(presets.length)];
    
    await push(
      token: token,
      title: preset['title']!,
      body: preset['body']!,
      data: {'type': 'engagement_nudge'},
    );
  }
}
