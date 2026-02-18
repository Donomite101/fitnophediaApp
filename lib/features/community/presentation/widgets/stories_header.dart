import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fitnophedia/features/community/domain/models/community_models.dart';
import 'package:fitnophedia/features/community/data/services/community_service.dart';
import 'package:fitnophedia/features/community/presentation/screens/create_community_content_screen.dart';
import 'package:fitnophedia/features/community/presentation/screens/community_profile_screen.dart';
import 'package:fitnophedia/features/community/presentation/screens/story_viewer_screen.dart';
import 'package:shimmer/shimmer.dart';

class StoriesHeader extends StatelessWidget {
  final List<String> followingIds;
  final String currentUserId;
  final String currentUserProfileImage;

  const StoriesHeader({
    Key? key,
    required this.followingIds,
    required this.currentUserId,
    required this.currentUserProfileImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: StreamBuilder<List<StoryModel>>(
        stream: CommunityService.instance.getActiveStories(followingIds: [currentUserId, ...followingIds]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmer(context);
          }
          final allStories = snapshot.data ?? [];
          
          // Group stories by userId
          final Map<String, List<StoryModel>> groupedStories = {};
          for (var story in allStories) {
            groupedStories.putIfAbsent(story.userId, () => []).add(story);
          }

          final ownStories = groupedStories[currentUserId] ?? [];
          final otherUserIds = groupedStories.keys.where((id) => id != currentUserId).toList();
          
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: otherUserIds.length + 1, // +1 for "Your Story"
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildAddStoryButton(context, ownStories);
              }
              
              final userId = otherUserIds[index - 1];
              final userStories = groupedStories[userId]!;
              return _buildUserStoryCircle(context, userId, userStories);
            },
          );
        },
      ),
    );
  }

  Widget _buildUserStoryCircle(BuildContext context, String userId, List<StoryModel> userStories) {
    final firstStory = userStories.first;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryViewerScreen(
              stories: userStories,
              initialIndex: 0,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.orange, Colors.yellow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.black,
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage: CachedNetworkImageProvider(firstStory.userProfileImage),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 60,
              child: Text(
                firstStory.userName,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddStoryButton(BuildContext context, List<StoryModel> ownStories) {
    final hasStory = ownStories.isNotEmpty;
    final latestStory = hasStory ? ownStories.first : null;

    return GestureDetector(
      onTap: () {
        if (hasStory) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoryViewerScreen(
                stories: ownStories,
                initialIndex: 0,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateCommunityContentScreen(
                isStory: true,
              ),
            ),
          );
        }
      },
      onLongPress: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CreateCommunityContentScreen(
              isStory: true,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: hasStory ? const EdgeInsets.all(2) : EdgeInsets.zero,
                  decoration: hasStory ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 2),
                  ) : null,
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: hasStory 
                      ? CachedNetworkImageProvider(latestStory!.mediaUrl)
                      : (currentUserProfileImage.isNotEmpty 
                        ? CachedNetworkImageProvider(currentUserProfileImage)
                        : null),
                    child: (!hasStory && currentUserProfileImage.isEmpty) ? const Icon(Icons.person) : null,
                  ),
                ),
                if (!hasStory)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Your Story', style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCircle(BuildContext context, StoryModel story, List<StoryModel> allStories, int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryViewerScreen(
              stories: allStories,
              initialIndex: index - 1,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF00C853)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage: story.mediaUrl.isNotEmpty
                    ? CachedNetworkImageProvider(story.mediaUrl)
                    : null,
                  child: story.mediaUrl.isEmpty ? const Icon(Icons.person) : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              story.userName,
              style: const TextStyle(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[900]!,
          highlightColor: Colors.grey[800]!,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                const CircleAvatar(radius: 32),
                const SizedBox(height: 4),
                Container(width: 40, height: 8, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }
}
