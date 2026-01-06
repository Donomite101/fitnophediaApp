import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WorkoutApiService {
  Future<List<Map<String, dynamic>>> fetchExercises() async {
    try {
      debugPrint("🔎 [WorkoutApiService] Fetching exercises from Supabase...");

      // Fetch from 'exercises' table
      final response = await Supabase.instance.client
          .from('exercises')
          .select();

      debugPrint("✅ Loaded ${response.length} exercises from Supabase");

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("❌ [WorkoutApiService] Error: $e");
      // Fallback or rethrow
      rethrow;
    }
  }
}
