import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String userProfileImage;
  final String mediaUrl;
  final String mediaType;
  final String caption;
  final int likesCount;
  final int viewsCount;
  final String? gymId;
  final bool isAd;
  final String? adLink;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userProfileImage,
    required this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.likesCount,
    this.viewsCount = 0,
    this.gymId,
    this.isAd = false,
    this.adLink,
    required this.createdAt,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Member',
      userProfileImage: data['userProfileImage'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      mediaType: data['mediaType'] ?? 'image',
      caption: data['caption'] ?? '',
      likesCount: data['likesCount'] ?? 0,
      viewsCount: data['viewsCount'] ?? 0,
      gymId: data['gymId'],
      isAd: data['isAd'] ?? false,
      adLink: data['adLink'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userProfileImage': userProfileImage,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'caption': caption,
      'likesCount': likesCount,
      'viewsCount': viewsCount,
      'gymId': gymId,
      'isAd': isAd,
      'adLink': adLink,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class StoryModel {
  final String id;
  final String userId;
  final String userName;
  final String userProfileImage;
  final String mediaUrl;
  final int likesCount;
  final List<String> viewerIds;
  final DateTime expiresAt;
  final DateTime createdAt;

  StoryModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userProfileImage,
    required this.mediaUrl,
    this.likesCount = 0,
    this.viewerIds = const [],
    required this.expiresAt,
    required this.createdAt,
  });

  factory StoryModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return StoryModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Member',
      userProfileImage: data['userProfileImage'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      likesCount: data['likesCount'] ?? 0,
      viewerIds: List<String>.from(data['viewerIds'] ?? []),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 24)),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userProfileImage': userProfileImage,
      'mediaUrl': mediaUrl,
      'likesCount': likesCount,
      'viewerIds': viewerIds,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
