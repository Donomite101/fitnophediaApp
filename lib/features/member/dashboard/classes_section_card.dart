import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';
import 'member_class_card.dart';
import '../classes/member_classes_screen.dart';
import '../classes/member_class_details_screen.dart';

class ClassesSectionCard extends StatelessWidget {
  final String gymId;
  final String memberId;
  final Color primaryGreen;
  final Color cardBackground;
  final Color textPrimary;
  final Color greyText;

  const ClassesSectionCard({
    Key? key,
    required this.gymId,
    required this.memberId,
    this.primaryGreen = const Color(0xFF00E676),
    required this.cardBackground,
    required this.textPrimary,
    required this.greyText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Classes",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  fontFamily: 'Outfit',
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MemberClassesScreen(
                        gymId: gymId,
                        memberId: memberId,
                      ),
                    ),
                  );
                },
                child: Text(
                  "See All",
                  style: TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180, // Height of MemberClassCard
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('gyms')
                .doc(gymId)
                .collection('classes')
                .where('isActive', isEqualTo: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildShimmer();
              }

              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final classData = docs[index].data() as Map<String, dynamic>;
                  classData['id'] = docs[index].id;
                  
                  return MemberClassCard(
                    classData: classData,
                    isDarkMode: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MemberClassDetailsScreen(
                            gymId: gymId,
                            memberId: memberId,
                            classData: classData,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.calendar_remove, color: greyText.withOpacity(0.5), size: 40),
          const SizedBox(height: 8),
          Text(
            "No classes scheduled today",
            style: TextStyle(color: greyText, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          width: 300,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
    );
  }
}
