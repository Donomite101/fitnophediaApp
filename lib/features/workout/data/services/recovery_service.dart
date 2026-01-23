import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RecoveryService {
  RecoveryService._();
  static final RecoveryService instance = RecoveryService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Constants for recovery calculation
  static const double _recoveryRatePerHour = 4.0; // Recovers 4% per hour
  static const double _maxRecovery = 100.0;
  static const double _minRecovery = 0.0;

  /// Fetches the current recovery score, accounting for time elapsed since last update.
  Future<int> getRecoveryScore(String gymId, String memberId) async {
    try {
      final doc = await _db
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('stats')
          .doc('recovery')
          .get();

      if (!doc.exists) return 100; // Default to full recovery if no data

      final data = doc.data()!;
      double storedScore = (data['score'] as num?)?.toDouble() ?? 100.0;
      final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();

      if (lastUpdated == null) return storedScore.toInt();

      // Calculate recovery gain based on time elapsed
      final now = DateTime.now();
      final hoursElapsed = now.difference(lastUpdated).inMinutes / 60.0;
      final recoveryGain = hoursElapsed * _recoveryRatePerHour;

      final currentScore = min(_maxRecovery, storedScore + recoveryGain);
      
      return currentScore.toInt();
    } catch (e) {
      debugPrint("Error fetching recovery score: $e");
      return 100; // Fallback
    }
  }

  /// Updates the recovery score after a workout.
  /// [durationMinutes]: Duration of the workout in minutes.
  /// [intensity]: 1 (Low), 2 (Medium), 3 (High). Default is 2.
  Future<void> updateRecoveryScore({
    required String gymId,
    required String memberId,
    required int durationMinutes,
    int intensity = 2,
  }) async {
    try {
      // 1. Get current effective score first
      final currentScore = await getRecoveryScore(gymId, memberId);

      // 2. Calculate impact
      // Formula: Duration (min) * IntensityFactor * 0.5
      // Intensity Factors: Low=0.5, Medium=1.0, High=1.5
      double intensityFactor = 1.0;
      if (intensity == 1) intensityFactor = 0.5;
      if (intensity == 3) intensityFactor = 1.5;

      final impact = (durationMinutes * intensityFactor * 0.5);
      
      // 3. Calculate new score
      double newScore = currentScore - impact;
      newScore = max(_minRecovery, newScore); // Clamp to 0

      debugPrint("📉 Recovery Update: Current=$currentScore, Impact=$impact, New=$newScore");

      // 4. Save to Firestore
      await _db
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('stats')
          .doc('recovery')
          .set({
        'score': newScore,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint("Error updating recovery score: $e");
    }
  }
}
