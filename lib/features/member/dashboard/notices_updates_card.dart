// lib/features/member/notices/notices_updates_card.dart
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class NoticesUpdatesCard extends StatelessWidget {
  final VoidCallback onTap;
  final Color primaryGreen;
  final Color cardBackground;
  final Color textPrimary;
  final Color greyText;
  final Function(String) showSnackbar;
  final int unreadCount;
  final DateTime? lastUpdate;

  const NoticesUpdatesCard({
    Key? key,
    required this.onTap,
    required this.primaryGreen,
    required this.cardBackground,
    required this.textPrimary,
    required this.greyText,
    required this.showSnackbar,
    this.unreadCount = 0,
    this.lastUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = cardBackground;
    final Color titleColor = textPrimary;
    final Color subtitleColor = greyText;
    final Color accent = primaryGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          showSnackbar('Opening notices section...');
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        splashColor: accent.withOpacity(0.10),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.36 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              // Top banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent.withOpacity(0.12), accent.withOpacity(0.04)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent.withOpacity(0.18), accent.withOpacity(0.06)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Iconsax.notification, color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notices & Updates',
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.05,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Latest gym announcements',
                            style: TextStyle(color: subtitleColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // unread badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: unreadCount > 0
                            ? (isDark ? Colors.redAccent.withOpacity(0.12) : Colors.red.withOpacity(0.08))
                            : (isDark ? Colors.grey.withOpacity(0.12) : Colors.grey.withOpacity(0.08)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Iconsax.notification,
                            size: 12,
                            color: unreadCount > 0
                                ? (isDark ? Colors.redAccent : Colors.red)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? (isDark ? Colors.redAccent : Colors.red)
                                  : Colors.grey,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // short description (editable by the caller via data)
                      Text(
                        'Stay updated with announcements from your gym owner — class changes, events, and urgent notices will appear here.',
                        style: TextStyle(color: subtitleColor, fontSize: 13, height: 1.3),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),

                      // footer: last update + CTA
                      Row(
                        children: [
                          Row(
                            children: [
                              Icon(Iconsax.calendar, size: 14, color: subtitleColor),
                              const SizedBox(width: 8),
                              Text(
                                lastUpdate != null
                                    ? 'Last updated: ${_formatDate(lastUpdate!)}'
                                    : 'No updates yet',
                                style: TextStyle(color: subtitleColor, fontSize: 12),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text('View', style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_ios, size: 14, color: accent),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'today';
    } else if (dateOnly == yesterday) {
      return 'yesterday';
    } else {
      final difference = today.difference(dateOnly).inDays;
      if (difference < 7) {
        return '$difference days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    }
  }
}
