import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/cloudinary_config.dart';
import 'package:fitnophedia/features/community/data/services/community_service.dart';
import 'package:fitnophedia/features/community/domain/models/community_models.dart';
import 'package:fitnophedia/features/community/presentation/screens/create_community_content_screen.dart';
import 'package:fitnophedia/features/member/profile/MemberProfileScreen.dart';
import 'package:fitnophedia/features/member/profile/member_profile_setup_screen.dart';
import 'package:fitnophedia/features/community/presentation/screens/comments_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitnophedia/features/community/presentation/widgets/community_shimmer.dart';
import 'package:fitnophedia/features/community/presentation/widgets/stories_header.dart';
import 'package:share_plus/share_plus.dart';

class CommunityScreen extends StatefulWidget {
  final String userId;
  final String? gymId;

  const CommunityScreen({Key? key, required this.userId, this.gymId}) : super(key: key);

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _scrollControllerFollowing = ScrollController();
  List<PostModel> _allPosts = [];
  List<PostModel> _followingPosts = [];
  bool _isLoadingAll = false;
  bool _isLoadingFollowing = false;
  DocumentSnapshot? _lastDocumentAll;
  DocumentSnapshot? _lastDocumentFollowing;
  bool _hasMoreAll = true;
  bool _hasMoreFollowing = true;
  List<String> _followingIds = [];
  StreamSubscription? _followingSubscription;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final Set<String> _viewedPostIds = {}; // Track viewed posts in this session
  String _profileImageUrl = '';

