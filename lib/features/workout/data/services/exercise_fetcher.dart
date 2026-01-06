import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetch ALL exercises from Supabase.
class ExerciseFetcher {
  static Future<List<Map<String, dynamic>>> fetchAllExercises() async {
    debugPrint("🔎 [ExerciseFetcher] Fetching exercises from Supabase...");

    try {
      final response = await Supabase.instance.client
          .from('exercises')
          .select();

      debugPrint("✅ LOADED ${response.length} exercises from Supabase");

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("❌ [ExerciseFetcher] Error: $e");
      rethrow;
    }
  }
}
