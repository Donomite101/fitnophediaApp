import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class NutritionAnalysisResult {
  final String? name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double sugar;

  NutritionAnalysisResult({
    this.name,
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
        if (n == null) return 0;
        if (n is num) return n.toDouble();
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
        // Fallback: ingredients[].parsed[].nutrients
        final ingredientsList = data['ingredients'] as List<dynamic>? ?? [];
        for (final ingData in ingredientsList) {
          final parsedList = (ingData as Map<String, dynamic>)['parsed'] as List<dynamic>? ?? [];
          for (final parsed in parsedList) {
            final nutrients = (parsed as Map<String, dynamic>)['nutrients'] as Map<String, dynamic>? ?? {};
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

    print('FINAL AGGREGATED: $totalCalories kcal, $totalProtein P, $totalCarbs C, $totalFat F');

    return NutritionAnalysisResult(
      name: ingredients.length == 1 ? ingredients.first : null,
      calories: totalCalories,
      protein: totalProtein,
      carbs: totalCarbs,
      fat: totalFat,
      sugar: totalSugar,
    );
  }

  Future<NutritionAnalysisResult?> searchByBarcode(String barcode) async {
    // 1. Try Edamam if keys are available
    if (appId.isNotEmpty && appKey.isNotEmpty) {
      final edamamResult = await _searchEdamamBarcode(barcode);
      if (edamamResult != null) return edamamResult;
    }

    // 2. Fallback to OpenFoodFacts (No keys required, global coverage)
    return await _searchOpenFoodFacts(barcode);
  }

  Future<NutritionAnalysisResult?> _searchEdamamBarcode(String barcode) async {
    final uri = Uri.https(
      'api.edamam.com',
      '/api/food-database/v2/parser',
      {
        'app_id': appId,
        'app_key': appKey,
        'upc': barcode,
      },
    );

    try {
      final res = await http.get(uri);
      print('Edamam Barcode Result ($barcode): ${res.statusCode}');
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      final hints = data['hints'] as List?;
      if (hints == null || hints.isEmpty) return null;

      final food = hints[0]['food'];
      final nutrients = food['nutrients'] as Map<String, dynamic>;

      double getSafe(String key) {
        final val = nutrients[key];
        if (val == null) return 0;
        return (val as num).toDouble();
      }

      return NutritionAnalysisResult(
        name: food['label'],
        calories: getSafe('ENERC_KCAL'),
        protein: getSafe('PROCNT'),
        carbs: getSafe('CHOCDF'),
        fat: getSafe('FAT'),
        sugar: getSafe('SUGAR'),
      );
    } catch (e) {
      print('Edamam Barcode Error: $e');
      return null;
    }
  }

  Future<NutritionAnalysisResult?> _searchOpenFoodFacts(String barcode) async {
    final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
    try {
      final res = await http.get(url);
      print('OpenFoodFacts Result ($barcode): ${res.statusCode}');
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      if (data['status'] != 1) {
        print('Product not found in OpenFoodFacts');
        return null;
      }

      final product = data['product'];
      final nutrients = product['nutriments'] as Map<String, dynamic>?;

      if (nutrients == null) return null;

      double getSafe(String key) {
        final val = nutrients[key];
        if (val == null) return 0;
        return (val as num).toDouble();
      }

      // OpenFoodFacts usually returns per 100g. 
      // For simplicity, we assume one service/unit for now or just take the 100g value.
      return NutritionAnalysisResult(
        name: product['product_name'],
        calories: getSafe('energy-kcal_100g') > 0 ? getSafe('energy-kcal_100g') : getSafe('energy-kcal'),
        protein: getSafe('proteins_100g'),
        carbs: getSafe('carbohydrates_100g'),
        fat: getSafe('fat_100g'),
        sugar: getSafe('sugars_100g'),
      );
    } catch (e) {
      print('OpenFoodFacts Error: $e');
      return null;
    }
  }
}
