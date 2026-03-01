import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fitnophedia/features/community/data/services/community_service.dart';
import 'package:fitnophedia/features/community/presentation/screens/community_profile_screen.dart';

class CommunityFollowListScreen extends StatefulWidget {
  final String userId;
  final String type; // 'followers' or 'following'

  const CommunityFollowListScreen({
    Key? key,
    required this.userId,
    required this.type,
  }) : super(key: key);

  @override
  State<CommunityFollowListScreen> createState() =>
      _CommunityFollowListScreenState();
}

class _CommunityFollowListScreenState extends State<CommunityFollowListScreen> {
  late Future<List<Map<String, dynamic>>> _futureList;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    if (widget.type == 'followers') {
      _futureList = CommunityService.instance.getFollowers(widget.userId);
    } else {
      _futureList = CommunityService.instance.getFollowing(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'followers' ? 'Followers' : 'Following';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: BackButton(color: Theme.of(context).iconTheme.color),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Something went wrong. Please try again.',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            );
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.type == 'followers'
                        ? Iconsax.people
                        : Iconsax.user_add,
                    size: 64,
                    color: isDark ? Colors.white24 : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.type == 'followers'
                        ? 'No followers yet'
                        : 'Not following anyone',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              final uid = user['uid'] ?? user['id'] ?? '';
              final name =
                  user['username'] ??
                  user['firstName'] ??
                  user['name'] ??
                  'Unknown User';
              final profileImageUrl =
                  user['profileImageUrl'] ?? user['photoUrl'] ?? '';
              final isGymOwner = user['isGymOwner'] == true;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: isDark ? Colors.grey[900] : Colors.grey[200],
                  backgroundImage: profileImageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(profileImageUrl)
                      : null,
                  child: profileImageUrl.isEmpty
                      ? Icon(
                          Iconsax.user,
                          color: isDark ? Colors.white54 : Colors.black54,
                        )
                      : null,
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isGymOwner) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 14, color: Colors.blue),
                    ],
                  ],
                ),
                subtitle: Text(
                  isGymOwner ? 'Gym Owner' : 'Member',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                trailing: TextButton(
                  onPressed: () {
                    if (uid.isNotEmpty) {
                      CommunityProfileScreen.navigate(context, uid);
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(
                    'View',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                onTap: () {
                  if (uid.isNotEmpty) {
                    CommunityProfileScreen.navigate(context, uid);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
