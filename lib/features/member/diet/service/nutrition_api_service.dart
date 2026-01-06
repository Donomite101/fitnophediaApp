import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class NutritionAnalysisResult {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;

  NutritionAnalysisResult({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sugar,
  });
}

class NutritionApiService {
  final String appId = dotenv.env['EDAMAM_APP_ID'] ?? '';
  final String appKey = dotenv.env['EDAMAM_APP_KEY'] ?? '';

  Future<NutritionAnalysisResult> analyzeIngredients(
      List<String> ingredients,
      ) async {
    if (appId.isEmpty || appKey.isEmpty) {
      throw Exception(
        'Edamam keys missing. Check .env (EDAMAM_APP_ID / EDAMAM_APP_KEY).',
      );
    }

    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    double totalSugar = 0;

    for (final raw in ingredients) {
      final ingr = raw.trim();
      if (ingr.isEmpty) continue;

      final uri = Uri.https(
        'api.edamam.com',
        '/api/nutrition-data',
        {
          'app_id': appId,
          'app_key': appKey,
          'ingr': ingr,
        },
      );

      final res = await http.get(uri);

      // Debug
      // ignore: avoid_print
      print('nutrition-data for "$ingr" => ${res.statusCode}');
      // ignore: avoid_print
      print('body: ${res.body}');

      if (res.statusCode != 200) {
        throw Exception(
          'Edamam error ${res.statusCode} for "$ingr". Body: ${res.body}',
        );
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      // Try top-level calories
      double caloriesFromTop = (data['calories'] ?? 0).toDouble();

      final totalNutrients =
      data['totalNutrients'] as Map<String, dynamic>?;

      double protein = 0;
      double carbs = 0;
      double fat = 0;
      double sugar = 0;

      double getFromMap(Map<String, dynamic> map, String key) {
        final n = map[key];
        if (n is Map<String, dynamic>) {
          return (n['quantity'] ?? 0).toDouble();
        }
        return 0;
      }

      if (totalNutrients != null && totalNutrients.isNotEmpty) {
        // Standard Edamam structure
        protein += getFromMap(totalNutrients, 'PROCNT');
        carbs += getFromMap(totalNutrients, 'CHOCDF');
        fat += getFromMap(totalNutrients, 'FAT');
        sugar += getFromMap(totalNutrients, 'SUGAR');

        if (caloriesFromTop == 0) {
          caloriesFromTop = getFromMap(totalNutrients, 'ENERC_KCAL');
        }
      } else {
        // Fallback: ingredients[].parsed[].nutrients (matches your logs)
        final ingredientsList =
            data['ingredients'] as List<dynamic>? ?? [];

        for (final ingData in ingredientsList) {
          final parsedList =
              (ingData as Map<String, dynamic>)['parsed']
              as List<dynamic>? ??
                  [];
          for (final parsed in parsedList) {
            final nutrients =
                (parsed as Map<String, dynamic>)['nutrients']
                as Map<String, dynamic>? ??
                    {};

            protein += getFromMap(nutrients, 'PROCNT');
            carbs += getFromMap(nutrients, 'CHOCDF');
            fat += getFromMap(nutrients, 'FAT');
            sugar += getFromMap(nutrients, 'SUGAR');

            if (caloriesFromTop == 0) {
              caloriesFromTop += getFromMap(nutrients, 'ENERC_KCAL');
            }
          }
        }
      }

      totalCalories += caloriesFromTop;
      totalProtein += protein;
      totalCarbs += carbs;
      totalFat += fat;
      totalSugar += sugar;
    }

    // ignore: avoid_print
    print(
        'Aggregated -> kcal:$totalCalories P:$totalProtein C:$totalCarbs F:$totalFat S:$totalSugar');

    return NutritionAnalysisResult(
      calories: totalCalories,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      sugar: totalSugar,
    );
  }
}
