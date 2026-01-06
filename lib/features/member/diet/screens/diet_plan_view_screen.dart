import 'package:flutter/material.dart';

import '../models/nutrition_models.dart';
import '../repository/nutrition_repository.dart';



class DietPlanViewScreen extends StatefulWidget {
  final String gymId;
  final String memberId;
  final DateTime date;

  const DietPlanViewScreen({
    super.key,
    required this.gymId,
    required this.memberId,
    required this.date,
  });

  @override
  State<DietPlanViewScreen> createState() => _DietPlanViewScreenState();
}

class _DietPlanViewScreenState extends State<DietPlanViewScreen> {
  late final NutritionRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = NutritionRepository(
      gymId: widget.gymId,
      memberId: widget.memberId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = widget.date;
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Diet Plan • $dateLabel'),
      ),
      body: Column(
        children: [
          _buildSummaryCard(theme),
          const SizedBox(height: 8),
          Expanded(child: _buildMealsDetailList(theme)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return StreamBuilder<DailyNutritionSummary?>(
      stream: _repo.listenSummary(widget.date),
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final totalCalories = summary?.totalCalories ?? 0;
        final protein = summary?.totalProtein ?? 0;
        final carbs = summary?.totalCarbs ?? 0;
        final fat = summary?.totalFat ?? 0;
        final sugar = summary?.totalSugar ?? 0;
        final waterMl = summary?.waterMl ?? 0;
        final waterGoalMl = summary?.waterGoalMl ?? 2500;

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Summary',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text('Calories: ${totalCalories.toStringAsFixed(0)} kcal'),
                    Text('Protein: ${protein.toStringAsFixed(1)} g'),
                    Text('Carbs: ${carbs.toStringAsFixed(1)} g'),
                    Text('Fat: ${fat.toStringAsFixed(1)} g'),
                    Text('Sugar: ${sugar.toStringAsFixed(1)} g'),
                    Text('Water: $waterMl / $waterGoalMl ml'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMealsDetailList(ThemeData theme) {
    return StreamBuilder<List<NutritionMeal>>(
      stream: _repo.listenMeals(widget.date),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final meals = snapshot.data ?? [];
        if (meals.isEmpty) {
          return const Center(
            child: Text('No meals planned for this day.'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: meals.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final meal = meals[index];
            return _buildMealCard(theme, meal);
          },
        );
      },
    );
  }

  Widget _buildMealCard(ThemeData theme, NutritionMeal meal) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          meal.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${meal.timeOfDay} • ${meal.totalCalories.toStringAsFixed(0)} kcal',
        ),
        childrenPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Row(
            children: [
              _macroChip('Protein', '${meal.totalProtein.toStringAsFixed(1)} g'),
              const SizedBox(width: 8),
              _macroChip('Carbs', '${meal.totalCarbs.toStringAsFixed(1)} g'),
              const SizedBox(width: 8),
              _macroChip('Fat', '${meal.totalFat.toStringAsFixed(1)} g'),
              const SizedBox(width: 8),
              _macroChip('Sugar', '${meal.totalSugar.toStringAsFixed(1)} g'),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Items',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (meal.items.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No item details for this meal.'),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: meal.items.map((item) {
                final qty = item.quantity > 0
                    ? '${item.quantity} ${item.unit} • '
                    : '';
                final kcal = item.calories > 0
                    ? '${item.calories.toStringAsFixed(0)} kcal'
                    : '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '$qty${item.name}${kcal.isNotEmpty ? ' • $kcal' : ''}',
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _macroChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}
