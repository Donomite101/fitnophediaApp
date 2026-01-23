import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../repository/nutrition_repository.dart';

class DietPlanListScreen extends StatelessWidget {
  final String gymId;
  final String memberId;

  const DietPlanListScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF050505) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : Colors.black;
    final repo = NutritionRepository(gymId: gymId, memberId: memberId);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "SAVED PLANS",
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: repo.listenAiDietPlans(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("Error loading diet plans: ${snapshot.error}");
            return Center(child: Text("Error loading plans: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
          }

          final plans = snapshot.data ?? [];

          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.note_remove, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    "No saved plans yet",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return _buildPlanCard(context, plan, isDark, textColor);
            },
          );
        },
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, Map<String, dynamic> plan, bool isDark, Color textColor) {
    final name = plan['name'] ?? "Untitled Plan";
    final createdAt = plan['createdAt'] as Timestamp?;
    final dateStr = createdAt != null
        ? DateFormat('MMM d, yyyy').format(createdAt.toDate())
        : "Unknown Date";
    final source = plan['source'] == 'ai_coach' ? "AI COACH" : "CUSTOM";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Iconsax.clipboard_text, color: textColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      dateStr.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      source,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        color: isDark ? Colors.greenAccent : Colors.green,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Iconsax.arrow_right_3, color: isDark ? Colors.grey[600] : Colors.grey[400], size: 16),
        ],
      ),
    );
  }
}
