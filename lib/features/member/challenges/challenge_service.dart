// lib/services/challenge_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore _db = FirebaseFirestore.instance;

class ChallengeUpdateResult {
  final int xpFromChallenges;
  final List<String> earnedBadgeIds;
  final List<String> completedChallengeTitles;

  const ChallengeUpdateResult({
    required this.xpFromChallenges,
    required this.earnedBadgeIds,
    required this.completedChallengeTitles,
  });

  static const empty = ChallengeUpdateResult(
    xpFromChallenges: 0,
    earnedBadgeIds: [],
    completedChallengeTitles: [],
  );

  ChallengeUpdateResult merge(ChallengeUpdateResult other) {
    return ChallengeUpdateResult(
      xpFromChallenges: xpFromChallenges + other.xpFromChallenges,
      earnedBadgeIds: [...earnedBadgeIds, ...other.earnedBadgeIds],
      completedChallengeTitles: [
        ...completedChallengeTitles,
        ...other.completedChallengeTitles,
      ],
    );
  }
}

/// Call this whenever a real event happens:
/// - metric 'xp'      => when you grant XP
/// - metric 'workout' => when workout completed (workoutId required)
/// - metric 'visit'   => gym attendance
/// - metric 'referral','promo' => your custom flows
Future<ChallengeUpdateResult> bumpChallengeProgress({
  required String gymId,
  required String memberId,
  required String metric,
  required num delta,
  String? workoutId,
}) async {
  final now = DateTime.now();

  final challengesSnap = await _db
      .collection('global_challenges')
      .where('metric', isEqualTo: metric)
      .where('isActive', isEqualTo: true)
      .where('joinedBy', arrayContains: memberId)
      .get();

  int totalXpFromChallenges = 0;
  final List<String> earnedBadges = [];
  final List<String> completedTitles = [];

  for (final chDoc in challengesSnap.docs) {
    final raw = chDoc.data();
    final data =
    raw is Map<String, dynamic> ? raw : <String, dynamic>{};

    final challengeId = chDoc.id;

    final startAt = data['startAt'] is Timestamp
        ? (data['startAt'] as Timestamp).toDate()
        : null;
    final endAt = data['endAt'] is Timestamp
        ? (data['endAt'] as Timestamp).toDate()
        : null;

    if (startAt != null && now.isBefore(startAt)) continue;
    if (endAt != null && now.isAfter(endAt)) continue;

    if (metric == 'workout') {
      final chWorkoutId = (data['workoutId'] ?? '').toString();
      if (chWorkoutId.isEmpty || chWorkoutId != workoutId) continue;
    }

    num _numField(dynamic v) {
      if (v is num) return v;
      return num.tryParse(v?.toString() ?? '0') ?? 0;
    }

    int _intField(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '0') ?? 0;
    }

    final num targetValue = _numField(data['targetValue']);
    if (targetValue <= 0) continue;

    final int xpReward = _intField(data['xpReward']);
    final String rewardBadgeId =
    (data['rewardBadgeId'] ?? '').toString();
    final String challengeTitle =
    (data['title'] ?? '').toString();

    final achRef = _db
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(memberId)
        .collection('achievements')
        .doc('challenges')
        .collection('items')
        .doc(challengeId);

    bool shouldGrantReward = false;

    await _db.runTransaction((tx) async {
      final achSnap = await tx.get(achRef);
      final achRaw = achSnap.data();
      final achData =
      achRaw is Map<String, dynamic> ? achRaw : <String, dynamic>{};

      final String status = (achData['status'] ?? 'joined').toString();
      if (status != 'joined') {
        return;
      }

      final dynamic curRaw = achData['progressValue'];
      final num current = curRaw is num
          ? curRaw
          : num.tryParse(curRaw?.toString() ?? '0') ?? 0;

      final num newValue = current + delta;
      final bool isDone = newValue >= targetValue;

      if (!isDone) {
        tx.set(
          achRef,
          {
            'metric': metric,
            'targetValue': targetValue,
            'progressValue': newValue,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return;
      }

      final bool alreadyCompleted =
          (achData['status'] ?? '') == 'completed';
      final bool rewardGranted =
          achData['rewardGranted'] == true;

      shouldGrantReward = !(alreadyCompleted || rewardGranted);

      tx.set(
        achRef,
        {
          'metric': metric,
          'targetValue': targetValue,
          'progressValue': newValue,
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'rewardGranted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      tx.update(chDoc.reference, {
        'completedBy': FieldValue.arrayUnion([memberId]),
      });
    });

    if (shouldGrantReward) {
      // apply rewards in DB
      await _applyChallengeRewards(
        gymId: gymId,
        memberId: memberId,
        challengeId: challengeId,
        challengeTitle: challengeTitle,
        xpReward: xpReward,
        rewardBadgeId: rewardBadgeId,
      );

      if (xpReward > 0) {
        totalXpFromChallenges += xpReward;
      }
      if (rewardBadgeId.isNotEmpty) {
        earnedBadges.add(rewardBadgeId);
      }
      completedTitles.add(challengeTitle);
    }
  }

  return ChallengeUpdateResult(
    xpFromChallenges: totalXpFromChallenges,
    earnedBadgeIds: earnedBadges,
    completedChallengeTitles: completedTitles,
  );
}

Future<void> _applyChallengeRewards({
  required String gymId,
  required String memberId,
  required String challengeId,
  required String challengeTitle,
  required int xpReward,
  required String rewardBadgeId,
}) async {
  final memberRef = _db
      .collection('gyms')
      .doc(gymId)
      .collection('members')
      .doc(memberId);

  final batch = _db.batch();

  if (xpReward > 0) {
    final xpLogRef = memberRef.collection('xp_logs').doc();
    batch.set(xpLogRef, {
      'amount': xpReward,
      'reason': 'challenge_completed',
      'challengeId': challengeId,
      'title': challengeTitle,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final statsRef = memberRef
        .collection('meta')
        .doc('stats');
    batch.set(
      statsRef,
      {
        'totalXp': FieldValue.increment(xpReward),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  if (rewardBadgeId.isNotEmpty) {
    final badgeRef = memberRef
        .collection('achievements')
        .doc('badges')
        .collection('items')
        .doc(rewardBadgeId);

    batch.set(
      badgeRef,
      {
        'badgeId': rewardBadgeId,
        'challengeId': challengeId,
        'title': challengeTitle,
        'earnedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
  Future<void> markChallengeCompletedOnce({
    required String gymId,
    required String memberId,
    required String challengeId,
  }) async {
    final db = FirebaseFirestore.instance;

    final challengeRef =
    db.collection('global_challenges').doc(challengeId);

    final achievementRef = db
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(memberId)
        .collection('achievements')
        .doc('challenges')
        .collection('items')
        .doc(challengeId);

    await db.runTransaction((tx) async {
      final chSnap = await tx.get(challengeRef);
      if (!chSnap.exists) return;

      final achSnap = await tx.get(achievementRef);
      final achData =
          (achSnap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

      final alreadyCompleted =
          (achData['status'] ?? '') == 'completed';

      if (alreadyCompleted) return;

      tx.update(challengeRef, {
        'completedBy': FieldValue.arrayUnion([memberId]),
      });

      tx.set(
        achievementRef,
        {
          'challengeId': challengeId,
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  await batch.commit();
}
