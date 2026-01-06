import 'package:flutter/material.dart';
import '../../data/models/exercise_model.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final String gymId;
  final String memberId;
  final Exercise exercise;
  final bool isPremade;

  const ExerciseDetailScreen({
    Key? key,
    required this.exercise,
    required this.gymId,
    required this.memberId,
    required this.isPremade,
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
            color: Colors.black,
          ),
        ),
      ),

      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ********** HERO IMAGE SECTION **********
            _heroImage(),

            SizedBox(height: 22),

            // ********** NAME + TAGS **********
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                exercise.name,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),

            SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _tagChip(exercise.bodyPart),
                  _tagChip(exercise.equipment),
                  if (exercise.category.isNotEmpty) _tagChip(exercise.category),
                  if (exercise.target.isNotEmpty) _tagChip(exercise.target),
                ],
              ),
            ),

            SizedBox(height: 25),

            // ********** VIDEO BUTTON **********
            if (exercise.videoUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _videoButton(context),
              ),

            if (exercise.videoUrl.isNotEmpty) SizedBox(height: 30),

            // ********** STEPS TITLE **********
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "How to Perform",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),

            SizedBox(height: 12),

            // ********** STEPS LIST **********
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: List.generate(
                  exercise.steps.length,
                      (index) => _stepTile(index + 1, exercise.steps[index]),
                ),
              ),
            ),

            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // **************************************************
  // HERO IMAGE (GIF or static)
  // **************************************************
  Widget _heroImage() {
    return Container(
      height: 280,
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

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.25),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // **************************************************
  // TAG CHIP
  // **************************************************
  Widget _tagChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.green.shade400,
            Colors.blue.shade400,
          ],
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  // **************************************************
  // VIDEO BUTTON (future YouTube support)
  // **************************************************
  Widget _videoButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          "/exerciseVideoPlayer",
          arguments: exercise.videoUrl,
        );
      },
      child: Container(
        height: 58,
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
              Icon(Icons.play_circle_fill, color: Colors.white, size: 26),
              SizedBox(width: 8),
              Text(
                "Watch Video Demo",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // **************************************************
  // STEP TILE (Apple Fitness+ Style)
  // **************************************************
  Widget _stepTile(int number, String step) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$number.",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              step,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black87,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
