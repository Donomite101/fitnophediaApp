import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../models/nutrition_models.dart';
import '../repository/nutrition_repository.dart';

class ManualMealCreateScreen extends StatefulWidget {
  final String gymId;
  final String memberId;
  final DateTime selectedDate;

  const ManualMealCreateScreen({
    super.key,
    required this.gymId,
    required this.memberId,
    required this.selectedDate,
  });

  @override
  State<ManualMealCreateScreen> createState() => _ManualMealCreateScreenState();
}

class _MealDraft {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController caloriesController = TextEditingController();
  final TextEditingController proteinController = TextEditingController();
  final TextEditingController carbsController = TextEditingController();
  final TextEditingController fatController = TextEditingController();
  final TextEditingController sugarController = TextEditingController();
  String type;
  TimeOfDay time;
  bool isExpanded = true;

  _MealDraft({
    this.type = 'breakfast',
    required this.time,
  });

  void dispose() {
    nameController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatController.dispose();
    sugarController.dispose();
  }
}

class _ManualMealCreateScreenState extends State<ManualMealCreateScreen> {
  late final NutritionRepository _repo;
  
  final List<_MealDraft> _meals = [];
  final List<bool> _selectedDays = List.generate(7, (index) => false);
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _mealTypes = [
    {'value': 'breakfast', 'label': 'Breakfast', 'icon': Iconsax.coffee, 'color': const Color(0xFFFF9500)},
    {'value': 'lunch', 'label': 'Lunch', 'icon': Iconsax.cake, 'color': const Color(0xFF34C759)},
    {'value': 'dinner', 'label': 'Dinner', 'icon': Iconsax.cup, 'color': const Color(0xFF5856D6)},
    {'value': 'snack', 'label': 'Snack', 'icon': Iconsax.star, 'color': const Color(0xFFFF3B30)},
  ];

  final List<String> _weekDayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _repo = NutritionRepository(
      gymId: widget.gymId,
      memberId: widget.memberId,
    );
    
    // Initialize with default meals for a full day schedule
    _meals.add(_MealDraft(type: 'breakfast', time: const TimeOfDay(hour: 8, minute: 0)));
    _meals.add(_MealDraft(type: 'lunch', time: const TimeOfDay(hour: 13, minute: 0)));
    _meals.add(_MealDraft(type: 'dinner', time: const TimeOfDay(hour: 20, minute: 0)));
    
