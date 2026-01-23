import 'package:flutter/material.dart';
import '../../data/models/exercise_model.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final String gymId;
  final String memberId;
  final Exercise exercise;
  final bool isPremade;

  const ExerciseDetailScreen({
    Key? key,
    required this.exercise, required this.gymId, required this.memberId, required this.isPremade,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(
          exercise.name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),

      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // HERO IMAGE WITH GRADIENT
            _exerciseHeroImage(),

            SizedBox(height: 20),

            // TITLE + BODY PART + EQUIPMENT TAGS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                exercise.name,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 10,
                children: [
                  _tagChip(exercise.bodyPart),
                  _tagChip(exercise.equipment),
                  if (exercise.category.isNotEmpty)
                    _tagChip(exercise.category),
                ],
              ),
            ),

            SizedBox(height: 20),

            // VIDEO BUTTON
            if (exercise.videoUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _videoPreviewButton(context),
              ),

            SizedBox(height: 25),

            // STEPS SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "How To Do It",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: exercise.steps.map((step) {
                  return _stepTile(step);
                }).toList(),
              ),
            ),

            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // HERO IMAGE
  Widget _exerciseHeroImage() {
    return Container(
      height: 260,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: exercise.imageUrl.isNotEmpty
                ? Image.network(
              exercise.imageUrl,
              fit: BoxFit.cover,
            )
                : Container(color: Colors.grey.shade300),
          ),

          // GRADIENT OVERLAY
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.25),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  // CATEGORY / MUSCLE TAG CHIP
  Widget _tagChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade400,
            Colors.blue.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // VIDEO PREVIEW BUTTON
  Widget _videoPreviewButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          "/exerciseVideoPlayer",
          arguments: exercise.videoUrl,
        );
      },
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade400,
              Colors.green.shade400,
            ],
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                "Watch Video Demo",
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

  // STEP TILE (Apple Fitness+ style)
  Widget _stepTile(String step) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Text(
        step,
        style: TextStyle(
          fontSize: 15,
          color: Colors.black87,
          height: 1.4,
        ),
      ),
    );
  }
}
