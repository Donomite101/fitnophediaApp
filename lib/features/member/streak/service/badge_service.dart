import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/badge_model.dart';

class BadgeService {
  static final BadgeService _instance = BadgeService._();
  factory BadgeService() => _instance;
  BadgeService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Save all user badges to Firestore
  Future<void> saveUserBadges({
    required String gymId,
    required String memberId,
    required List<BadgeModel> badges,
  }) async {
    try {
      final badgesRef = _db
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('achievements')
          .doc('badges');

      final badgesData = badges.map((badge) => badge.toMap()).toList();

      await badgesRef.set({
        'badges': badgesData,
        'updatedAt': FieldValue.serverTimestamp(),
        'totalUnlocked': badges.where((b) => b.unlocked).length,
        'totalBadges': badges.length,
      }, SetOptions(merge: true));

      debugPrint('✅ Saved ${badges.length} badges to Firestore (${badges.where((b) => b.unlocked).length} unlocked)');
    } catch (e) {
      debugPrint('❌ Error saving badges: $e');
      rethrow;
    }
  }

  /// Load user badges from Firestore
  Future<List<BadgeModel>> loadUserBadges({
    required String gymId,
    required String memberId,
  }) async {
    try {
      final badgesRef = _db
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('achievements')
          .doc('badges');

      final snapshot = await badgesRef.get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final badgesList = (data['badges'] as List<dynamic>)
            .map((item) => BadgeModel.fromMap(item as Map<String, dynamic>))
            .toList();

        debugPrint('✅ Loaded ${badgesList.length} badges from Firestore');
        return badgesList;
      } else {
        debugPrint('📭 No badges found in Firestore, returning empty list');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error loading badges: $e');
      return [];
    }
  }

  /// Unlock a specific badge
  Future<void> unlockBadge({
    required String gymId,
    required String memberId,
    required String badgeTitle,
  }) async {
    try {
      final badgesRef = _db
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('achievements')
          .doc('badges');

      // Get current badges
      final snapshot = await badgesRef.get();
      List<dynamic> badgesData = [];

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        badgesData = List<dynamic>.from(data['badges'] ?? []);

        // Update the specific badge
        bool badgeFound = false;
        for (int i = 0; i < badgesData.length; i++) {
          final badge = badgesData[i] as Map<String, dynamic>;
          if (badge['title'] == badgeTitle && !(badge['unlocked'] ?? false)) {
            badgesData[i]['unlocked'] = true;
            badgesData[i]['unlockedAt'] = DateTime.now().toIso8601String();
            badgeFound = true;
            debugPrint('🎉 Unlocked badge: $badgeTitle');
            break;
          }
        }

        if (!badgeFound) {
          debugPrint('⚠️  Badge not found or already unlocked: $badgeTitle');
        }
      } else {
        debugPrint('📭 No badges document found');
        return;
      }

      // Update total unlocked count
      final totalUnlocked = badgesData
          .where((badge) => (badge as Map<String, dynamic>)['unlocked'] == true)
          .length;

      await badgesRef.set({
        'badges': badgesData,
        'updatedAt': FieldValue.serverTimestamp(),
        'totalUnlocked': totalUnlocked,
        'totalBadges': badgesData.length,
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint('❌ Error unlocking badge: $e');
      rethrow;
    }
  }

  /// Check if a badge is already unlocked
  Future<bool> isBadgeUnlocked({
    required String gymId,
    required String memberId,
    required String badgeTitle,
  }) async {
    try {
      final badgesRef = _db
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('achievements')
          .doc('badges');

      final snapshot = await badgesRef.get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final badgesList = (data['badges'] as List<dynamic>)
            .map((item) => BadgeModel.fromMap(item as Map<String, dynamic>))
            .toList();

        final badge = badgesList.firstWhere(
              (b) => b.title == badgeTitle,
          orElse: () => BadgeModel(
            icon: '',
            title: '',
            description: '',
            color: Colors.black,
            unlocked: false,
            category: '',
            criteria: BadgeCriteria(type: BadgeType.streak, threshold: 0),
          ),
        );

        return badge.unlocked;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking badge status: $e');
      return false;
    }
  }

  /// Get user's badge statistics
  Future<Map<String, dynamic>> getBadgeStats({
    required String gymId,
    required String memberId,
  }) async {
    try {
      final badgesRef = _db
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('achievements')
          .doc('badges');

      final snapshot = await badgesRef.get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        return {
          'totalBadges': data['totalBadges'] ?? 0,
          'totalUnlocked': data['totalUnlocked'] ?? 0,
          'updatedAt': data['updatedAt'],
        };
      }

      return {
        'totalBadges': 0,
        'totalUnlocked': 0,
        'updatedAt': null,
      };
    } catch (e) {
      debugPrint('❌ Error getting badge stats: $e');
      return {
        'totalBadges': 0,
        'totalUnlocked': 0,
        'updatedAt': null,
      };
    }
  }

  /// Get recently unlocked badges
  Future<List<BadgeModel>> getRecentlyUnlockedBadges({
    required String gymId,
    required String memberId,
    int limit = 3,
  }) async {
    try {
      final badges = await loadUserBadges(gymId: gymId, memberId: memberId);

      final unlockedBadges = badges.where((b) => b.unlocked).toList();

      // Sort by unlock date (most recent first)
      unlockedBadges.sort((a, b) {
        if (a.unlockedAt == null) return 1;
        if (b.unlockedAt == null) return -1;
        return b.unlockedAt!.compareTo(a.unlockedAt!);
      });

      return unlockedBadges.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Error getting recently unlocked badges: $e');
      return [];
    }
  }
}