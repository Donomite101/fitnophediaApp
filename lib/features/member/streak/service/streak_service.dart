import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../challenges/challenge_service.dart';

class StreakService {
  StreakService._();
  static final StreakService instance = StreakService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toDouble(dynamic value, {double defaultValue = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  Future<Position> getCurrentPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }
  Future<List<bool>> getActiveDaysForCurrentWeek({
    required String gymId,
    required String memberId,
  }) async {
    final now = DateTime.now();

    // DateTime.weekday: Monday = 1, Sunday = 7
    final int weekday = now.weekday;

    // Start of week = Monday
    final DateTime monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: weekday - 1));

    final gymRef = _db.collection('gyms').doc(gymId);
    final memberRef = gymRef.collection('members').doc(memberId);
    final attRef = memberRef.collection('attendance');

    // Build DateTimes for Monday..Sunday
    final List<DateTime> weekDays = List.generate(
      7,
          (i) => monday.add(Duration(days: i)),
    );

    // Convert to your 'yyyy-MM-dd' keys
    final dateFormat = DateFormat('yyyy-MM-dd');
    final List<String> keys =
    weekDays.map((d) => dateFormat.format(d)).toList();

    // Fetch all 7 attendance docs
    final List<DocumentSnapshot> snaps = await Future.wait(
      keys.map((k) => attRef.doc(k).get()),
    );

    // Map Firestore docs -> bools (present => true)
    final List<bool> activeDays = <bool>[];

    for (final snap in snaps) {
      if (!snap.exists) {
        activeDays.add(false);
        continue;
      }

      final data = snap.data() as Map<String, dynamic>? ?? {};
      final bool present = data['present'] == true;

      // If you want holidays to also count as active, this is enough.
      // If you ever want to exclude holidays, you can check `data['holiday']`.
      activeDays.add(present);
    }

