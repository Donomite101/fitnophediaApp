import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fitnophedia/core/utils/class_image_helper.dart';

class MemberClassCard extends StatelessWidget {
  final Map<String, dynamic> classData;
  final bool isDarkMode;
  final VoidCallback onTap;

  const MemberClassCard({
    Key? key,
    required this.classData,
    required this.isDarkMode,
    required this.onTap,
  }) : super(key: key);

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) hexColor = "FF$hexColor";
    if (hexColor.length == 8) {
      return Color(int.parse("0x$hexColor"));
    }
    return const Color(0xFF00E676);
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorFromHex(classData['color'] ?? '#00E676');
    final participants = classData['participants'] as int? ?? 0;
    final capacity = classData['capacity'] as int? ?? 20;
    final isFull = participants >= capacity;
    final trainer = classData['trainer'] ?? 'Instructor';
    final time = classData['time'] ?? 'TBD';
    final name = classData['className'] ?? 'Fitness Class';
    final category = classData['category'] ?? 'general';
    final level = (classData['level'] ?? 'Beginner').toString().toUpperCase();
    final imageUrl = classData['imageUrl'] ?? ClassImageHelper.getCategoryImage(category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300, // Fixed width for horizontal scrolling
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              ClassImageHelper.isAsset(imageUrl)
                  ? Image.asset(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        child: Center(
                          child: Icon(Iconsax.image, color: Colors.grey[400]),
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        child: Center(
                          child: Icon(Iconsax.image, color: Colors.grey[400]),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        child: Center(
                          child: Icon(Iconsax.image, color: Colors.grey[400]),
                        ),
                      ),
                    ),
              
              // Gradient Overlay (Bottom to Top)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9), // Darker at bottom
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // Level Badge (Top Right)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    level,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // Status Badge (Top Left) - Optional
              if (isFull)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'FULL',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Content (Bottom)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Category Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // Class Name
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Trainer & Time
                    Row(
                      children: [
                        // Trainer
                        Icon(Iconsax.user, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            trainer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        
                        // Vertical Divider
                        Container(
                          height: 12,
                          width: 1,
                          color: Colors.white30,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),

                        // Time
                        Icon(Iconsax.clock, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          time,
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
