import 'package:flutter/material.dart';

class WorkoutTemplateScreen extends StatelessWidget {
  const WorkoutTemplateScreen({Key? key}) : super(key: key);

  final List<Map<String, dynamic>> templates = const [
    {
      "title": "Full Body Beginner",
      "level": "Beginner",
      "days": "3 Days / Week",
      "color": Colors.green,
      "workouts": ["Full Body A", "Full Body B", "Full Body C"],
    },
    {
      "title": "Push Pull Legs",
      "level": "Intermediate",
      "days": "6 Days / Week",
      "color": Colors.blue,
      "workouts": ["Push Day", "Pull Day", "Leg Day"],
    },
    {
      "title": "Fat Loss HIIT",
      "level": "All Levels",
      "days": "4 Days / Week",
      "color": Colors.orange,
      "workouts": ["HIIT A", "HIIT B", "Core HIIT", "Cardio Burn"],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
        title: Text(
          "Workout Templates",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: templates.length,
        itemBuilder: (context, index) {
          final t = templates[index];
          return _templateCard(context, t);
        },
      ),
    );
  }

  // TEMPLATE CARD (Apple Fitness+ Style)
  Widget _templateCard(BuildContext context, Map<String, dynamic> t) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          "/templateDetail",
          arguments: t,
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 20),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              Colors.green.shade400.withOpacity(0.85),
              Colors.blue.shade400.withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TEMPLATE TITLE
            Text(
              t["title"],
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),

            SizedBox(height: 6),

            // LEVEL + DAYS
            Row(
              children: [
                _infoChip(t["level"]),
                SizedBox(width: 10),
                _infoChip(t["days"]),
              ],
            ),

            SizedBox(height: 20),

            // WORKOUT DAYS PREVIEW
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (t["workouts"] as List).map((w) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        w,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            SizedBox(height: 10),

            // VIEW DETAILS BUTTON
            Text(
              "View Details →",
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // INFO CHIP
  Widget _infoChip(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
