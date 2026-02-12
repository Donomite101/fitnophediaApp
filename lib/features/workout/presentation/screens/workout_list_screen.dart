import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../widgets/unified_workout_card.dart';

class WorkoutListScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>>? staticWorkouts;
  final Stream<QuerySnapshot>? workoutStream;
  final String gymId;
  final String memberId;

  const WorkoutListScreen({
    Key? key,
    required this.title,
    this.staticWorkouts,
    this.workoutStream,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? Colors.black : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left_2, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
      body: _buildBody(context, isDark),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    if (staticWorkouts != null) {
      return _buildGrid(staticWorkouts!, isDark);
    } else if (workoutStream != null) {
      return StreamBuilder<QuerySnapshot>(
        stream: workoutStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(isDark);
          }

          final workouts = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();

          return _buildGrid(workouts, isDark);
        },
      );
    }
    return _buildEmptyState(isDark);
  }

  Widget _buildGrid(List<Map<String, dynamic>> workouts, bool isDark) {
    if (workouts.isEmpty) return _buildEmptyState(isDark);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workouts.length,
      itemBuilder: (context, index) {
        final workout = workouts[index];
        // Ensure consistent data structure
        if (!workout.containsKey('savedAt') && !workout.containsKey('createdAt')) {
             workout['savedAt'] = Timestamp.now();
        }
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: UnifiedWorkoutCard(
            data: workout,
            gymId: gymId,
            memberId: memberId,
            isDark: isDark,
            width: double.infinity,
            height: 320, // Taller card for feed look
            margin: EdgeInsets.zero,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.document_text, size: 64, color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: 16),
          Text(
            "No workouts found",
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
