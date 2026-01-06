import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Fetch ALL ExerciseDB exercises in a single call.
class ExerciseFetcher {
  static const String _url =
      "https://exercisedb.p.rapidapi.com/exercises?limit=1300";

  static Future<List<Map<String, dynamic>>> fetchAllExercises() async {
    debugPrint("🔎 [ExerciseFetcher] Fetching ALL exercises at once…");

    final apiKey = dotenv.env['RAPIDAPI_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Missing RAPIDAPI_KEY in .env");
    }

    final response = await http.get(
      Uri.parse(_url),
      headers: {
        "X-RapidAPI-Key": apiKey,
        "X-RapidAPI-Host": "exercisedb.p.rapidapi.com",
      },
    );

    debugPrint("📡 Status Code: ${response.statusCode}");

    if (response.statusCode != 200) {
      debugPrint("❌ API Error: ${response.body}");
      throw Exception("Failed to fetch exercises");
    }

    final List decoded = json.decode(response.body);

    debugPrint("✅ LOADED ${decoded.length} exercises into memory");

    return decoded.cast<Map<String, dynamic>>();
  }
}
