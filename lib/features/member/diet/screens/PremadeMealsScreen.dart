import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/nutrition_models.dart';
import '../repository/nutrition_repository.dart';
import '../service/asset_meal_templates_service.dart';


class PremadeMealsScreen extends StatefulWidget {
  final String gymId;    // still keep to reuse NutritionRepository
  final String memberId;
  final DateTime date;

  const PremadeMealsScreen({
    super.key,
    required this.gymId,
    required this.memberId,
    required this.date,
  });

  @override
  State<PremadeMealsScreen> createState() => _PremadeMealsScreenState();
}

class _PremadeMealsScreenState extends State<PremadeMealsScreen> {
  late final NutritionRepository _nutritionRepo;
  late final AssetMealTemplatesService _assetService;

  bool _loading = true;
  List<MealTemplate> _templates = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _nutritionRepo = NutritionRepository(
      gymId: widget.gymId,
      memberId: widget.memberId,
    );
    _assetService = AssetMealTemplatesService();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final list = await _assetService.loadTemplates();
      setState(() {
        _templates = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose Premade Meal')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose Premade Meal')),
        body: Center(child: Text('Failed to load meals: $_error')),
      );
    }

    if (_templates.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Choose Premade Meal')),
        body: const Center(child: Text('No premade meals available.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Premade Meal'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _templates.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final t = _templates[index];
          return Card(
            child: ListTile(
              title: Text(t.name),
              subtitle: Text(
                '${t.defaultTime} • ${t.calories.toStringAsFixed(0)} kcal',
              ),
              onTap: () => _onTemplateSelected(t),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onTemplateSelected(MealTemplate t) async {
    final meal = NutritionMeal(
      mealId: const Uuid().v4(),
      name: t.name,
      timeOfDay: t.defaultTime,
      createdAt: DateTime.now(),
      totalCalories: t.calories,
      totalProtein: t.protein,
      totalCarbs: t.carbs,
      totalFat: t.fat,
      totalSugar: t.sugar,
      items: t.ingredients
          .map(
            (ing) => NutritionItem(
          name: ing,
          quantity: 0,
          unit: '',
          calories: 0,
          protein: 0,
          carbs: 0,
          fat: 0,
          sugar: 0,
        ),
      )
          .toList(),
    );

    await _nutritionRepo.saveMeal(widget.date, meal);
    await _nutritionRepo.recalculateSummary(widget.date);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }
}
