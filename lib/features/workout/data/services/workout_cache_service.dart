import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class WorkoutCache {
  static const String key = "cached_exercises";
  static const String timeKey = "cached_exercises_time";

  // read
  Future<List<Map<String, dynamic>>?> getCachedExercises({bool ignoreExpiry = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    final timestamp = prefs.getInt(timeKey);

    if (jsonString == null || timestamp == null) {
      debugPrint("📭 [WorkoutCache] No cache found");
      return null;
    }

    // Cache validity: 24 hours
    if (!ignoreExpiry) {
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age > 86400000) {
        debugPrint("⏳ [WorkoutCache] Cache expired");
        return null;
      }
    }

    debugPrint("💾 [WorkoutCache] Loaded cache");
    final List decoded = jsonDecode(jsonString);
    return decoded.cast<Map<String, dynamic>>();
  }

  // write
  Future<void> saveExercises(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(list));
    await prefs.setInt(
      timeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    debugPrint("💽 [WorkoutCache] Saved exercises to cache");
  }
}