    // Default to the day that was tapped in the calendar
    _selectedDays[widget.selectedDate.weekday - 1] = true;
  }

  @override
  void dispose() {
    for (var meal in _meals) {
      meal.dispose();
    }
    super.dispose();
  }

  void _addMeal() {
    setState(() {
      _meals.add(_MealDraft(
        type: 'snack',
        time: TimeOfDay.now(),
      ));
    });
  }

  void _removeMeal(int index) {
    if (_meals.length <= 1) return;
    setState(() {
      _meals[index].dispose();
      _meals.removeAt(index);
    });
  }

  Future<void> _savePlan() async {
    bool hasValidMeal = false;
    for (var draft in _meals) {
      if (draft.nameController.text.trim().isNotEmpty) {
        hasValidMeal = true;
        break;
      }
    }

    if (!hasValidMeal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one meal name')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      List<DateTime> targetDates = [];
      final now = widget.selectedDate;
      // Start of current week (Monday)
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      
      for (int i = 0; i < 7; i++) {
        if (_selectedDays[i]) {
          targetDates.add(startOfWeek.add(Duration(days: i)));
        }
      }

      if (targetDates.isEmpty) targetDates.add(widget.selectedDate);

      for (final date in targetDates) {
        for (final draft in _meals) {
          if (draft.nameController.text.trim().isEmpty) continue;

          final timeString = '${draft.time.hour.toString().padLeft(2, '0')}:${draft.time.minute.toString().padLeft(2, '0')}';
          
          final meal = NutritionMeal(
            mealId: '${DateTime.now().millisecondsSinceEpoch}_${_meals.indexOf(draft)}',
            name: draft.nameController.text.trim(),
            timeOfDay: timeString,
            createdAt: DateTime.now(),
            totalCalories: double.tryParse(draft.caloriesController.text) ?? 0.0,
            totalProtein: double.tryParse(draft.proteinController.text) ?? 0.0,
            totalCarbs: double.tryParse(draft.carbsController.text) ?? 0.0,
            totalFat: double.tryParse(draft.fatController.text) ?? 0.0,
            totalSugar: double.tryParse(draft.sugarController.text) ?? 0.0,
            items: [],
            isConsumed: false,
          );

          await _repo.saveMeal(date, meal);
        }
        await _repo.recalculateSummary(date);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meal plan saved for ${targetDates.length} day(s)'),
            backgroundColor: const Color(0xFF00C853),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF5F5F5);
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manually Create Plan',
          style: TextStyle(family: 'Outfit', fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('REPEAT FOR DAYS'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (index) {
                   final isSelected = _selectedDays[index];
                   return GestureDetector(
                     onTap: () => setState(() => _selectedDays[index] = !isSelected),
                     child: AnimatedContainer(
                       duration: const Duration(milliseconds: 200),
                       width: 40,
                       height: 40,
                       alignment: Alignment.center,
                       decoration: BoxDecoration(
                         color: isSelected ? const Color(0xFF00C853) : Colors.transparent,
                         shape: BoxShape.circle,
                       ),
                       child: Text(
                         _weekDayNames[index].substring(0, 1),
                         style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
                       ),
                     ),
                   );
                }),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionLabel('DAILY MEALS'),
                TextButton.icon(
                  onPressed: _addMeal,
                  icon: const Icon(Iconsax.add_circle, size: 18, color: Color(0xFF00C853)),
                  label: const Text('Add Meal', style: TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _meals.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _buildMealCard(index, _meals[index], isDark, cardBg, textColor),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _savePlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  shadowColor: const Color(0xFF00C853).withOpacity(0.4),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Iconsax.tick_circle, size: 24),
                          SizedBox(width: 12),
                          Text('Save Plan', style: TextStyle(family: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(int index, _MealDraft draft, bool isDark, Color cardBg, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => draft.isExpanded = !draft.isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                   Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: const Color(0xFF00C853).withOpacity(0.1), shape: BoxShape.circle),
                    child: Center(child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      draft.nameController.text.isEmpty ? 'New Meal' : draft.nameController.text,
                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: textColor),
                    ),
                  ),
                  if (_meals.length > 1)
                    IconButton(icon: const Icon(Iconsax.trash, color: Colors.red, size: 16), onPressed: () => _removeMeal(index)),
                  Icon(draft.isExpanded ? Iconsax.arrow_up_1 : Iconsax.arrow_down_1, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (draft.isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildTextField(
                    controller: draft.nameController,
                    hint: 'Meal Name',
                    isDark: isDark,
                    icon: Iconsax.edit,
                    onChanged: (v) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildMealTypeDropdown(draft, isDark, textColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTimeSelector(context, draft, isDark, textColor)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildNutritionGrid(draft, isDark, textColor),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMealTypeDropdown(_MealDraft draft, bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: draft.type,
          isExpanded: true,
          icon: const Icon(Iconsax.arrow_down_1, size: 14),
          items: _mealTypes.map((type) => DropdownMenuItem(
            value: type['value'],
            child: Row(
              children: [
                Icon(type['icon'], size: 14, color: type['color']),
                const SizedBox(width: 8),
                Text(type['label'], style: TextStyle(fontSize: 13, color: textColor)),
              ],
            ),
          )).toList(),
          onChanged: (v) => v != null ? setState(() => draft.type = v) : null,
        ),
      ),
    );
  }

  Widget _buildTimeSelector(BuildContext context, _MealDraft draft, bool isDark, Color textColor) {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(context: context, initialTime: draft.time);
        if (time != null) setState(() => draft.time = time);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Iconsax.clock, size: 14, color: Colors.blue),
            const SizedBox(width: 8),
            Text(draft.time.format(context), style: TextStyle(fontSize: 13, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionGrid(_MealDraft draft, bool isDark, Color textColor) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMacroMiniField('Calories', draft.caloriesController, Colors.green, isDark, suffix: ' kcal')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMacroMiniField('Protein', draft.proteinController, Colors.blue, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMacroMiniField('Carbs', draft.carbsController, Colors.orange, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _buildMacroMiniField('Fat', draft.fatController, Colors.purple, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroMiniField(String label, TextEditingController controller, Color color, bool isDark, {String suffix = 'g'}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color)),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              isDense: true,
              hintText: '0',
              border: InputBorder.none,
              suffixText: suffix,
              suffixStyle: const TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(family: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    required IconData icon,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(family: 'Outfit', fontSize: 15, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: const Color(0xFF00C853), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}
