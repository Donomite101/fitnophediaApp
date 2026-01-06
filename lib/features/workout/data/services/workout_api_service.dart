import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WorkoutApiService {
  // Fetch ALL 1300 exercises
  final String baseUrl =
      "https://exercisedb.p.rapidapi.com/exercises?limit=1300";

  Future<List<Map<String, dynamic>>> fetchExercises() async {
    try {
      debugPrint("🔎 [WorkoutApiService] Fetching ALL exercises...");

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          "X-RapidAPI-Key": dotenv.env['RAPIDAPI_KEY']!,
          "X-RapidAPI-Host": "exercisedb.p.rapidapi.com",
        },
      );

      debugPrint("📡 [WorkoutApiService] Status: ${response.statusCode}");

      if (response.statusCode != 200) {
        debugPrint("❌ API Error: ${response.body}");
        throw Exception("Failed to load exercises");
      }

      final List list = jsonDecode(response.body);

      debugPrint("✅ Loaded ${list.length} exercises");

      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint("❌ [WorkoutApiService] Error: $e");
      rethrow;
    }
  }
}
