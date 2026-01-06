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
  String selectedCategory = "";

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    provider.loadExercises();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WorkoutProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        title: Text(
          "Exercise Library",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),

      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _search,
                onChanged: provider.searchExercises,
                decoration: InputDecoration(
                  hintText: "Search exercises…",
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // CATEGORY CHIPS
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: [
                ExerciseCategoryChip(
                  label: "Chest",
                  onSelected: (label) {
                    setState(() => selectedCategory = label);
                    final list = provider.filterByBodyPart(label);
                    provider.setFilteredExercises(list);

                  },
                ),
                ExerciseCategoryChip(
                  label: "Back",
                  onSelected: (label) {
                    setState(() => selectedCategory = label);
                    final list = provider.filterByBodyPart(label);
                    provider.setFilteredExercises(list);

                  },
                ),
                ExerciseCategoryChip(
                  label: "Legs",
                  onSelected: (label) {
                    setState(() => selectedCategory = label);
                    final list = provider.filterByBodyPart(label);
                    provider.setFilteredExercises(list);
                  },
                ),
                ExerciseCategoryChip(
                  label: "Arms",
                  onSelected: (label) {
                    setState(() => selectedCategory = label);
                    final list = provider.filterByBodyPart(label);
                    provider.setFilteredExercises(list);

                  },
                ),
                ExerciseCategoryChip(
                  label: "Shoulders",
                  onSelected: (label) {
                    setState(() => selectedCategory = label);
                    final list = provider.filterByBodyPart(label);
                    provider.setFilteredExercises(list);

                  },
                ),
                ExerciseCategoryChip(
                  label: "Core",
                  onSelected: (label) {
                    setState(() => selectedCategory = label);
                    final list = provider.filterByBodyPart(label);
                    provider.setFilteredExercises(list);
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: 10),

          // LIST OF EXERCISES
          Expanded(
            child: provider.isLoading
                ? Center(
              child: CircularProgressIndicator(
                color: Colors.green,
              ),
            )
                : provider.filteredExercises.isEmpty
                ? Center(
              child: Text(
                "No exercises found",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            )
                : ListView.builder(
              physics: BouncingScrollPhysics(),
              itemCount: provider.filteredExercises.length,
              itemBuilder: (context, index) {
                final exercise = provider.filteredExercises[index];
                return ExerciseCard(
                  exercise: exercise,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      "/exerciseDetail",
                      arguments: exercise,
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