  @override
  void initState() {
    super.initState();
    _fetchFollowingList();
    _loadPosts(isFollowingFeed: false);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
        if (!_isLoadingAll && _hasMoreAll) _loadPosts(isFollowingFeed: false);
      }
    });
    _scrollControllerFollowing.addListener(() {
      if (_scrollControllerFollowing.position.pixels >= _scrollControllerFollowing.position.maxScrollExtent * 0.8) {
        if (!_isLoadingFollowing && _hasMoreFollowing) _loadPosts(isFollowingFeed: true);
      }
    });
  }

  @override
  void dispose() {
    _followingSubscription?.cancel();
    _scrollController.dispose();
    _scrollControllerFollowing.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startFollowingListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    _followingSubscription?.cancel();
    _followingSubscription = FirebaseFirestore.instance
        .collection('members')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        final List<dynamic> following = data['following'] ?? [];
        final profileImg = data['profileImageUrl'] ?? '';
        
        if (!mounted) return;
        setState(() {
          _followingIds = following.map((e) => e.toString()).toList();
          _profileImageUrl = profileImg;
        });
        
        // Reload following posts if we have new IDs or if it's the first load
        if (_followingIds.isNotEmpty && _followingPosts.isEmpty && !_isLoadingFollowing) {
          _loadPosts(isFollowingFeed: true);
        }
      }
    });
  }

  Future<void> _fetchFollowingList() async {
    _startFollowingListener();
  }

  Future<void> _loadPosts({required bool isFollowingFeed}) async {
    if (!mounted) return;
    if (isFollowingFeed) {
      if (_isLoadingFollowing || !_hasMoreFollowing) return;
      setState(() => _isLoadingFollowing = true);
    } else {
      if (_isLoadingAll || !_hasMoreAll) return;
      setState(() => _isLoadingAll = true);
    }

    Query query = FirebaseFirestore.instance.collection('posts')
        .orderBy('createdAt', descending: true);

    if (isFollowingFeed) {
      if (_followingIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingFollowing = false;
        _hasMoreFollowing = false;
      });
      return;
      }
      query = query.where('userId', whereIn: _followingIds);
    }

    query = query.limit(10);

    final lastDoc = isFollowingFeed ? _lastDocumentFollowing : _lastDocumentAll;
    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      final newPosts = snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
    if (!mounted) return;
    setState(() {
      if (isFollowingFeed) {
        _followingPosts.addAll(newPosts);
        _lastDocumentFollowing = snapshot.docs.last;
        _isLoadingFollowing = false;
        if (newPosts.length < 10) _hasMoreFollowing = false;
      } else {
        _allPosts.addAll(newPosts);
        _lastDocumentAll = snapshot.docs.last;
        _isLoadingAll = false;
        if (newPosts.length < 10) _hasMoreAll = false;
      }
    });
    } else {
      if (!mounted) return;
      setState(() {
        if (isFollowingFeed) {
          _isLoadingFollowing = false;
          _hasMoreFollowing = false;
        } else {
          _isLoadingAll = false;
          _hasMoreAll = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: GestureDetector(
              onTap: () => MemberProfileScreen.navigate(context, widget.userId),
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('members').doc(widget.userId).get(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  final imageUrl = data?['profileImageUrl'] ?? '';
                  return CircleAvatar(
                    radius: 18,
                    backgroundImage: imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
                    child: imageUrl.isEmpty ? const Icon(Icons.person, size: 20) : null,
                  );
                },
              ),
            ),
          ),
          title: _isSearching 
            ? TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search members...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: _searchUsers,
              )
            : Text(
                'SOCIAL',
                style: GoogleFonts.bebasNeue(letterSpacing: 2, fontSize: 24),
              ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Iconsax.search_normal),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchResults.clear();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Iconsax.add_square),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateCommunityContentScreen(
                      gymId: widget.gymId,
                    ),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.green,
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: "NEW"),
              Tab(text: "FOLLOWING"),
            ],
          ),
        ),
        body: _isSearching 
          ? _buildSearchResults()
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPostFeed(isFollowing: false),
                      _buildPostFeed(isFollowing: true),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final snapshot = await FirebaseFirestore.instance.collection('members')
      .where('firstName', isGreaterThanOrEqualTo: query)
      .where('firstName', isLessThanOrEqualTo: query + '\uf8ff')
      .limit(20)
      .get();

    setState(() {
      _searchResults = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(child: Text("No users found"));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: (user['profileImageUrl'] ?? '').isNotEmpty 
              ? CachedNetworkImageProvider(user['profileImageUrl']) 
              : null,
            child: (user['profileImageUrl'] ?? '').isEmpty ? const Icon(Icons.person) : null,
          ),
          title: Text(user['firstName'] ?? 'User'),
          subtitle: Text(user['bio'] ?? 'Fitness Enthusiast'),
          onTap: () => MemberProfileScreen.navigate(context, user['id']),
        );
      },
    );
  }

  Widget _buildPostFeed({required bool isFollowing}) {
    final posts = isFollowing ? _followingPosts : _allPosts;
    final isLoading = isFollowing ? _isLoadingFollowing : _isLoadingAll;
    final hasMore = isFollowing ? _hasMoreFollowing : _hasMoreAll;

    if (isFollowing && _followingIds.isEmpty && !isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.user_add, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Follow people to see their posts!", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: CommunityService.instance.getActiveAds(gymId: widget.gymId),
      builder: (context, adSnap) {
        final ads = adSnap.data ?? [];
        
        return RefreshIndicator(
          onRefresh: () async {
            if (isFollowing) {
              await _fetchFollowingList();
              _lastDocumentFollowing = null;
              _followingPosts.clear();
              _hasMoreFollowing = true;
              await _loadPosts(isFollowingFeed: true);
            } else {
              _lastDocumentAll = null;
              _allPosts.clear();
              _hasMoreAll = true;
              await _loadPosts(isFollowingFeed: false);
            }
          },
          child: ListView.builder(
            controller: isFollowing ? _scrollControllerFollowing : _scrollController,
            itemCount: isLoading && posts.isEmpty ? 1 : posts.length + (hasMore ? 1 : 0) + (ads.isNotEmpty && !isFollowing ? (posts.length ~/ 5) : 0),
            itemBuilder: (context, index) {
              if (isLoading && posts.isEmpty) {
                return const CommunityShimmer();
              }
              
              if (index >= (posts.length + (hasMore ? 1 : 0) + (ads.isNotEmpty && !isFollowing ? (posts.length ~/ 5) : 0))) {
                 return const SizedBox.shrink();
              }

              // Logic to insert ads every 5 posts
              if (!isFollowing && ads.isNotEmpty && index != 0 && index % 6 == 0) {
                 final adIndex = (index ~/ 6) % ads.length;
                 return _buildAdItem(ads[adIndex]);
              }

              // Adjust post index if ads are inserted
              int postIdx = !isFollowing && ads.isNotEmpty ? index - (index ~/ 6) : index;
              
              if (postIdx >= posts.length) {
                if (hasMore) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(color: Colors.green),
                  ));
                }
                return const SizedBox.shrink();
              }

              return _buildPostItem(posts[postIdx]);
            },
          ),
        );
      }
    );
  }

  void _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
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
      await CommunityService.instance.deletePost(postId);
      setState(() {
        _allPosts.removeWhere((p) => p.id == postId);
        _followingPosts.removeWhere((p) => p.id == postId);
      });
    }
  }

  Widget _buildPostItem(PostModel post) {
    final isMe = post.userId == FirebaseAuth.instance.currentUser?.uid;

    // Increment view count once per session
    if (!_viewedPostIds.contains(post.id)) {
      _viewedPostIds.add(post.id);
      CommunityService.instance.incrementPostViews(post.id);
    }

    return GestureDetector(
      onLongPress: isMe ? () => _deletePost(post.id) : null,
      onTap: () {
        if (!_viewedPostIds.contains(post.id)) {
          _viewedPostIds.add(post.id);
          CommunityService.instance.incrementPostViews(post.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: FutureBuilder<Map<String, dynamic>>(
              future: CommunityService.instance.getMemberDetails(post.userId),
              builder: (context, userSnap) {
                final userData = userSnap.data ?? {};
                final displayName = userData['username'] ?? userData['firstName'] ?? post.userName;
                final profileImg = userData['profileImageUrl'] ?? post.userProfileImage;
                
                return Row(
                  children: [
                    GestureDetector(
                      onTap: () => MemberProfileScreen.navigate(context, post.userId),
                      child: CircleAvatar(
                        backgroundImage: profileImg.isNotEmpty 
                          ? CachedNetworkImageProvider(profileImg)
                          : null,
                        child: profileImg.isEmpty ? const Icon(Icons.person) : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => MemberProfileScreen.navigate(context, post.userId),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          FutureBuilder<String>(
                            future: CommunityService.instance.getGymName(post.gymId),
                            builder: (context, snap) => Text(
                              snap.data ?? 'Gym Member',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Media
          AspectRatio(
            aspectRatio: 1,
            child: CachedNetworkImage(
              imageUrl: post.mediaUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[900]),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(post.id)
                      .collection('likes')
                      .doc(widget.userId)
                      .snapshots(),
                  builder: (context, likeSnap) {
                    final isLiked = likeSnap.hasData && likeSnap.data!.exists;
                    return IconButton(
                      icon: Icon(
                        isLiked ? Iconsax.heart5 : Iconsax.heart,
                        color: isLiked ? Colors.red : null,
                      ),
                      onPressed: () => CommunityService.instance.toggleLike(post.id, widget.userId),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Iconsax.message), 
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommentsScreen(postId: post.id),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Iconsax.send_2), 
                  onPressed: () {
                    Share.share('Check out this post on FitNophedia!\n\n${post.caption}\n${post.mediaUrl}');
                  },
                ),
                const Spacer(),
                StreamBuilder<bool>(
                  stream: CommunityService.instance.isSaved(widget.userId, post.id),
                  builder: (context, savedSnap) {
                    final isSaved = savedSnap.data ?? false;
                    return IconButton(
                      icon: Icon(isSaved ? Iconsax.archive_15 : Iconsax.archive_1),
                      onPressed: () => CommunityService.instance.toggleSave(widget.userId, post.id),
                      color: isSaved ? Colors.green : null,
                    );
                  }
                ),
              ],
            ),
          ),
          // Likes & Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('posts').doc(post.id).snapshots(),
                  builder: (context, postSnap) {
                    final Map<String, dynamic>? data = postSnap.data?.data() as Map<String, dynamic>?;
                    final likes = data?['likesCount'] ?? post.likesCount;
                    final views = data?['viewsCount'] ?? post.viewsCount;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Iconsax.heart5, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            '$likes',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Iconsax.eye, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            '$views',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                if (post.caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
                        children: [
                          TextSpan(
                            text: post.userName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(text: post.caption),
                        ],
                      ),
                    ),
                  ),
                Text(
                  _formatTimestamp(post.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return "${timestamp.day}/${timestamp.month}/${timestamp.year}";
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  Widget _buildAdItem(Map<String, dynamic> ad) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: ad['mediaUrl'] ?? '',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[900]),
              errorWidget: (context, url, error) => const Center(
                child: Text("Ad Content", style: TextStyle(color: Colors.white)),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ad['gymName'] ?? 'Sponsored',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                child: const Text("Ad", style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            )
          ],
        ),
      ),
    );
  }
}