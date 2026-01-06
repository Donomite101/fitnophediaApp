import 'package:flutter/material.dart';
import '../models/badge_dialog.dart';
import '../models/badge_model.dart';

class AllBadgesScreen extends StatefulWidget {
  final List<BadgeModel> badges;
  final bool isDarkMode;

  const AllBadgesScreen({
    Key? key,
    required this.badges,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<AllBadgesScreen> createState() => _AllBadgesScreenState();
}

class _AllBadgesScreenState extends State<AllBadgesScreen> {
  final Color _primaryBlue = const Color(0xFF2196F3);
  Color get _backgroundColor => widget.isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  Color get _textColor => widget.isDarkMode ? Colors.white : Colors.black;
  Color get _secondaryTextColor => widget.isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF666666);

  @override
  Widget build(BuildContext context) {
    final featuredBadges = widget.badges.where((b) => b.category == 'Featured').toList();
    final weeklyBadges = widget.badges.where((b) => b.category == 'Weekly Achievement').toList();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textColor, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Achievements',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isDarkMode
                        ? [
                      const Color(0xFF1E3A8A),
                      const Color(0xFF1E40AF),
                      _primaryBlue,
                    ]
                        : [
                      const Color(0xFFDBEAFE),
                      const Color(0xFFE0F2FE),
                      const Color(0xFFE3F2FD),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      '${widget.badges.where((b) => b.unlocked).length}',
                      'Unlocked',
                      Icons.emoji_events,
                    ),
                    _buildStatItem(
                      '${widget.badges.length}',
                      'Total',
                      Icons.all_inclusive,
                    ),
                    _buildStatItem(
                      '${(widget.badges.where((b) => b.unlocked).length / widget.badges.length * 100).toInt()}%',
                      'Progress',
                      Icons.trending_up,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Featured section
              if (featuredBadges.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Featured Badges',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: featuredBadges.length,
                  itemBuilder: (context, index) {
                    return _buildBadgeCard(context, featuredBadges[index]);
                  },
                ),
                const SizedBox(height: 32),
              ],

              // Weekly Achievement section
              if (weeklyBadges.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Weekly Achievements',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: weeklyBadges.length,
                  itemBuilder: (context, index) {
                    return _buildBadgeCard(context, weeklyBadges[index]);
                  },
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(widget.isDarkMode ? 0.1 : 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: widget.isDarkMode ? Colors.white : Colors.black,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: widget.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: widget.isDarkMode
                ? Colors.white.withOpacity(0.8)
                : Colors.black.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(BuildContext context, BadgeModel badge) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(20),
            child: BadgeUnlockDialog(
              badge: badge,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        );
      },
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: badge.unlocked
                      ? LinearGradient(
                    colors: [badge.color, badge.color.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: badge.unlocked ? null : (widget.isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
                  shape: BoxShape.circle,
                  boxShadow: badge.unlocked
                      ? [
                    BoxShadow(
                      color: badge.color.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                      : null,
                  border: Border.all(
                    color: widget.isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    badge.icon,
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
              if (badge.isNew && badge.unlocked)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9800), Color(0xFFFF6B35)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9800).withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (!badge.unlocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(widget.isDarkMode ? 0.6 : 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: Text(
              badge.title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badge.unlocked ? _textColor : _secondaryTextColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}