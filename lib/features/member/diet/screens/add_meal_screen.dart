import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/nutrition_models.dart';
import '../repository/nutrition_repository.dart';
import '../service/food_barcode_service.dart';
import '../service/nutrition_api_service.dart';
import '../screens/barcode_scan_screen.dart'; // adjust path if needed

class AddMealScreen extends StatefulWidget {
  final String gymId;
  final String memberId;
  final DateTime date;
  final String? existingMealId; // null = new meal

  const AddMealScreen({
    super.key,
    required this.gymId,
    required this.memberId,
    required this.date,
    this.existingMealId,
  });

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  late final NutritionRepository _repo;
  late final NutritionApiService _api;

  final _formKey = GlobalKey<FormState>();

  final _mealNameController = TextEditingController(text: 'Meal');
  final _timeController = TextEditingController();
  final List<TextEditingController> _ingredientControllers = [];

  bool _loading = false;
  double _calories = 0, _protein = 0, _carbs = 0, _fat = 0, _sugar = 0;

  @override
  void initState() {
    super.initState();
    _repo = NutritionRepository(
      gymId: widget.gymId,
      memberId: widget.memberId,
    );

    _api = NutritionApiService();

    final now = TimeOfDay.fromDateTime(DateTime.now());
    _timeController.text =
    '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    _addIngredientField(); // start with one line

    // TODO: if editing existing meal, load it here (not implemented yet)
  }

  @override
  void dispose() {
    _mealNameController.dispose();
    _timeController.dispose();
    for (final c in _ingredientControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Meal'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Meal info', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mealNameController,
                decoration: const InputDecoration(
                  labelText: 'Meal name',
                  hintText: 'e.g. Breakfast, Post-workout',
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter meal name' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _timeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Time',
                      ),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Ingredients (one per line)',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._buildIngredientFields(),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addIngredientField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add ingredient'),
                ),
              ),
              const SizedBox(height: 8),

              // Scan helpers row
              Row(
                children: [
                  IconButton(
                    onPressed: _onScanBarcode,
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Scan product barcode',
                  ),
                  // Placeholders for future:
                  // IconButton(
                  //   onPressed: _onScanLabel,
                  //   icon: const Icon(Icons.document_scanner_outlined),
                  //   tooltip: 'Scan nutrition label',
                  // ),
                  // IconButton(
                  //   onPressed: _onVoiceInput,
                  //   icon: const Icon(Icons.mic_none),
                  //   tooltip: 'Speak ingredients',
                  // ),
                ],
              ),

              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loading ? null : _calculateNutrition,
                icon: _loading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.analytics_outlined),
                label: const Text('Calculate nutrition with Edamam'),
              ),
              const SizedBox(height: 16),
              if (_calories > 0 || _loading)
                _buildNutritionSummaryCard(theme),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _saveMeal,
                  child: const Text('Save Meal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildIngredientFields() {
    return List.generate(_ingredientControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _ingredientControllers[index],
                decoration: InputDecoration(
                  labelText: 'Ingredient ${index + 1}',
                  hintText: 'e.g. 1 cup rice',
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter ingredient' : null,
              ),
            ),
            const SizedBox(width: 8),
            if (_ingredientControllers.length > 1)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _removeIngredientField(index),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildNutritionSummaryCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calculated Nutrition', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Calories: ${_calories.toStringAsFixed(0)} kcal'),
            Text('Protein: ${_protein.toStringAsFixed(1)} g'),
            Text('Carbs: ${_carbs.toStringAsFixed(1)} g'),
            Text('Fat: ${_fat.toStringAsFixed(1)} g'),
            Text('Sugar: ${_sugar.toStringAsFixed(1)} g'),
          ],
        ),
      ),
    );
  }

  void _addIngredientField() {
    setState(() {
      _ingredientControllers.add(TextEditingController());
    });
  }

  void _removeIngredientField(int index) {
    setState(() {
      _ingredientControllers.removeAt(index);
    });
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (picked != null) {
      _timeController.text =
      '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  final FoodBarcodeService _barcodeService = FoodBarcodeService();

  Future<void> _onScanBarcode() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScanScreen(),
      ),
    );

    if (!mounted || barcode == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final result = await _barcodeService.fetchByBarcode(barcode);

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No nutrition data found for $barcode')),
        );
        return;
      }

      // For now, assume 1 serving = 100g
      setState(() {
        _mealNameController.text = result.productName;
        _calories = result.caloriesPer100g;
        _protein = result.proteinPer100g;
        _carbs = result.carbsPer100g;
        _fat = result.fatPer100g;
        _sugar = result.sugarPer100g;

        if (_ingredientControllers.isEmpty) {
          _addIngredientField();
        }
        _ingredientControllers.first.text =
        '${result.productName} (100g, from barcode $barcode)';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded nutrition for ${result.productName}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Barcode lookup failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _calculateNutrition() async {
    if (!_formKey.currentState!.validate()) return;

    final ingredients = _ingredientControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one ingredient.')),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // ignore: avoid_print
      print('Analyzing ingredients: $ingredients');

      final result = await _api.analyzeIngredients(ingredients);

      setState(() {
        _calories = result.calories;
        _protein = result.protein;
        _carbs = result.carbs;
        _fat = result.fat;
        _sugar = result.sugar;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to analyze: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveMeal() async {
    if (!_formKey.currentState!.validate()) return;

    if (_calories == 0 &&
        _protein == 0 &&
        _carbs == 0 &&
        _fat == 0 &&
        _sugar == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please calculate nutrition before saving.'),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final mealId = widget.existingMealId ?? const Uuid().v4();

      final meal = NutritionMeal(
        mealId: mealId,
        name: _mealNameController.text.trim(),
        timeOfDay: _timeController.text.trim(),
        createdAt: DateTime.now(),
        totalCalories: _calories,
        totalProtein: _protein,
        totalCarbs: _carbs,
        totalFat: _fat,
        totalSugar: _sugar,
        items: _ingredientControllers
            .map(
              (c) => NutritionItem(
            name: c.text.trim(),
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

      await _repo.saveMeal(widget.date, meal);
      await _repo.recalculateSummary(widget.date);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save meal: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}
