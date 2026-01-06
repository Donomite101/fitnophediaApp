import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodBarcodeNutritionResult {
  final String productName;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double sugarPer100g;

  FoodBarcodeNutritionResult({
    required this.productName,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.sugarPer100g,
  });
}

class FoodBarcodeService {
  Future<FoodBarcodeNutritionResult?> fetchByBarcode(String barcode) async {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 1) {
      // product not found
      return null;
    }

    final product = data['product'] as Map<String, dynamic>;
    final name = (product['product_name'] ?? 'Unknown product').toString();

    final nutriments =
        product['nutriments'] as Map<String, dynamic>? ?? {};

    double d(String key) =>
        double.tryParse((nutriments[key]?.toString() ?? '0')) ?? 0.0;

    return FoodBarcodeNutritionResult(
      productName: name,
      caloriesPer100g: d('energy-kcal_100g'),
      proteinPer100g: d('proteins_100g'),
      carbsPer100g: d('carbohydrates_100g'),
      fatPer100g: d('fat_100g'),
      sugarPer100g: d('sugars_100g'),
    );
  }
}
