import 'package:flutter/foundation.dart';
import '../models/exercise_model.dart';
import '../services/workout_api_service.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../services/workout_cache_service.dart';

class WorkoutRepository {
  final WorkoutApiService api;
  final WorkoutCache cache;

  WorkoutRepository({
    required this.api,
    required this.cache,
  });

  Future<List<Exercise>> loadExercises() async {
    debugPrint("🔍 [WorkoutRepository] Loading exercises…");

    // 1. Try loading cache
    // final cached = await cache.getCachedExercises();
    // if (cached != null) {
    //   debugPrint("💾 [WorkoutRepository] Returning cached exercises");
    //   return cached
    //       .map<Exercise>((e) => Exercise.fromJson(e))
    //       .toList();
    // }

    // 2. Cache empty → call API
    debugPrint("📡 [WorkoutRepository] Cache miss → calling ExerciseDB API…");

    try {
      final apiData = await api.fetchExercises(); // returns List<Map>

      // Convert API result → List<Exercise>
      final exercises = apiData
          .map<Exercise>((e) => Exercise.fromJson(e))
          .toList();

      // Save to cache as JSON
      await cache.saveExercises(
        exercises.map((e) => e.toJson()).toList(),
      );

      return exercises;
    } catch (e) {
      debugPrint("❌ [WorkoutRepository] API fetch failed: $e");
      rethrow;
    }
  }
  Future<List<Exercise>> loadWarmupExercises() async {
    debugPrint("🔍 [WorkoutRepository] Loading warmup exercises…");
    try {
      final String response = await rootBundle.loadString('assets/workouts/warmup_exercises.json');
      final List<dynamic> data = json.decode(response);
      
      return data.map((e) => Exercise.fromJson(e)).toList();
    } catch (e) {
      debugPrint("❌ [WorkoutRepository] Warmup load error: $e");
      return [];
    }
  }
}
