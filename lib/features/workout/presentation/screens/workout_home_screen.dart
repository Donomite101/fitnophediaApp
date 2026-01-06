import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../routes/app_routes.dart';
import '../../data/providers/workout_provider.dart';
import '../widgets/workout_banner_carousel.dart';
import '../widgets/exercise_category_chip.dart';
import '../widgets/exercise_card.dart';

class WorkoutHomeScreen extends StatefulWidget {
  final String gymId;
  final String memberId;

  const WorkoutHomeScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  State<WorkoutHomeScreen> createState() => _WorkoutHomeScreenState();
}

class _WorkoutHomeScreenState extends State<WorkoutHomeScreen> {
  String selectedCategory = "";

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      Provider.of<WorkoutProvider>(context, listen: false).loadExercises();
    });
  }


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WorkoutProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          "Workouts",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),

      body: provider.isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // BANNER CAROUSEL
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: WorkoutBannerCarousel(),
            ),

            SizedBox(height: 20),

            // CATEGORY SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Categories",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),

            SizedBox(height: 10),

            _categoryList(provider),

            SizedBox(height: 25),

            // ACTION BUTTONS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _premiumButton(
                      title: "Exercise Library",
                      icon: Icons.auto_awesome,
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.exerciseLibrary);
                      },
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _premiumButton(
                      title: "Create Workout",
                      icon: Icons.edit_note_rounded,
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.createWorkout);
                      },
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),

            // TODAY’S WORKOUT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Today's Workout",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),

            SizedBox(height: 10),

            _todaysWorkoutSection(),

            SizedBox(height: 30),

            // RECOMMENDED SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Recommended For You",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),

            SizedBox(height: 12),

            _recommendedSection(provider),

            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // CATEGORY CHIPS (Functional)
  Widget _categoryList(WorkoutProvider provider) {
    final categories = ["Chest", "Back", "Legs", "Arms", "Shoulders", "Core"];

    return SizedBox(
      height: 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: categories.map((cat) {
          return ExerciseCategoryChip(
            label: cat,
            selected: selectedCategory == cat,
            onSelected: (label) {
              setState(() => selectedCategory = label);

              final list = provider.filterByBodyPart(label);
              provider.setFilteredExercises(list);

            },
          );
        }).toList(),
      ),
    );
  }

  // PREMIUM BUTTONS (Exercise Library | Create Workout)
  Widget _premiumButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.green.shade400,
              Colors.blue.shade400,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // TODAY'S WORKOUT TILE
  Widget _todaysWorkoutSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade400.withOpacity(0.75),
              Colors.green.shade400.withOpacity(0.75),
            ],
          ),
        ),
        child: Center(
          child: Text(
            "No workout planned today",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // RECOMMENDED FOR YOU
  Widget _recommendedSection(WorkoutProvider provider) {
    final list = selectedCategory.isEmpty
        ? provider.exercises.take(5).toList()
        : provider.filteredExercises.take(5).toList();

    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          "No exercises available",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return ExerciseCard(exercise: list[index]);
      },
    );
  }
}
