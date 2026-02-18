import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/exercise_model.dart';
import '../../data/providers/workout_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CreateWorkoutScreen extends StatefulWidget {
  final String? gymId;
  final String? memberId;

  const CreateWorkoutScreen({
    Key? key,
    this.gymId,
    this.memberId,
  }) : super(key: key);

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
  List<Map<String, dynamic>> _customWarmupExercises = [];
  int _currentDayIndex = 0;
  
  String _selectedCategory = 'All';
  String _selectedEquipment = 'All';
  final List<String> _categories = ['All', 'Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core'];
  final List<String> _equipmentTypes = ['All', 'Barbell', 'Dumbbell', 'Bodyweight', 'Machine'];

  String _selectedDifficulty = 'Intermediate';
  final List<String> _difficulties = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
    // Initialize days list
    for (int i = 0; i < _numberOfDays; i++) {
      _days.add({'name': 'Day ${i + 1}', 'exercises': []});
    }
  }



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
    final progress = (_currentStep + 1) / (_numberOfDays + 2);

    // Safety check for hot reload or initialization issues
    if (_days.isEmpty && _numberOfDays > 0) {
      for (int i = 0; i < _numberOfDays; i++) {
        _days.add({'name': 'Day ${i + 1}', 'exercises': []});
      }
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Iconsax.arrow_left_2, color: textColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentStep == 0 ? "Create Workout" : (_currentStep == 1 ? "Warmup Config" : "Day ${_currentStep - 1}"),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "${_currentStep + 1}/${_numberOfDays + 2}",
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            
            // Main Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildSetupCard(isDark, textColor),
                  _buildWarmupConfigCard(isDark, textColor),
                  ...List.generate(_numberOfDays, (index) => _buildDayCard(index, isDark, textColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateDuration(int newDays) {
    setState(() {
      _numberOfDays = newDays;
      if (newDays > _days.length) {
        // Add new days
        for (int i = _days.length; i < newDays; i++) {
          _days.add({'name': 'Day ${i + 1}', 'exercises': []});
        }
      } else if (newDays < _days.length) {
        // Remove extra days
        _days.removeRange(newDays, _days.length);
      }
    });
  }

  Widget _buildSetupCard(bool isDark, Color textColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Workout Details',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure your training plan',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 32),

          // 1. Workout Name
          Text(
            "Name",
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _workoutNameController,
            style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: textColor),
            decoration: InputDecoration(
              hintText: "e.g. Upper Body Power",
              hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: Icon(Iconsax.edit_2, color: isDark ? Colors.white54 : Colors.black45, size: 20),
            ),
          ),

          const SizedBox(height: 24),

          // 2. Duration (Days)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Duration (Days)",
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              Text(
                "$_numberOfDays",
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00E676),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final days = index + 1;
                final isSelected = _numberOfDays == days;
                return GestureDetector(
                  onTap: () => _updateDuration(days),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00E676) : (isDark ? Colors.white24 : Colors.grey[300]!),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        "$days",
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.black : textColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // 3. Difficulty
          Text(
            "Difficulty Level",
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
            ),
            child: Row(
              children: _difficulties.map((level) {
                final isSelected = _selectedDifficulty == level;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDifficulty = level),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1A1A1A) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ] : null,
                      ),
                      child: Center(
                        child: Text(
                          level,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? const Color(0xFF00E676) : (isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 40),

          // Start Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startBuilding,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text(
                'Continue to Exercises',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarmupConfigCard(bool isDark, Color textColor) {
    final provider = Provider.of<WorkoutProvider>(context);
    
    // Load warmups if not loaded
    if (provider.warmupExercises.isEmpty && !provider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.loadWarmupExercises();
      });
    }
    
    return Column(
      children: [
        // Warmup Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Warmup Configuration",
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _customWarmupExercises.isEmpty 
                    ? 'No custom exercises added. Default smart warmup will be used.' 
                    : '${_customWarmupExercises.length} custom warmup exercises added',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),

        // Filters (Reused logic)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: provider.searchWarmupExercises,
                  style: TextStyle(fontFamily: 'Outfit', color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search warmup exercises...',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontSize: 14),
                    prefixIcon: Icon(Iconsax.search_normal, color: isDark ? Colors.white54 : Colors.black45, size: 18),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Exercise List
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: provider.filteredWarmupExercises.length,
                  itemBuilder: (context, index) {
                    final exercise = provider.filteredWarmupExercises[index];
                    final isAdded = _customWarmupExercises.any((e) => e['name'] == exercise.name);
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isAdded) {
                            _customWarmupExercises.removeWhere((e) => e['name'] == exercise.name);
                          } else {
                            _customWarmupExercises.add({
                              'name': exercise.name,
                              'sets': 1,
                              'reps': '60s', // Default for warmup
                              'weight': 0.0,
                              'isWarmup': true,
                              'instructions': exercise.instructions,
                              'bodyPart': exercise.bodyPart,
                            });
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAdded ? const Color(0xFF00E676) : (isDark ? Colors.white10 : Colors.grey[200]!),
                            width: isAdded ? 2 : 1,
                          ),
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
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: CachedNetworkImage(
                                  imageUrl: exercise.imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (context, url) => Container(color: isDark ? Colors.grey[900] : Colors.grey[200]),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exercise.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    exercise.bodyPart,
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        
        // Navigation Buttons
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _currentStep--);
                    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Back", style: TextStyle(fontFamily: 'Outfit', color: textColor)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _currentStep++);
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("Next", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(int dayIndex, bool isDark, Color textColor) {
    final provider = Provider.of<WorkoutProvider>(context);
    final day = _days[dayIndex];
    final dayExercises = day['exercises'] as List;

    return Column(
      children: [
        // Day Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day['name'],
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dayExercises.length} exercises added',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildActionButton(
                        icon: Iconsax.copy,
                        onTap: () => _copyFromDayDialog(dayIndex),
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        icon: Iconsax.edit_2,
                        onTap: () => _renameDayDialog(dayIndex),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: provider.searchExercises,
                  style: TextStyle(fontFamily: 'Outfit', color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search exercises...',
                    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontSize: 14),
                    prefixIcon: Icon(Iconsax.search_normal, color: isDark ? Colors.white54 : Colors.black45, size: 18),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Equipment Dropdown
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedEquipment,
                    icon: Icon(Iconsax.arrow_down_1, size: 16, color: isDark ? Colors.white54 : Colors.black45),
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    items: _equipmentTypes.map((String equipment) {
                      return DropdownMenuItem<String>(
                        value: equipment,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getEquipmentIcon(equipment),
                              size: 16,
                              color: _selectedEquipment == equipment ? const Color(0xFF00E676) : (isDark ? Colors.white54 : Colors.black45),
                            ),
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
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Category Filter
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00E676) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF00E676) : (isDark ? Colors.white24 : Colors.grey[300]!),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      category,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.black : textColor,
                      ),
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
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: provider.filteredExercises.length,
                  itemBuilder: (context, index) {
                    final exercise = provider.filteredExercises[index];
                    final isAdded = dayExercises.any((e) => e['name'] == exercise.name);
                    final exerciseData = isAdded 
                        ? dayExercises.firstWhere((e) => e['name'] == exercise.name)
                        : null;
                    final isWarmup = exerciseData?['isWarmup'] ?? false;

                    return GestureDetector(
                      onTap: () => _toggleDayExercise(dayIndex, exercise, isAdded),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isAdded 
                                ? const Color(0xFF00E676) 
                                : (isDark ? Colors.white10 : Colors.grey[200]!),
                            width: isAdded ? 2 : 1,
                          ),
                          boxShadow: isAdded ? [
                            BoxShadow(
                              color: const Color(0xFF00E676).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ] : null,
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
                                    // Info Button (Bottom Right)
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () => _showExerciseDetails(exercise),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.6),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white24, width: 1),
                                          ),
                                          child: const Icon(Iconsax.info_circle, color: Colors.white, size: 16),
                                        ),
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
    // _currentStep includes Setup (0) and Warmup (1), so Day 1 is 2.
    // We want to allow going up to the last day.
    // Last page index is _numberOfDays + 1.
    if (_currentStep < _numberOfDays + 1) {
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

                  const SizedBox(height: 20),
                  
                  // Sets Control
                  
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
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '0.0',
                            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          onChanged: (value) => weight = value,
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
                            'weight': weight,
                          });
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Add to Workout',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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

  void _showExerciseDetails(Exercise exercise) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: exercise.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: exercise.imageUrl,
                              height: 250,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(
                                height: 250,
                                color: isDark ? Colors.white10 : Colors.grey[200],
                                child: const Icon(Iconsax.activity, size: 50, color: Color(0xFF00E676)),
                              ),
                            )
                          : Container(
                              height: 250,
                              color: isDark ? Colors.white10 : Colors.grey[200],
                              child: const Icon(Iconsax.activity, size: 50, color: Color(0xFF00E676)),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    Text(
                      exercise.name,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tags
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDetailTag(exercise.bodyPart, Iconsax.user, isDark),
                        _buildDetailTag(exercise.equipment, Iconsax.weight_1, isDark),
                        if (exercise.target.isNotEmpty)
                          _buildDetailTag(exercise.target, Iconsax.gps, isDark),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Instructions
                    Text(
                      'Instructions',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (exercise.steps.isNotEmpty)
                      ...exercise.steps.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${entry.key + 1}',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF00E676),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 14,
                                    height: 1.5,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList()
                    else
                      Text(
                        'No instructions available.',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTag(String text, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF00E676)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
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

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey[300]!,
          ),
        ),
        child: Icon(
          icon,
          color: isDark ? Colors.white70 : Colors.black87,
          size: 20,
        ),
      ),
    );
  }

  Future<void> _saveWorkout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Validation: Ensure at least one exercise is added
      bool hasExercises = false;
      for (var day in _days) {
        if ((day['exercises'] as List).isNotEmpty) {
          hasExercises = true;
          break;
        }
      }

      if (!hasExercises) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please add at least one exercise to your workout.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Validation: Ensure at least one exercise is added
      int totalExercises = 0;
      for (var day in _days) {
        totalExercises += (day['exercises'] as List).length;
      }

      if (totalExercises == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please add at least one exercise to your workout.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }




      String? gymId = widget.gymId;
      String? memberId = widget.memberId ?? user.uid;

      if (gymId == null || gymId.isEmpty) {
        // Try member_index
        final indexDoc = await FirebaseFirestore.instance.collection('member_index').doc(user.uid).get();
        if (indexDoc.exists) {
          gymId = indexDoc.data()?['gymId'];
        }
      }

      if (gymId == null || gymId.isEmpty) {
        // Try users collection as last resort
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        gymId = userDoc.data()?['gymId'];
      }

      if (gymId == null || gymId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Gym ID not found. Please try again later.')));
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
          'difficulty': _selectedDifficulty,
          'customWarmup': _customWarmupExercises, // Save custom warmups
          'plan': {'schedule': schedule},
          'createdAt': FieldValue.serverTimestamp(),
        };
      } else {
        workoutData = {
          'name': _workoutNameController.text.trim(),
          'exercises': _days[0]['exercises'],
          'source': 'custom',
          'difficulty': _selectedDifficulty,
          'createdAt': FieldValue.serverTimestamp(),
        };
      }

      await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
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
