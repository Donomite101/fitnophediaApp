import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/workout_provider.dart';
import '../widgets/exercise_card.dart';
import '../widgets/exercise_category_chip.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({Key? key}) : super(key: key);

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final TextEditingController _search = TextEditingController();
  String selectedCategory = "All";

  // Common categories (ensure these match your DB data for filtering to work)
  final List<String> _categories = [
    "All",
    "Chest",
    "Back",
    "Legs",
    "Arms",
    "Shoulders",
    "Core",
    "Cardio"
  ];

  @override
  void initState() {
    super.initState();
    // Re-load or just ensure loaded
    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    if (provider.exercises.isEmpty) {
      provider.loadExercises();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WorkoutProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: bgColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Exercise Library",
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),

      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey[200]!,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _search,
                onChanged: provider.searchExercises,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: textColor,
                ),
                decoration: InputDecoration(
                  hintText: "Search exercises...",
                  hintStyle: TextStyle(
                    fontFamily: 'Outfit',
                    color: isDark ? Colors.grey : Colors.grey[400],
                  ),
                  prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey : Colors.grey[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          // CATEGORY CHIPS
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return ExerciseCategoryChip(
                  label: cat,
                  selected: selectedCategory == cat,
                  onSelected: (label) {
                    setState(() => selectedCategory = label);
                    if (label == "All") {
                      provider.resetFilters();
                    } else {
                      // Note: This logic depends on your DB values. 
                      // If DB has "upper legs", filtering by "Legs" might fail 
                      // unless filterByBodyPart handles partial matches.
                      provider.filterByBodyPart(label);
                      // The provider updates filteredExercises internally usually
                    }
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // LIST OF EXERCISES
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00E676),
                    ),
                  )
                : provider.filteredExercises.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, 
                                size: 48, 
                                color: isDark ? Colors.grey[800] : Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              "No exercises found",
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 16,
                                color: isDark ? Colors.grey : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: provider.filteredExercises.length,
                        itemBuilder: (context, index) {
                          final exercise = provider.filteredExercises[index];
                          return ExerciseCard(
                            exercise: exercise,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                "/exerciseDetail",
                                arguments: {
                                  'exercise': exercise,
                                },
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
