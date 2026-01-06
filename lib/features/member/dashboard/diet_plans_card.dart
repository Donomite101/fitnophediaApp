// lib/features/member/diet/diet_plans_card.dart
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class DietPlansCard extends StatelessWidget {
  final VoidCallback onTap;
  final Color primaryGreen;
  final Color cardBackground;
  final Color textPrimary;
  final Color greyText;

  const DietPlansCard({
    Key? key,
    required this.onTap,
    required this.primaryGreen,
    required this.cardBackground,
    required this.textPrimary,
    required this.greyText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = primaryGreen;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: accent.withOpacity(0.12),
          highlightColor: Colors.transparent,
          child: Container(
            height: 190,
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                // Left Accent Panel
                Container(
                  width: 110,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withOpacity(0.15),
                        accent.withOpacity(0.05)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      height: 58,
                      width: 58,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: const Icon(Iconsax.menu_board, color: Colors.white, size: 28),
                    ),
                  ),
                ),

                // Right Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TITLE ROW ------------------------------------
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                "Diet Plans",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Iconsax.heart, size: 14, color: accent),
                                  const SizedBox(width: 5),
                                  Text(
                                    "Personal",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // DESCRIPTION -------------------------------------
                        Expanded(
                          child: Text(
                            "Personalized meal plans designed for your fitness goals. Includes macros, timing, and weekly adjustments.",
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: greyText,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // FOOTER ROW --------------------------------------
                        Row(
                          children: [
                            Icon(Iconsax.clock, size: 14, color: greyText),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Updated weekly",
                                style: TextStyle(
                                  color: greyText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  "Open",
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.arrow_forward_ios,
                                    size: 12, color: accent),
                              ],
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
