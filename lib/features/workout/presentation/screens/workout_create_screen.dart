import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/exercise_model.dart';
import '../../data/providers/workout_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CreateWorkoutScreen extends StatefulWidget {
  const CreateWorkoutScreen({Key? key}) : super(key: key);

  @override
  State<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _workoutNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  int _currentStep = 0;
  int _numberOfDays = 1;
  List<Map<String, dynamic>> _days = [];
  int _currentDayIndex = 0;
  
  String _selectedCategory = 'All';
  String _selectedEquipment = 'All';
  final List<String> _categories = ['All', 'Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core'];
  final List<String> _equipmentTypes = ['All', 'Barbell', 'Dumbbell', 'Bodyweight', 'Machine'];

  @override
  void dispose() {
    _pageController.dispose();
    _workoutNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: Icon(Iconsax.arrow_left, color: textColor),
                onPressed: _previousStep,
              )
            : IconButton(
                icon: Icon(Iconsax.close_square, color: textColor),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          _currentStep == 0 ? 'Create Workout' : 'Build Your Plan',
          style: TextStyle(fontFamily: 'Outfit', color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Step Indicator
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Step ${_currentStep + 1}/${_numberOfDays + 1}',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 13,
                  color: const Color(0xFF00E676),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildSetupCard(isDark, textColor),
          ..._days.asMap().entries.map((entry) {
            return _buildDayCard(entry.key, isDark, textColor);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSetupCard(bool isDark, Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Let\'s Create Your Workout',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by giving your workout a name and choosing how many days',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 32),

          // Workout Name Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.edit, color: Color(0xFF00E676), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Workout Name',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _workoutNameController,
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'e.g., Upper/Lower Split, PPL Program',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Number of Days Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.calendar, color: Color(0xFF00E676), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Number of Days',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Day Counter
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$_numberOfDays ${_numberOfDays == 1 ? "Day" : "Days"} Per Week',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _numberOfDays > 1 ? () => setState(() => _numberOfDays--) : null,
                          icon: const Icon(Iconsax.minus_cirlce),
                          color: const Color(0xFF00E676),
                          iconSize: 32,
                        ),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '$_numberOfDays',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00E676),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _numberOfDays < 7 ? () => setState(() => _numberOfDays++) : null,
                          icon: const Icon(Iconsax.add_circle),
                          color: const Color(0xFF00E676),
                          iconSize: 32,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Quick Selectors
                Wrap(
                  spacing: 8,
                  children: [
                    _buildQuickDayChip(3, '3 Days'),
                    _buildQuickDayChip(4, '4 Days'),
                    _buildQuickDayChip(5, '5 Days'),
                    _buildQuickDayChip(6, '6 Days'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Continue Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startBuilding,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'START BUILDING',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Iconsax.arrow_right_3, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDayChip(int days, String label) {
    final isSelected = _numberOfDays == days;
    return GestureDetector(
      onTap: () => setState(() => _numberOfDays = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E676) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildDayCard(int dayIndex, bool isDark, Color textColor) {
    final provider = Provider.of<WorkoutProvider>(context);
    final day = _days[dayIndex];
    final dayExercises = day['exercises'] as List;

    return Column(
      children: [
        // Day Header
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00E676), Color(0xFF00D9A3)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day['name'],
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dayExercises.length} exercises added',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Copy from Day Button
                  GestureDetector(
                    onTap: () => _copyFromDayDialog(dayIndex),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.copy, color: Colors.black, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Rename Button
                  GestureDetector(
                    onTap: () => _renameDayDialog(dayIndex),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.edit_2, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: provider.searchExercises,
                  style: TextStyle(fontFamily: 'Outfit', color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontSize: 13),
                    prefixIcon: const Icon(Iconsax.search_normal, color: Color(0xFF00E676), size: 18),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Equipment Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: _selectedEquipment,
                  icon: const Icon(Iconsax.arrow_down_1, size: 16, color: Color(0xFF00E676)),
                  underline: const SizedBox(),
                  isDense: true,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  items: _equipmentTypes.map((String equipment) {
                    return DropdownMenuItem<String>(
                      value: equipment,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getEquipmentIcon(equipment), size: 16, color: const Color(0xFF00E676)),
                          const SizedBox(width: 8),
                          Text(equipment),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedEquipment = newValue);
                      _applyEquipmentFilter(provider);
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Category Filter
        SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = _selectedCategory == category;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedCategory = category);
                  if (category == 'All') {
                    provider.resetFilters();
                  } else {
                    provider.filterByBodyPart(category);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00E676) : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : textColor.withOpacity(0.7),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Exercise List
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: provider.filteredExercises.length,
                  itemBuilder: (context, index) {
                    final exercise = provider.filteredExercises[index];
                    final isAdded = dayExercises.any((e) => e['name'] == exercise.name);
                    final exerciseData = isAdded 
                        ? dayExercises.firstWhere((e) => e['name'] == exercise.name)
                        : null;
                    final isWarmup = exerciseData?['isWarmup'] ?? false;

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isAdded ? const Color(0xFF00E676) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            // Dismiss keyboard first
                            FocusScope.of(context).unfocus();
                            // Small delay to ensure keyboard is dismissed before showing bottom sheet
                            Future.delayed(const Duration(milliseconds: 100), () {
                              _toggleDayExercise(dayIndex, exercise, isAdded);
                            });
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Large Image
                              Container(
                                height: 120,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                  color: const Color(0xFF00E676).withOpacity(0.1),
                                ),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                      child: exercise.imageUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: exercise.imageUrl!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              errorWidget: (context, url, error) =>
                                                  const Center(child: Icon(Iconsax.activity, color: Color(0xFF00E676), size: 32)),
                                            )
                                          : const Center(child: Icon(Iconsax.activity, color: Color(0xFF00E676), size: 32)),
                                    ),
                                    // Gradient Overlay
                                    if (exercise.imageUrl != null)
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.3),
                                            ],
                                          ),
                                        ),
                                      ),
                                    // Warmup Badge (Top Left)
                                    if (isWarmup)
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Iconsax.flash_15, color: Colors.white, size: 14),
                                        ),
                                      ),
                                    // Checkmark Badge (Top Right)
                                    if (isAdded)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF00E676),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Iconsax.tick_circle5, color: Colors.black, size: 16),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Exercise Name
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        exercise.name,
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: textColor,
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (!isAdded) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00E676).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            exercise.bodyPart ?? 'Exercise',
                                            style: const TextStyle(
                                              fontFamily: 'Outfit',
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF00E676),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Bottom Navigation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2)),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                if (dayIndex < _days.length - 1)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _nextDay,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFF00E676), width: 2),
                      ),
                      child: const Text(
                        'NEXT DAY',
                        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                      ),
                    ),
                  ),
                if (dayIndex == _days.length - 1)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveWorkout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'SAVE WORKOUT',
                        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _startBuilding() {
    if (_workoutNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a workout name')),
      );
      return;
    }

    setState(() {
      _days = List.generate(_numberOfDays, (index) {
        return {
          'name': 'Day ${index + 1}',
          'exercises': [],
        };
      });
      _currentStep = 1;
    });

    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextDay() {
    if (_currentStep < _days.length) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleDayExercise(int dayIndex, Exercise exercise, bool isAdded) {
    if (isAdded) {
      // Remove exercise
      setState(() {
        final dayExercises = _days[dayIndex]['exercises'] as List;
        dayExercises.removeWhere((e) => e['name'] == exercise.name);
      });
    } else {
      // Show configuration sheet
      _showExerciseConfig(dayIndex, exercise);
    }
  }

  void _showExerciseConfig(int dayIndex, Exercise exercise) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    
    int sets = 3;
    int reps = 10;
    String weight = '';
    bool isWarmup = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Title
                  Text(
                    'Add Exercise',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    exercise.name,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // Warmup Toggle
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isWarmup ? Colors.orange.withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isWarmup ? Colors.orange : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.flash_15,
                          color: isWarmup ? Colors.orange : (isDark ? Colors.white60 : Colors.black54),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Warmup Exercise',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Lower weight to prepare',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isWarmup,
                          onChanged: (value) => setSheetState(() => isWarmup = value),
                          activeColor: Colors.orange,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Sets Control
                  Row(
                    children: [
                      Icon(Iconsax.layer, color: const Color(0xFF00E676), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sets',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => setSheetState(() => sets = (sets - 1).clamp(1, 999)),
                              icon: const Icon(Iconsax.minus, size: 18),
                              color: const Color(0xFF00E676),
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 40),
                              child: Text(
                                sets.toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setSheetState(() => sets++),
                              icon: const Icon(Iconsax.add, size: 18),
                              color: const Color(0xFF00E676),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Reps Control
                  Row(
                    children: [
                      Icon(Iconsax.repeate_music, color: const Color(0xFF00E676), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Reps',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => setSheetState(() => reps = (reps - 1).clamp(1, 999)),
                              icon: const Icon(Iconsax.minus, size: 18),
                              color: const Color(0xFF00E676),
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 40),
                              child: Text(
                                reps.toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setSheetState(() => reps++),
                              icon: const Icon(Iconsax.add, size: 18),
                              color: const Color(0xFF00E676),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Weight Control
                  Row(
                    children: [
                      Icon(Iconsax.weight_1, color: const Color(0xFF00E676), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Weight (kg)',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                      ),
                      Container(
                        width: 120,
                        child: TextField(
                          controller: TextEditingController(text: weight),
                          onChanged: (value) => weight = value,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Optional',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white30 : Colors.black26,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Add Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          final dayExercises = _days[dayIndex]['exercises'] as List;
                          dayExercises.add({
                            'name': exercise.name,
                            'sets': sets,
                            'reps': reps,
                            'weight': weight.isEmpty ? '' : weight,
                            'bodyPart': exercise.bodyPart,
                            'isWarmup': isWarmup,
                          });
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${exercise.name} added!'),
                            backgroundColor: const Color(0xFF00E676),
                            duration: const Duration(milliseconds: 800),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'ADD EXERCISE',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _applyEquipmentFilter(WorkoutProvider provider) {
    if (_selectedEquipment == 'All') {
      if (_selectedCategory == 'All') {
        provider.resetFilters();
      } else {
        provider.filterByBodyPart(_selectedCategory);
      }
    } else {
      // Get base filtered list
      List<Exercise> filtered = _selectedCategory == 'All' 
          ? provider.exercises 
          : provider.exercises.where((e) {
              final bodyPart = e.bodyPart?.toLowerCase() ?? '';
              return bodyPart.contains(_selectedCategory.toLowerCase());
            }).toList();

      // Apply equipment filter
      filtered = filtered.where((e) {
        final equipment = e.equipment?.toLowerCase() ?? '';
        return equipment.contains(_selectedEquipment.toLowerCase());
      }).toList();

      provider.setFilteredExercises(filtered);
    }
  }

  IconData _getEquipmentIcon(String equipment) {
    switch (equipment.toLowerCase()) {
      case 'barbell':
        return Iconsax.weight;
      case 'dumbbell':
        return Iconsax.weight_1;
      case 'machine':
        return Iconsax.cpu;
      case 'cable':
        return Iconsax.link;
      case 'bodyweight':
        return Iconsax.man;
      case 'band':
        return Iconsax.unlimited;
      default:
        return Iconsax.filter;
    }
  }

  void _copyFromDayDialog(int targetDayIndex) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        title: Row(
          children: [
            const Icon(Iconsax.copy, color: Color(0xFF00E676), size: 24),
            const SizedBox(width: 12),
            Text(
              'Copy Exercises',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select which day to copy from:',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_days.length, (index) {
              if (index == targetDayIndex) return const SizedBox.shrink();
              
              final day = _days[index];
              final exerciseCount = (day['exercises'] as List).length;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00E676).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Iconsax.clipboard_text, color: Color(0xFF00E676), size: 20),
                  ),
                  title: Text(
                    day['name'],
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    '$exerciseCount exercise${exerciseCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  trailing: const Icon(Iconsax.arrow_right_3, color: Color(0xFF00E676), size: 18),
                  onTap: () {
                    _copyExercises(index, targetDayIndex);
                    Navigator.pop(context);
                  },
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
  }

  void _copyExercises(int fromDayIndex, int toDayIndex) {
    final fromExercises = List.from(_days[fromDayIndex]['exercises'] as List);
    
    setState(() {
      // Copy all exercises with their configurations
      _days[toDayIndex]['exercises'] = fromExercises.map((exercise) {
        return Map<String, dynamic>.from(exercise);
      }).toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied ${fromExercises.length} exercises from ${_days[fromDayIndex]['name']}!'),
        backgroundColor: const Color(0xFF00E676),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _renameDayDialog(int index) {
    final controller = TextEditingController(text: _days[index]['name']);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        title: const Text('Rename Day', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'e.g., Push Day, Pull Day',
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _days[index]['name'] = controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
            child: const Text('Rename', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWorkout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final gymId = userDoc.data()?['gymId'];

      if (gymId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Gym ID not found')));
        }
        return;
      }

      Map<String, dynamic> workoutData;

      if (_numberOfDays > 1) {
        final schedule = _days.map((day) {
          return {
            'day': day['name'],
            'focus': (day['exercises'] as List).isNotEmpty 
                ? ((day['exercises'] as List)[0]['bodyPart'] ?? 'Mixed')
                : 'Rest',
            'exercises': day['exercises'],
          };
        }).toList();

        workoutData = {
          'planName': _workoutNameController.text.trim(),
          'source': 'custom',
          'plan': {'schedule': schedule},
          'createdAt': FieldValue.serverTimestamp(),
        };
      } else {
        workoutData = {
          'name': _workoutNameController.text.trim(),
          'exercises': _days[0]['exercises'],
          'source': 'custom',
          'createdAt': FieldValue.serverTimestamp(),
        };
      }

      await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(user.uid)
          .collection('workout_plans')
          .add(workoutData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workout saved successfully! 🎉'), backgroundColor: Color(0xFF00E676)),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
