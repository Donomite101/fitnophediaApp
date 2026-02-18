import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fitnophedia/features/community/domain/models/community_models.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fitnophedia/features/community/data/services/community_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iconsax/iconsax.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;

  const StoryViewerScreen({
    Key? key, 
    required this.stories, 
    this.initialIndex = 0
  }) : super(key: key);

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _progressController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _markRead(_currentIndex);
    _startStory();
  }

  void _markRead(int index) {
    final story = widget.stories[index];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && !story.viewerIds.contains(uid)) {
      CommunityService.instance.markStoryAsViewed(story.id, uid);
    }
  }

  void _startStory() {
    _progressController.reset();
    _progressController.forward();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _markRead(_currentIndex);
      _startStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _markRead(_currentIndex);
      _startStory();
    }
  }

  void _deleteStory(String storyId) async {
    _progressController.stop();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story'),
        content: const Text('Are you sure you want to delete this story?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CommunityService.instance.deleteStory(storyId);
      if (mounted) {
        if (widget.stories.length <= 1) {
          Navigator.pop(context);
        } else {
          // Simplest is to just pop and assume parent refreshes, 
          // but for now let's just exit
          Navigator.pop(context);
        }
      }
    } else {
       _progressController.forward();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _previousStory();
          } else if (details.globalPosition.dx > width * 2 / 3) {
            _nextStory();
          }
        },
        onLongPressStart: (_) => _progressController.stop(),
        onLongPressEnd: (_) => _progressController.forward(),
        child: Stack(
          children: [
            // Media
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.stories.length,
              itemBuilder: (context, index) {
                return CachedNetworkImage(
                  imageUrl: widget.stories[index].mediaUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                );
              },
            ),

            // UI Overlay
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  children: [
                    // Progress Bar
                    Row(
                      children: widget.stories.asMap().entries.map((entry) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, child) {
                                double progress = 0.0;
                                if (entry.key < _currentIndex) {
                                  progress = 1.0;
                                } else if (entry.key == _currentIndex) {
                                  progress = _progressController.value;
                                }
                                return LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  minHeight: 2,
                                );
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    // Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: story.userProfileImage.isNotEmpty
                            ? CachedNetworkImageProvider(story.userProfileImage)
                            : null,
                          child: story.userProfileImage.isEmpty ? const Icon(Icons.person, size: 20) : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          story.userName,
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (story.userId == FirebaseAuth.instance.currentUser?.uid)
                          IconButton(
                            icon: const Icon(Iconsax.trash, color: Colors.white70, size: 20),
                            onPressed: () => _deleteStory(story.id),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Bottom Actions (Likes & Views)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (story.userId == FirebaseAuth.instance.currentUser?.uid)
                            _buildStoryStat(Iconsax.eye, story.viewerIds.length.toString()),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: () {
                              CommunityService.instance.toggleStoryLike(story.id, FirebaseAuth.instance.currentUser!.uid);
                              // Local feedback
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Liked!'), duration: Duration(milliseconds: 500)),
                              );
                            },
                            child: _buildStoryStat(Iconsax.heart5, story.likesCount.toString(), color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryStat(IconData icon, String label, {Color color = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