    // activeDays[0] -> Monday, [1] -> Tuesday, ... [6] -> Sunday
    return activeDays;
  }

  Future<StreakResult> recordAttendanceAndUpdateStreak({
    required String gymId,
    required String memberId,
    Position? overridePosition,
  }) async {
    try {
      final now = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(now);

      final gymRef = _db.collection('gyms').doc(gymId);
      final memberRef = gymRef.collection('members').doc(memberId);
      final attRef = memberRef.collection('attendance').doc(todayKey);
      final streakRef = memberRef.collection('stats').doc('streak');

      // 1) Prevent double check-in
      final attSnap = await attRef.get();
      if (attSnap.exists) {
        return StreakResult(
          success: true,
          message: 'Attendance already recorded for today',
          newStreakCount: null,
          celebrate: false,
        );
      }

      // 2) Load gym (geofence + holidays)
      final gymSnap = await gymRef.get();
      if (!gymSnap.exists) {
        return StreakResult(
          success: false,
          message: 'Gym not found',
          newStreakCount: null,
          celebrate: false,
        );
      }

      final gymData = gymSnap.data() as Map<String, dynamic>;

      // Handle GeoPoint OR Map for location
      final dynamic rawLocation = gymData['location'];

      GeoPoint? geoLocation;
      Map<String, dynamic>? locationMap;

      if (rawLocation is GeoPoint) {
        geoLocation = rawLocation;
      } else if (rawLocation is Map<String, dynamic>) {
        locationMap = rawLocation;
      }

      final holidaysMap = Map<String, dynamic>.from(gymData['holidays'] ?? {});
      final bool isHoliday = holidaysMap[todayKey] == true;

      // 3) Device location
      late final Position position;
      try {
        position = overridePosition ?? await getCurrentPosition();
      } catch (e) {
        return StreakResult(
          success: false,
          message: 'Location permission failed: $e',
          newStreakCount: null,
          celebrate: false,
        );
      }

      // 4) Geofence
      double? gymLat;
      double? gymLng;
      double radius = 100.0; // default radius

      if (geoLocation != null) {
        // New schema: location is GeoPoint, radius stored separately
        gymLat = geoLocation.latitude;
        gymLng = geoLocation.longitude;
        radius = _toDouble(
          gymData['radiusMeters'] ?? gymData['geofenceRadiusMeters'] ?? 100,
          defaultValue: 100,
        );
      } else if (locationMap != null) {
        // Old schema: location is a Map { lat, lng, radiusMeters }
        if (locationMap.containsKey('lat') && locationMap.containsKey('lng')) {
          gymLat = _toDouble(locationMap['lat']);
          gymLng = _toDouble(locationMap['lng']);
        }
        radius = _toDouble(
          locationMap['radiusMeters'] ?? 100,
          defaultValue: 100,
        );
      }

      if (gymLat != null && gymLng != null) {
        final dist = _distanceMeters(
          position.latitude,
          position.longitude,
          gymLat,
          gymLng,
        );

        if (dist > radius) {
          return StreakResult(
            success: false,
            message: 'You are outside the gym geofence.',
            newStreakCount: null,
            celebrate: false,
          );
        }
      }
      // If no valid gymLat/gymLng, geofence check is simply skipped.

      // 5) Record attendance
      await attRef.set({
        'present': true,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'geofence+workout',
        'holiday': isHoliday,
        'deviceLat': position.latitude,
        'deviceLng': position.longitude,
      });

      // 6) Load streak
      final streakSnap = await streakRef.get();
      int current = 0;
      int longest = 0;
      String? lastCounted;

      if (streakSnap.exists) {
        final d = streakSnap.data() as Map<String, dynamic>;
        current = _readInt(d, 'currentStreak');
        longest = _readInt(d, 'longestStreak');
        lastCounted = d['lastCounted'] as String?;
      }

      final previousStreak = current;

      // 7) Holiday: freeze streak (no increase, no celebration)
      if (isHoliday) {
        await streakRef.set(
          {
            'lastCounted': todayKey,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return StreakResult(
          success: true,
          message: 'Attendance recorded (holiday), streak preserved',
          newStreakCount: current,
          celebrate: false,
        );
      }

      // Already counted (safety)
      if (lastCounted == todayKey) {
        return StreakResult(
          success: true,
          message: 'Attendance already counted today',
          newStreakCount: current,
          celebrate: false,
        );
      }

      // 8) Compute new streak (robust date diff)
      if (lastCounted != null) {
        try {
          final lastDate = DateFormat('yyyy-MM-dd').parse(lastCounted);
          final daysDifference = now.difference(lastDate).inDays;

          if (daysDifference == 1) {
            current += 1;
          } else {
            current = 1;
          }
        } catch (e) {
          debugPrint('Error parsing lastCounted date: $e');
          current = 1;
        }
      } else {
        current = 1;
      }

      if (current > longest) longest = current;

      // 9) Persist streak
      await streakRef.set(
        {
          'currentStreak': current,
          'longestStreak': longest,
          'lastCounted': todayKey,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // bump visit-based challenges
      await bumpChallengeProgress(
        gymId: gymId,
        memberId: memberId,
        metric: 'visit',
        delta: 1,
      );

      final bool shouldCelebrate = current > previousStreak;

      debugPrint(
        'Streak updated: previous=$previousStreak, current=$current, '
            'longest=$longest, celebrate=$shouldCelebrate',
      );

      return StreakResult(
        success: true,
        message: 'Streak updated to $current days',
        newStreakCount: current,
        celebrate: shouldCelebrate,
      );
    } catch (e, st) {
      debugPrint('StreakService error: $e\n$st');
      return StreakResult(
        success: false,
        message: 'Failed to record attendance: $e',
        newStreakCount: null,
        celebrate: false,
      );
    }
  }

  int _readInt(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }
}

class StreakResult {
  final bool success;
  final String message;
  final int? newStreakCount;
  final bool celebrate;

  StreakResult({
    required this.success,
    required this.message,
    this.newStreakCount,
    this.celebrate = false,
  });
}
