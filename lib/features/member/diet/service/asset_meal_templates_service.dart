import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/nutrition_models.dart';

class AssetMealTemplatesService {
  final String path;

  AssetMealTemplatesService({
    this.path = 'assets/nutrition/meal_templates.json',
  });

  Future<List<MealTemplate>> loadTemplates() async {
    final jsonStr = await rootBundle.loadString(path);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final list = data['templates'] as List<dynamic>? ?? [];
    return list
        .map((e) => MealTemplate.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
