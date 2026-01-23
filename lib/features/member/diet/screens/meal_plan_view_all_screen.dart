import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../models/meal_plan_model.dart';
import '../widgets/meal_plan_card_widget.dart';
import 'meal_plan_detail_screen.dart';

class MealPlanViewAllScreen extends StatelessWidget {
  final String title;
  final List<MealPlan> plans;
  final String gymId;
  final String memberId;

  const MealPlanViewAllScreen({
    Key? key,
    required this.title,
    required this.plans,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: plans.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.note_remove, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    "No plans found",
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.53, // Adjusted to fit card content (approx 310px height)
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                return MealPlanCard(
                  mealPlan: plans[index],
                  isDark: isDark,
                  onTap: () => _navigateToDetail(context, plans[index]),
                  width: double.infinity,
                );
              },
            ),
    );
  }

  void _navigateToDetail(BuildContext context, MealPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MealPlanDetailScreen(
          mealPlan: plan,
          gymId: gymId,
          memberId: memberId,
        ),
      ),
    );
  }
}
