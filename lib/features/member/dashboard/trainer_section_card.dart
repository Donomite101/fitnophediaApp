import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'member_trainer_card.dart';
import '../../../../core/app_theme.dart';

class TrainerSectionCard extends StatelessWidget {
  final String gymId;
  final String memberId;
  final Color primaryGreen;
  final Color cardBackground;
  final Color textPrimary;
  final Color greyText;

  const TrainerSectionCard({
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
                "Meet Our Trainers",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Icon(Iconsax.arrow_right_1, color: greyText.withOpacity(0.5), size: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 345,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('gyms')
                .doc(gymId)
                .collection('staff')
                .where('role', isEqualTo: 'trainer')
                .where('status', isEqualTo: 'active')
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildShimmer();
              }

              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final trainerData = docs[index].data() as Map<String, dynamic>;
                  trainerData['id'] = docs[index].id;
                  
                  return MemberTrainerCard(
                    trainerData: trainerData,
                    isDarkMode: isDark,
                    onTap: () {
                      _showBookingSheet(context, trainerData);
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

  void _showBookingSheet(BuildContext context, Map<String, dynamic> trainer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingSheet(trainer: trainer),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          width: 180,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
        );
      },
    );
  }
}

class _BookingSheet extends StatelessWidget {
  final Map<String, dynamic> trainer;

  const _BookingSheet({Key? key, required this.trainer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Container(
                  width: 80,
                  height: 80,
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  child: trainer['photoUrl'] != null 
                    ? CachedNetworkImage(
                        imageUrl: trainer['photoUrl'],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
                        errorWidget: (context, url, error) => const Icon(Iconsax.user, size: 40, color: AppTheme.primaryGreen),
                      )
                    : const Icon(Iconsax.user, size: 40, color: AppTheme.primaryGreen),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trainer['name'] ?? 'Trainer',
                      style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      trainer['specialization'] ?? 'Fitness Pro',
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Experience',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            trainer['notes'] ?? 'Bringing years of expertise in body transformations and functional training to help you reach your goals.',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey, height: 1.5),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Booking request sent to ${trainer['name']}!'),
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: Text(
                'BOOK FREE CONSULTATION',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
