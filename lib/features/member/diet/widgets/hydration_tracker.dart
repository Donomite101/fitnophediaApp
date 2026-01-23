import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class HydrationTracker extends StatelessWidget {
  final int currentMl;
  final int goalMl;
  final Function(int) onAddWater;
  final bool isDark;

  const HydrationTracker({
    Key? key,
    required this.currentMl,
    required this.goalMl,
    required this.onAddWater,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mock data for the "1000 ml" display
    // In a real app, this would be dynamic.
    // The image shows "Goal: 1500 ml" above "1000 ml"
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Goal: $goalMl ml",
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$currentMl ml",
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          
          // Slider / Progress
          // Using a custom painter or just a styled slider/progress bar
          // For now, using LinearPercentIndicator with custom styling to mimic the look
          LayoutBuilder(
            builder: (context, constraints) {
              final percent = (currentMl / goalMl).clamp(0.0, 1.0);
              final width = constraints.maxWidth * percent;
              final left = width - 12; // Center the 24px icon

              return Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    height: 6,
                    width: width,
                    decoration: BoxDecoration(
                      color: const Color(0xFF40C4FF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // The "drop" indicator
                  Positioned(
                    left: left.clamp(0.0, constraints.maxWidth - 24),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Iconsax.drop, size: 16, color: Color(0xFF40C4FF)),
                    ),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("0 ml", style: TextStyle(fontSize: 10, color: Colors.grey[400])),
              Text("$goalMl ml", style: TextStyle(fontSize: 10, color: Colors.grey[400])),
            ],
          ),

          const SizedBox(height: 24),

          // Water Glasses Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              for (int i = 0; i < 7; i++)
                _buildWaterGlass(context, i < 4, 250), // Mock filled state
              _buildAddWaterButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaterGlass(BuildContext context, bool isFilled, int amount) {
    return GestureDetector(
      onTap: () => onAddWater(amount),
      child: Icon(
        Icons.local_drink, // Using local_drink as a proxy for a glass
        size: 28,
        color: isFilled ? const Color(0xFF40C4FF) : const Color(0xFF40C4FF).withOpacity(0.3),
      ),
    );
  }

  Widget _buildAddWaterButton(BuildContext context) {
    return GestureDetector(
      onTap: () => onAddWater(250),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add, size: 18, color: Color(0xFF40C4FF)),
      ),
    );
  }
}
