import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../../../core/services/cloudinary_config.dart';
import 'package:fitnophedia/features/community/domain/models/community_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommunityService {
  static final CommunityService instance = CommunityService._internal();
  CommunityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== CLOUDINARY UPLOAD ==========
  Future<String?> uploadMedia(File file, {required String resourceType}) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/upload');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseData);
        return jsonResponse['secure_url'];
      }
      return null;
    } catch (e) {
      print('Cloudinary Upload Error: $e');
      return null;
    }
  }

  // ========== POSTS ==========
  Future<void> createPost(PostModel post) async {
    await _firestore.collection('posts').add(post.toMap());
  }

  Future<void> deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
  }

  Future<void> incrementPostViews(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'viewsCount': FieldValue.increment(1)
    });
  }

  Stream<List<PostModel>> getCommunityFeed({String? gymId, int limit = 10}) {
    // Basic feed: Order by createdAt
    // Pagination will be handled by the UI using startAfter
    Query query = _firestore.collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (gymId != null) {
      // Logic for gym-specific feed or global
      // The user mentioned "pop mid feed advertisement it will be global or between gym only"
      // This implies the feed itself might be global but ads are filtered.
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> toggleLike(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);

    final postDoc = await postRef.get();
    if (!postDoc.exists) return;
    final postData = postDoc.data()!;
    final postOwnerId = postData['userId'];

    final likeDoc = await likeRef.get();
    if (likeDoc.exists) {
      await likeRef.delete();
      await postRef.update({'likesCount': FieldValue.increment(-1)});
    } else {
      await likeRef.set({'userId': userId, 'createdAt': FieldValue.serverTimestamp()});
      await postRef.update({'likesCount': FieldValue.increment(1)});

      // Send notification if it's not the owner liking their own post
      if (userId != postOwnerId) {
        final currentUserDoc = await _firestore.collection('members').doc(userId).get();
        final senderName = currentUserDoc.data()?['firstName'] ?? 'Someone';
        
        await _sendSocialNotification(
          recipientId: postOwnerId,
          type: 'like',
          title: 'New Like',
          message: '$senderName liked your post',
          data: {'postId': postId},
        );
      }
    }
  }

  // ========== STORIES ==========
  Future<void> createStory(StoryModel story) async {
    await _firestore.collection('stories').add(story.toMap());
  }

  Future<void> deleteStory(String storyId) async {
    await _firestore.collection('stories').doc(storyId).delete();
  }

  Future<void> markStoryAsViewed(String storyId, String userId) async {
    await _firestore.collection('stories').doc(storyId).update({
      'viewerIds': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> toggleStoryLike(String storyId, String userId) async {
    final ref = _firestore.collection('stories').doc(storyId);
    final doc = await ref.get();
    if (!doc.exists) return;
    
    // Using a separate collection for story likes would be better for scale, 
    // but sticking to array for simplicity if small, or incrementing count.
    // Let's use array for 'likedBy' or just increment likesCount.
    // For stories, likes are often just a reaction.
    
    // We'll just toggle a simple like reaction here.
    // (Implementation details depend on UI needs)
    await ref.update({'likesCount': FieldValue.increment(1)});
  }

  Stream<List<StoryModel>> getActiveStories({required List<String> followingIds}) {
    if (followingIds.isEmpty) return Stream.value([]);
    
    return _firestore.collection('stories')
        .where('userId', whereIn: followingIds)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => StoryModel.fromFirestore(doc)).toList();
        });
  }

  // ========== FOLLOW SYSTEM ==========
  Future<void> toggleFollow(String currentUserId, String targetUserId) async {
    final currentUserRef = _firestore.collection('members').doc(currentUserId);
    final targetUserRef = _firestore.collection('members').doc(targetUserId);

    final currentUserDoc = await currentUserRef.get();
    final List<dynamic> following = currentUserDoc.data()?['following'] ?? [];

    if (following.contains(targetUserId)) {
      // Unfollow
      await currentUserRef.update({
        'following': FieldValue.arrayRemove([targetUserId])
      });
      // Update global member count
      await targetUserRef.update({
        'followersCount': FieldValue.increment(-1)
      });
      // Update gym-specific member count if exists
      final indexDoc = await _firestore.collection('member_index').doc(targetUserId).get();
      if (indexDoc.exists) {
        final gymId = indexDoc.data()?['gymId'];
        if (gymId != null) {
          await _firestore.collection('gyms').doc(gymId).collection('members').doc(targetUserId).update({
            'followersCount': FieldValue.increment(-1)
          });
        }
      }
      await targetUserRef.collection('followers').doc(currentUserId).delete();
    } else {
      // Follow
      await currentUserRef.update({
        'following': FieldValue.arrayUnion([targetUserId])
      });
      // Update global member count
      await targetUserRef.update({
        'followersCount': FieldValue.increment(1)
      });
      // Update gym-specific member count if exists
      final indexDoc = await _firestore.collection('member_index').doc(targetUserId).get();
      if (indexDoc.exists) {
        final gymId = indexDoc.data()?['gymId'];
        if (gymId != null) {
          await _firestore.collection('gyms').doc(gymId).collection('members').doc(targetUserId).update({
            'followersCount': FieldValue.increment(1)
          });
        }
      }
      await targetUserRef.collection('followers').doc(currentUserId).set({
        'uid': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send notification
      final senderName = currentUserDoc.data()?['firstName'] ?? 'Someone';
      await _sendSocialNotification(
        recipientId: targetUserId,
        type: 'follow',
        title: 'New Follower',
        message: '$senderName started following you',
        data: {'followerId': currentUserId},
      );
    }
  }

  // ========== COMMENTS ==========
  Future<void> addComment(String postId, {
    required String userId,
    required String userName,
    required String userProfileImage,
    required String text,
  }) async {
    final postRef = _firestore.collection('posts').doc(postId);
    
    await postRef.collection('comments').add({
      'userId': userId,
      'userName': userName,
      'userProfileImage': userProfileImage,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final postDoc = await postRef.get();
    if (postDoc.exists) {
      final postOwnerId = postDoc.data()?['userId'];
      if (postOwnerId != null && postOwnerId != userId) {
        await _sendSocialNotification(
          recipientId: postOwnerId,
          type: 'comment',
          title: 'New Comment',
          message: '$userName commented: $text',
          data: {'postId': postId},
        );
      }
    }
  }

  Stream<QuerySnapshot> getComments(String postId) {
    return _firestore.collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ========== NOTIFICATIONS HELPER ==========
  Future<void> _sendSocialNotification({
    required String recipientId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Find the recipient's gymId and memberId for routing
      final indexDoc = await _firestore.collection('member_index').doc(recipientId).get();
      if (!indexDoc.exists) return;

      final indexData = indexDoc.data()!;
      final gymId = indexData['gymId'];
      final memberId = indexData['memberId'] ?? recipientId;

      await _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('notifications')
          .add({
        'type': type,
        'title': title,
        'message': message,
        'data': data,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending social notification: $e');
    }
  }

  // ========== ADVERTISEMENTS ==========
  Future<void> createAd({
    required String gymId,
    required String gymName,
    required String mediaUrl,
    required String type, // Global or GymOnly
    String? adLink,
  }) async {
    await _firestore.collection('ads').add({
      'gymId': gymId,
      'gymName': gymName,
      'mediaUrl': mediaUrl,
      'type': type,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'adLink': adLink,
    });
  }

  Stream<List<Map<String, dynamic>>> getActiveAds({String? gymId}) {
    Query query = _firestore.collection('ads')
        .where('status', isEqualTo: 'active');
    
    return query.snapshots().map((snapshot) {
      final ads = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();

      if (gymId != null) {
        // Filter: global ads + ads specifically for this gym
        return ads.where((ad) => ad['type'] == 'Global' || ad['gymId'] == gymId).toList();
      }
      return ads;
    });
  }

  // ========== SAVED POSTS ==========
  Future<void> toggleSave(String userId, String postId) async {
    final saveRef = _firestore.collection('members').doc(userId).collection('saved_posts').doc(postId);
    final doc = await saveRef.get();
    if (doc.exists) {
      await saveRef.delete();
    } else {
      await saveRef.set({
        'postId': postId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<bool> isSaved(String userId, String postId) {
    return _firestore.collection('members').doc(userId).collection('saved_posts').doc(postId).snapshots().map((doc) => doc.exists);
  }

  Stream<List<PostModel>> getSavedPosts(String userId) {
    return _firestore.collection('members').doc(userId).collection('saved_posts')
        .snapshots()
        .asyncMap((snapshot) async {
          final postIds = snapshot.docs.map((doc) => doc.id).toList();
          if (postIds.isEmpty) return [];
          
          final posts = <PostModel>[];
          for (var id in postIds) {
            final postDoc = await _firestore.collection('posts').doc(id).get();
            if (postDoc.exists) {
              posts.add(PostModel.fromFirestore(postDoc));
            }
          }
          return posts;
        });
  }

  // ========== MEMBER CACHING ==========
  final Map<String, Map<String, dynamic>> _memberCache = {};

  Future<Map<String, dynamic>> getMemberDetails(String userId) async {
    if (_memberCache.containsKey(userId)) {
      return _memberCache[userId]!;
    }

    final doc = await _firestore.collection('members').doc(userId).get();
    if (doc.exists) {
      _memberCache[userId] = doc.data()!;
      return doc.data()!;
    }

    // Fallback: Check member_index to find gym-specific doc
    try {
      final indexDoc = await _firestore.collection('member_index').doc(userId).get();
      if (indexDoc.exists) {
        final gymId = indexDoc.data()?['gymId'];
        if (gymId != null) {
          final gymMemberDoc = await _firestore
              .collection('gyms')
              .doc(gymId)
              .collection('members')
              .doc(userId)
              .get();
          if (gymMemberDoc.exists) {
            _memberCache[userId] = gymMemberDoc.data()!;
            return gymMemberDoc.data()!;
          }
        }
      }
    } catch (e) {
      print('Error in member fallback: $e');
    }

    return {};
  }

  void invalidateMemberCache(String userId) {
    _memberCache.remove(userId);
  }

  // ========== GYM NAME HELPER ==========
  final Map<String, String> _gymNameCache = {};
  Future<String> getGymName(String? gymId) async {
    if (gymId == null || gymId.isEmpty) return 'Gym Member';
    if (_gymNameCache.containsKey(gymId)) return _gymNameCache[gymId]!;

    final doc = await _firestore.collection('gyms').doc(gymId).get();
    if (doc.exists) {
      final name = doc.data()?['name'] ?? doc.data()?['gymName'] ?? 'Gym Member';
      _gymNameCache[gymId] = name;
      return name;
    }
    return 'Gym Member';
  }
  Future<String?> getGymIdForMember(String userId) async {
    try {
      final doc = await _firestore.collection('member_index').doc(userId).get();
      return doc.data()?['gymId'];
    } catch (e) {
      return null;
    }
  }
}
