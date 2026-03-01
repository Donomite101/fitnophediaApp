import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_theme.dart';

class MemberTrainerCard extends StatelessWidget {
  final Map<String, dynamic> trainerData;
  final bool isDarkMode;
  final VoidCallback onTap;

  const MemberTrainerCard({
    Key? key,
    required this.trainerData,
    required this.isDarkMode,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final photoUrl = trainerData['photoUrl'];
    final name = trainerData['name'] ?? 'Trainer';
    final specialization = trainerData['specialization'] ?? 'Fitness Expert';
    final double ratingValue = (trainerData['performanceRating'] ?? 5.0).toDouble();
    final String ratingStr = ratingValue.toStringAsFixed(1);
    final String reviewsCount = (trainerData['totalClients'] ?? 0).toString();

    // Theme-aware colors
    final cardBg = isDarkMode ? const Color(0xFF0D0D0D) : Colors.white;
    final imageBg = isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0);
    final cardBorder = isDarkMode ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08);
    final cardShadow = isDarkMode ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.08);
    final nameTxtColor = isDarkMode ? Colors.white : Colors.black;
    final subTxtColor = isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5);
    final ratingTxtColor = isDarkMode ? Colors.white : Colors.black87;
    final reviewsTxtColor = isDarkMode ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4);
    final emptyIconColor = isDarkMode ? const Color(0xFF333333) : const Color(0xFFBBBBBB);
    final badgeBg = isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.8);
    final badgeBorder = isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);
    final badgeTxtColor = isDarkMode ? Colors.white : Colors.black87;

    // Online status check
    bool isOnline = false;
    final lastAttendance = trainerData['lastAttendanceDate'];
    if (lastAttendance != null) {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      isOnline = lastAttendance.toString().startsWith(today);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 20, bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: cardShadow,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Image Area
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: imageBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: photoUrl != null && photoUrl.toString().isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: photoUrl.toString(),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
                                errorWidget: (context, url, error) => Center(child: Icon(Iconsax.user, size: 50, color: emptyIconColor)),
                              )
                            : Center(child: Icon(Iconsax.user, size: 50, color: emptyIconColor)),
                      ),
                      // Present/Away Badge
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: badgeBorder, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOnline ? AppTheme.primaryGreen : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isOnline ? 'ONLINE' : 'AWAY',
                                style: GoogleFonts.plusJakartaSans(
                                  color: badgeTxtColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Name
              Text(
                name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: nameTxtColor,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),

              // 3. Specialty
              Text(
                specialization,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: subTxtColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // 4. Rating & Reviews
              Row(
                children: [
                  Text(
                    ratingStr,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ratingTxtColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < ratingValue.floor() ? Iconsax.star5 : Iconsax.star,
                        size: 12,
                        color: index < ratingValue.floor() ? Colors.amber : Colors.grey.withOpacity(0.3),
                      );
                    }),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '($reviewsCount)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: reviewsTxtColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 5. Action Button
              Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'View Profile',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
