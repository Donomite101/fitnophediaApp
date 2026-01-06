import 'package:flutter/material.dart';
import '../../data/models/exercise_model.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback? onTap;

  const ExerciseCard({
    Key? key,
    required this.exercise,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 280),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // IMAGE LEFT SIDE
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 120,
                height: 120,
                child: Stack(
                  children: [
                    // Image
                    Positioned.fill(
                      child: exercise.imageUrl.isNotEmpty
                          ? Image.network(
                        exercise.imageUrl,
                        fit: BoxFit.cover,
                      )
                          : Container(color: Colors.grey.shade300),
                    ),

                    // Gradient Overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              Colors.black.withOpacity(0.10),
                              Colors.black.withOpacity(0.25),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),

            // RIGHT SIDE DETAILS
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Exercise Name
                    Text(
                      exercise.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),

                    SizedBox(height: 6),

                    // Body Part
                    Text(
                      exercise.bodyPart,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    Spacer(),

                    // Equipment Tag w/ gradient
                    Container(
                      padding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.blue.shade400,
                          ],
                        ),
                      ),
                      child: Text(
                        exercise.equipment,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
