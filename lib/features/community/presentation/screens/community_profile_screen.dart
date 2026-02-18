import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fitnophedia/features/community/domain/models/community_models.dart';
import 'package:fitnophedia/features/community/data/services/community_service.dart';
import 'package:fitnophedia/features/community/presentation/screens/comments_screen.dart';
import 'package:fitnophedia/features/community/presentation/widgets/community_shimmer.dart';
import 'package:fitnophedia/features/member/streak/service/streak_service.dart';
import 'package:fitnophedia/features/member/profile/MemberProfileScreen.dart';

class CommunityProfileScreen extends StatefulWidget {
  final String userId;
  final bool isGymOwner;

  const CommunityProfileScreen({
    Key? key,
    required this.userId,
    this.isGymOwner = false,
  }) : super(key: key);

  @override
  State<CommunityProfileScreen> createState() => _CommunityProfileScreenState();
}

class _CommunityProfileScreenState extends State<CommunityProfileScreen> with AutomaticKeepAliveClientMixin {

  int _selectedTab = 0;
  
  // Cache data to prevent reloading on tab switch
  Map<String, dynamic>? _profileData;
  bool _isLoadingProfile = true;
  List<PostModel> _userPosts = [];
  List<PostModel> _savedPosts = [];
  bool _isLoadingPosts = false;
  bool _isLoadingSaved = false;
  bool _hasLoadedPosts = false;
  bool _hasLoadedSaved = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    await _loadProfileData();
    _loadUserPosts();
    if (_isCurrentUser()) {
      _loadSavedPosts();
    }
  }

  bool _isCurrentUser() {
    return widget.userId == FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _loadProfileData() async {
    if (widget.userId.isEmpty) return;
    setState(() => _isLoadingProfile = true);

    try {
      // Try to get from global members first
      Map<String, dynamic> data = await CommunityService.instance.getMemberDetails(widget.userId);

      if (data.isEmpty) {
        // Try fallback to gyms collection if we can find the gymId
        final indexDoc = await FirebaseFirestore.instance.collection('member_index').doc(widget.userId).get();
        if (indexDoc.exists) {
          final gymId = indexDoc.data()?['gymId'];
          final memberId = indexDoc.data()?['memberId'] ?? widget.userId;
          if (gymId != null) {
            final gymMemberDoc = await FirebaseFirestore.instance
                .collection('gyms')
                .doc(gymId)
                .collection('members')
                .doc(memberId)
                .get();
            if (gymMemberDoc.exists) {
              data = gymMemberDoc.data()!;
            }
          }
        }
      }

      if (data.isNotEmpty) {
        final enrichedData = await _enrichProfileData(data);
        if (mounted) {
          setState(() {
            _profileData = enrichedData;
            _isLoadingProfile = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }



  Future<void> _loadUserPosts() async {
    if (_hasLoadedPosts) return;
    setState(() => _isLoadingPosts = true);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();
      
      if (mounted) {
        setState(() {
          _userPosts = snapshot.docs
              .map((doc) => PostModel.fromFirestore(doc))
              .toList();
          _isLoadingPosts = false;
          _hasLoadedPosts = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading user posts: $e');
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _loadSavedPosts() async {
    if (_hasLoadedSaved || !_isCurrentUser()) return;
    setState(() => _isLoadingSaved = true);
    
    try {
      // Use the stream-to-future conversion for one-time load or just use the service
      final posts = await CommunityService.instance.getSavedPosts(widget.userId).first;
      
      if (mounted) {
        setState(() {
          _savedPosts = posts;
          _isLoadingSaved = false;
          _hasLoadedSaved = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved posts: $e');
      if (mounted) setState(() => _isLoadingSaved = false);
    }
  }



  Future<Map<String, dynamic>> _enrichProfileData(Map<String, dynamic> data) async {
    final gymId = data['gymId'] ?? '';
    int streak = 0;
    int workoutCount = 0;
    String gymName = 'Gym Member';

    if (gymId.isNotEmpty) {
      streak = await StreakService.instance.getEffectiveStreak(gymId, widget.userId);
      workoutCount = await _fetchTotalWorkouts(gymId, widget.userId);
      gymName = await CommunityService.instance.getGymName(gymId);
    }

    final followersSnapshot = await FirebaseFirestore.instance
        .collection('members')
        .doc(widget.userId)
        .collection('followers')
        .count()
        .get();
          
    final followersCount = followersSnapshot.count ?? data['followersCount'] ?? 0;

    return {
      ...data,
      'currentStreak': streak,
      'totalWorkouts': workoutCount,
      'gymDisplayName': gymName,
      'followersCount': followersCount,
    };
  }

  Future<int> _fetchTotalWorkouts(String gymId, String memberId) async {
    if (gymId.isEmpty || memberId.isEmpty) return 0;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('workouts')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _updateProfileField(String field, String value) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid != widget.userId) return;

    try {
      if (field == 'username') {
        final existing = await FirebaseFirestore.instance
            .collection('members')
            .where('username', isEqualTo: value)
            .get();

        if (existing.docs.isNotEmpty && existing.docs.first.id != currentUid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Username already taken')),
            );
          }
          return;
        }
      }

      final updateData = {
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Update global members
      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.userId)
          .set(updateData, SetOptions(merge: true));

      // Also update in gym-specific collection if it exists
      if (_profileData?['gymId'] != null) {
         await FirebaseFirestore.instance
            .collection('gyms')
            .doc(_profileData!['gymId'])
            .collection('members')
            .doc(widget.userId)
            .set(updateData, SetOptions(merge: true));
      }

      CommunityService.instance.invalidateMemberCache(widget.userId);
      _loadProfileData();
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  void _showEditDialog(String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit ${field[0].toUpperCase()}${field.substring(1)}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')
          ),
          ElevatedButton(
            onPressed: () {
              _updateProfileField(field, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save')
          )
        ],
      ),
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
        _userPosts.removeWhere((p) => p.id == postId);
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile == null) return;
    
    setState(() => _isLoadingProfile = true);
    
    try {
      final file = File(pickedFile.path);
      // Use Cloudinary for more reliable uploads
      final url = await CommunityService.instance.uploadMedia(file, resourceType: 'image');
      
      if (url == null) throw Exception('Upload failed');
      
      await _updateProfileField('profileImageUrl', url);
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!')));
    } catch (e) {
      debugPrint('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() => _isLoadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoadingProfile) {
      return const Scaffold(body: ProfileShimmer());
    }

    if (_profileData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Profile not found'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadProfileData, child: const Text('Retry')),
            ],
          ),
        )
      );
    }

    final data = _profileData!;
    final userName = data['username'] ?? data['firstName'] ?? data['name'] ?? 'User';
    final bio = data['bio'] ?? 'No bio available';
    // Robust check for profile image URL in various possible fields
    final profileImage = data['profileImageUrl'] ?? data['photoUrl'] ?? data['image'] ?? '';
    final gymName = data['gymDisplayName'] ?? 'Gym Member';
    final isMe = _isCurrentUser();

    final stats = {
      'streak': data['currentStreak'] ?? 0,
      'workouts': data['totalWorkouts'] ?? 0,
      'followers': data['followersCount'] ?? 0,
      'following': data['following'] is List ? (data['following'] as List).length : (data['following'] is int ? data['following'] : 0),
    };

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          _hasLoadedPosts = false;
          _hasLoadedSaved = false;
          await _initialLoad();
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: Colors.black,
              actions: [
                if (isMe)
                  IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    onPressed: _pickAndUploadImage,
                    tooltip: 'Change Photo',
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    profileImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: profileImage,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey[900]),
                            errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.white)),
                          )
                        : Container(
                            color: Colors.grey[900],
                            child: const Icon(Icons.person, size: 100, color: Colors.white24),
                          ),
                    if (isMe)
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                userName,
                                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              if (isMe)
                                IconButton(
                                  icon: const Icon(Icons.edit_note, size: 20, color: Colors.green),
                                  onPressed: () => _showEditDialog('username', userName),
                                ),
                            ],
                          ),
                        ),
                        _buildActionButton(data),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Bio', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (isMe)
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
                            onPressed: () => _showEditDialog('bio', bio),
                          ),
                      ],
                    ),
                    Text(bio, style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(gymName, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 24),
                    _buildStatsRow(stats),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTabButton(0, Iconsax.grid_1, "Posts", _userPosts.length),
                        if (isMe) ...[
                          const SizedBox(width: 40),
                          _buildTabButton(1, Iconsax.archive_1, "Saved", _savedPosts.length),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _selectedTab == 0 ? _buildPostGrid() : _buildSavedGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> initialData) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('members').doc(widget.userId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? initialData;
        final followers = data['followersCount'] ?? 0;
        final followingData = data['following'];
        final following = followingData is List ? followingData.length : (followingData is int ? followingData : 0);
        final streak = data['currentStreak'] ?? initialData['currentStreak'] ?? 0;
        final workouts = data['totalWorkouts'] ?? initialData['totalWorkouts'] ?? 0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Streak', streak.toString()),
            _buildStatItem('Workouts', workouts.toString()),
            _buildStatItem('Followers', followers.toString()),
            _buildStatItem('Following', following.toString()),
          ],
        );
      }
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label, int count) {
    bool isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = index);
        if (index == 1 && !_hasLoadedSaved) _loadSavedPosts();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.transparent, // Make larger hit area
        child: Column(
          children: [
            Icon(icon, color: isActive ? Colors.green : Colors.grey),
            const SizedBox(height: 4),
            Text('$label ($count)', style: TextStyle(color: isActive ? Colors.green : Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(Map<String, dynamic> data) {
    if (_isCurrentUser()) {
      return ElevatedButton.icon(
        onPressed: () async {
          final gymId = data['gymId'];
          if (gymId != null) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberEditProfileScreen(
                  gymId: gymId,
                  memberId: widget.userId,
                  initialData: data,
                ),
              ),
            );
            _loadProfileData(); // Reload after editing
          } else {
             _showEditDialog('username', data['username'] ?? '');
          }
        },
        icon: const Icon(Icons.edit, size: 16),
        label: const Text('Update Profile'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
    }
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('members').doc(currentUser.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final followingData = data?['following'];
        final isFollowing = followingData is List ? followingData.contains(widget.userId) : false;

        return ElevatedButton(
          onPressed: () => CommunityService.instance.toggleFollow(currentUser.uid, widget.userId),
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing ? Colors.grey[800] : Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(isFollowing ? 'Following' : 'Follow'),
        );
      }
    );
  }

  Widget _buildPostGrid() {
    if (_isLoadingPosts && _userPosts.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Colors.green)));
    if (_userPosts.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text("No posts yet", style: TextStyle(color: Colors.grey))));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        return GestureDetector(
          onLongPress: _isCurrentUser() ? () => _deletePost(post.id) : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CommentsScreen(postId: post.id))),
          child: CachedNetworkImage(
            imageUrl: post.mediaUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[900]),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        );
      },
    );
  }

  Widget _buildSavedGrid() {
    if (_isLoadingSaved && _savedPosts.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Colors.green)));
    if (_savedPosts.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text("No saved posts", style: TextStyle(color: Colors.grey))));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: _savedPosts.length,
      itemBuilder: (context, index) {
        final post = _savedPosts[index];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CommentsScreen(postId: post.id))),
          child: CachedNetworkImage(
            imageUrl: post.mediaUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey[900]),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        );
      },
    );
  }
}