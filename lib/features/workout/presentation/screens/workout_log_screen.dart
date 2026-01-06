import 'package:flutter/material.dart';

class WorkoutLogScreen extends StatefulWidget {
  const WorkoutLogScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  String selectedFilter = "Today";

  final List<String> filters = ["Today", "Yesterday", "This Week"];

  // Sample logs – you will replace with Firestore or local DB later
  final List<Map<String, dynamic>> workoutLogs = [
    {
      "date": "Today",
      "title": "Push Day",
      "exercises": [
        {"name": "Bench Press", "sets": 4, "reps": "10-8-6-6", "weight": "60kg"},
        {"name": "Incline Dumbbell Press", "sets": 3, "reps": "12", "weight": "20kg"},
        {"name": "Tricep Pushdown", "sets": 3, "reps": "15", "weight": "25kg"},
      ],
    },
    {
      "date": "Yesterday",
      "title": "Pull Day",
      "exercises": [
        {"name": "Lat Pulldown", "sets": 4, "reps": "10", "weight": "50kg"},
        {"name": "Barbell Row", "sets": 3, "reps": "8", "weight": "40kg"},
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredLogs = workoutLogs.where((log) => log["date"] == selectedFilter).toList();

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        title: Text(
          "Workout Log",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // FILTER CHIPS
          SizedBox(
            height: 50,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isActive = filter == selectedFilter;

                return GestureDetector(
                  onTap: () => setState(() => selectedFilter = filter),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 250),
                    margin: EdgeInsets.only(right: 12),
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: isActive
                          ? LinearGradient(
                        colors: [
                          Colors.green.shade400,
                          Colors.blue.shade400,
                        ],
                      )
                          : null,
                      border: isActive
                          ? null
                          : Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 10),

          // WORKOUT LOG LIST
          Expanded(
            child: filteredLogs.isEmpty
                ? _emptyState()
                : ListView.builder(
              physics: BouncingScrollPhysics(),
              itemCount: filteredLogs.length,
              itemBuilder: (context, index) {
                final log = filteredLogs[index];
                return _workoutSessionCard(log);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Empty state UI
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 70, color: Colors.grey.shade400),
          SizedBox(height: 12),
          Text(
            "No workouts logged",
            style: TextStyle(
              fontSize: 17,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Workout Session Card (Apple Fitness+ inspired)
  Widget _workoutSessionCard(Map<String, dynamic> log) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Workout title
          Text(
            log["title"],
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),

          SizedBox(height: 14),

          // Exercise list inside this session
          Column(
            children: (log["exercises"] as List).map((exercise) {
              return _exerciseRow(exercise);
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Each exercise row inside session
  Widget _exerciseRow(Map<String, dynamic> ex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          // Bullet
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.green.shade400,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10),

          // Name + details
          Expanded(
            child: Text(
              "${ex['name']}  •  ${ex['sets']} sets  •  ${ex['reps']} reps",
              style: TextStyle(
                fontSize: 15,
                height: 1.3,
                color: Colors.black87,
              ),
            ),
          ),

          // Weight
          Text(
            ex["weight"] ?? "",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade700,
            ),
          )
        ],
      ),
    );
  }
}
