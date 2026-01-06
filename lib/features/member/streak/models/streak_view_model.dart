import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/badge_model.dart';
import '../service/badge_service.dart';

class StreakViewModel extends ChangeNotifier {
  final String gymId;
  final String memberId;

  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalWorkouts = 0;
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();
  bool _isDarkMode = false;

  List<DateTime> workoutDates = [];

  // NEW: week activity for Mon..Sun as booleans
  // index 0 = Monday, 6 = Sunday
  List<bool> _weekActiveDays = List<bool>.filled(7, false);

  List<BadgeModel> badges = [];

  final BadgeService _badgeService = BadgeService();

  final Color primaryBlue = const Color(0xFF2196F3);
  final Color lightBlue = const Color(0xFFE3F2FD);
  final Color darkBlue = const Color(0xFF1976D2);
  final Color accentOrange = const Color(0xFFFF9800);
  final Color accentGreen = const Color(0xFF4CAF50);
  final Color pureBlack = const Color(0xFF000000);
  final Color pureWhite = const Color(0xFFFFFFFF);
  final Color darkGrey = const Color(0xFF121212);
  final Color lightGrey = const Color(0xFFF5F5F5);
  final Color mediumGrey = const Color(0xFF666666);

  final StreamController<bool> _themeController = StreamController<bool>.broadcast();

  StreakViewModel({
    required this.gymId,
    required this.memberId,
  });

  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get totalWorkouts => _totalWorkouts;
  bool get isLoading => _isLoading;
  DateTime get selectedMonth => _selectedMonth;
  bool get isDarkMode => _isDarkMode;

  // NEW: expose week active days (Mon..Sun)
  List<bool> get weekActiveDays => _weekActiveDays;

  Stream<bool> get themeStream => _themeController.stream;

  Color get backgroundColor => _isDarkMode ? pureBlack : pureWhite;
  Color get cardColor => _isDarkMode ? darkGrey : lightGrey;
  Color get textColor => _isDarkMode ? pureWhite : pureBlack;
  Color get secondaryTextColor => _isDarkMode ? const Color(0xFFB0B0B0) : mediumGrey;
  Color get streakColor => primaryBlue;
  Color get workoutColor => accentOrange;

  void updateTheme(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final newDarkMode = brightness == Brightness.dark;

    if (_isDarkMode != newDarkMode) {
      _isDarkMode = newDarkMode;
      _themeController.add(_isDarkMode);
      notifyListeners();
    }
  }

  Future<void> loadStreakData() async {
    try {
      final savedBadges = await _badgeService.loadUserBadges(
        gymId: gymId,
        memberId: memberId,
      );

      final streakDoc = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('stats')
          .doc('streak')
          .get();

      if (streakDoc.exists) {
        final data = streakDoc.data() as Map<String, dynamic>;
        _currentStreak = _parseInt(data['currentStreak']);
        _longestStreak = _parseInt(data['longestStreak']);
      }

      final statsCollection = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('stats')
          .get();

      bool foundTotalWorkouts = false;
      for (final doc in statsCollection.docs) {
        final data = doc.data() as Map<String, dynamic>;
        for (final key in data.keys) {
          if (key.toLowerCase().contains('total') &&
              (key.toLowerCase().contains('workout') ||
                  key.toLowerCase().contains('workouts'))) {
            _totalWorkouts = _parseInt(data[key]);
            foundTotalWorkouts = true;
            break;
          }
          if (key == 'total' || key == 'workouts' || key == 'workoutCount' ||
              key == 'totalCount' || key == 'count') {
            _totalWorkouts = _parseInt(data[key]);
            foundTotalWorkouts = true;
            break;
          }
        }
        if (foundTotalWorkouts) break;
      }

      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('attendance')
          .orderBy('timestamp', descending: true)
          .get();

      final List<DateTime> dates = [];
      int validWorkoutCount = 0;

      for (final doc in attendanceSnapshot.docs) {
        final timestamp = doc['timestamp'] as Timestamp?;
        final present = doc['present'] as bool? ?? true;
        if (timestamp != null && present) {
          dates.add(timestamp.toDate());
          validWorkoutCount++;
        }
      }

      workoutDates = dates;

      if (!foundTotalWorkouts) {
        _totalWorkouts = validWorkoutCount;
      }

      // NEW: compute Mon–Sun active days based on workoutDates
      _updateWeekActiveDays();

      await _calculateAndUpdateBadges();
      await _mergeWithSavedBadges(savedBadges);

      _isLoading = false;
      notifyListeners();

    } catch (e) {
      _loadMockData();
    }
  }

  // NEW: compute week activity from workoutDates
  void _updateWeekActiveDays() {
    if (workoutDates.isEmpty) {
      _weekActiveDays = List<bool>.filled(7, false);
      return;
    }

    final now = DateTime.now();

    // Start of week (Monday)
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1)); // Monday

    // Normalize all workout dates to Y-M-D to ignore time
    final Set<DateTime> normalizedWorkoutDates = workoutDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    final List<bool> result = List<bool>.filled(7, false);

    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final normalizedDay = DateTime(day.year, day.month, day.day);
      result[i] = normalizedWorkoutDates.contains(normalizedDay);
    }

    _weekActiveDays = result;

    // Optional debug:
    // debugPrint('Week active days (Mon..Sun): $_weekActiveDays');
  }

  Future<void> _calculateAndUpdateBadges() async {
    final int totalWorkoutsCount = workoutDates.length;

    final allBadges = [
      BadgeModel(
        icon: '🎯',
        title: 'First Timer',
        description: 'Complete your very first workout',
        color: const Color(0xFF00BCD4),
        unlocked: totalWorkoutsCount >= 1,
        category: 'Featured',
        criteria: BadgeCriteria(type: BadgeType.totalWorkouts, threshold: 1),
        isNew: totalWorkoutsCount == 1,
      ),
      BadgeModel(
        icon: '🔥',
        title: 'Streak Starter',
        description: 'Start a 3-day workout streak',
        color: const Color(0xFFFF5722),
        unlocked: _currentStreak >= 3,
        category: 'Featured',
        criteria: BadgeCriteria(type: BadgeType.streak, threshold: 3),
      ),
      BadgeModel(
        icon: '💪',
        title: 'Weekly Warrior',
        description: 'Complete 3 workouts in a week',
        color: const Color(0xFF4CAF50),
        unlocked: _weeklyWorkoutsCount() >= 3,
        category: 'Weekly Achievement',
        criteria: BadgeCriteria(type: BadgeType.weeklyWorkouts, threshold: 3),
      ),
      BadgeModel(
        icon: '⭐',
        title: '5 Workouts',
        description: 'Complete 5 total workouts',
        color: const Color(0xFFFFC107),
        unlocked: totalWorkoutsCount >= 5,
        category: 'Featured',
        criteria: BadgeCriteria(type: BadgeType.totalWorkouts, threshold: 5),
      ),
      BadgeModel(
        icon: '🚀',
        title: 'Active Starter',
        description: "You've conquered your first daily goal!",
        color: primaryBlue,
        unlocked: totalWorkoutsCount >= 1,
        category: 'Featured',
        criteria: BadgeCriteria(type: BadgeType.totalWorkouts, threshold: 1),
      ),
      BadgeModel(
        icon: '🏆',
        title: 'High Achiever',
        description: 'Completed 10 consecutive days of workouts',
        color: accentOrange,
        unlocked: _currentStreak >= 10,
        category: 'Featured',
        criteria: BadgeCriteria(type: BadgeType.streak, threshold: 10),
      ),
      BadgeModel(
        icon: '💎',
        title: 'Dedicated Athlete',
        description: 'Complete 30 total workouts',
        color: const Color(0xFF9C27B0),
        unlocked: totalWorkoutsCount >= 30,
        category: 'Featured',
        criteria: BadgeCriteria(type: BadgeType.totalWorkouts, threshold: 30),
      ),
      BadgeModel(
        icon: '👑',
        title: 'Champion',
        description: 'Maintain a 30-day streak',
        color: const Color(0xFFFFC107),
        unlocked: _currentStreak >= 30,
        category: 'Featured',
        criteria: BadgeCriteria(type: BadgeType.streak, threshold: 30),
      ),
      BadgeModel(
        icon: '🌟',
        title: 'Fitness Star',
        description: 'Complete 50 total workouts',
        color: primaryBlue,
        unlocked: totalWorkoutsCount >= 50,
        category: 'Featured',
        criteria: BadgeCriteria(type: BadgeType.totalWorkouts, threshold: 50),
        isNew: totalWorkoutsCount >= 50 && totalWorkoutsCount < 55,
      ),
      BadgeModel(
        icon: '⚡',
        title: 'Power Surge',
        description: 'Perfect attendance for a month',
        color: const Color(0xFFFF9800),
        unlocked: _hasPerfectMonth(),
        category: 'Featured',
        criteria: BadgeCriteria(type: BadgeType.monthAttendance, threshold: 30),
      ),
      BadgeModel(
        icon: '🔥',
        title: 'Hot Week',
        description: 'Complete all workouts this week',
        color: const Color(0xFFFF5722),
        unlocked: _hasPerfectWeek(),
        category: 'Weekly Achievement',
        criteria: BadgeCriteria(type: BadgeType.weeklyWorkouts, threshold: 7),
      ),
      BadgeModel(
        icon: '💪',
        title: 'Super Week',
        description: 'Complete 7 workouts in a week',
        color: const Color(0xFF4CAF50),
        unlocked: _weeklyWorkoutsCount() >= 7,
        category: 'Weekly Achievement',
        criteria: BadgeCriteria(type: BadgeType.weeklyWorkouts, threshold: 7),
      ),
      BadgeModel(
        icon: '🏋️',
        title: 'Power Week',
        description: 'Complete 5+ intense workouts',
        color: const Color(0xFF795548),
        unlocked: _weeklyWorkoutsCount() >= 5,
        category: 'Weekly Achievement',
        criteria: BadgeCriteria(type: BadgeType.weeklyWorkouts, threshold: 5),
      ),
    ];

    final List<BadgeModel> newlyUnlocked = [];
    for (final badge in allBadges) {
      if (badge.unlocked) {
        final wasUnlocked = await _badgeService.isBadgeUnlocked(
          gymId: gymId,
          memberId: memberId,
          badgeTitle: badge.title,
        );

        if (!wasUnlocked) {
          newlyUnlocked.add(badge.copyWith(
            unlockedAt: DateTime.now(),
            isNew: true,
          ));
        }
      }
    }

    for (final badge in newlyUnlocked) {
      await _badgeService.unlockBadge(
        gymId: gymId,
        memberId: memberId,
        badgeTitle: badge.title,
      );
    }

    badges = allBadges;

    await _badgeService.saveUserBadges(
      gymId: gymId,
      memberId: memberId,
      badges: badges,
    );
  }

  Future<void> _mergeWithSavedBadges(List<BadgeModel> savedBadges) async {
    if (savedBadges.isEmpty) return;
    for (final savedBadge in savedBadges) {
      final existingIndex = badges.indexWhere((b) => b.title == savedBadge.title);
      if (existingIndex != -1 && savedBadge.unlocked) {
        badges[existingIndex] = badges[existingIndex].copyWith(
          unlocked: true,
          unlockedAt: savedBadge.unlockedAt,
        );
      }
    }
  }

  bool _hasPerfectMonth() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    int workoutDaysThisMonth = 0;
    for (final date in workoutDates) {
      if (date.year == now.year && date.month == now.month) {
        workoutDaysThisMonth++;
      }
    }

    return workoutDaysThisMonth >= daysInMonth;
  }

  bool _hasPerfectWeek() {
    if (workoutDates.isEmpty) return false;

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOfWeekDate = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);

    final Set<String> uniqueDays = {};

    for (final date in workoutDates) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (normalizedDate.isAtSameMomentAs(startOfWeekDate) ||
          (normalizedDate.isAfter(startOfWeekDate) &&
              normalizedDate.isBefore(endOfWeekDate.add(const Duration(days: 1))))) {
        final dayKey = "${normalizedDate.year}-${normalizedDate.month}-${normalizedDate.day}";
        uniqueDays.add(dayKey);
      }
    }

    return uniqueDays.length >= 7;
  }

  int _weeklyWorkoutsCount() {
    if (workoutDates.isEmpty) return 0;

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOfWeekDate = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);

    int workoutDaysThisWeek = 0;
    final Set<String> uniqueDays = {};

    for (final date in workoutDates) {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (normalizedDate.isAtSameMomentAs(startOfWeekDate) ||
          (normalizedDate.isAfter(startOfWeekDate) &&
              normalizedDate.isBefore(endOfWeekDate.add(const Duration(days: 1))))) {
        final dayKey = "${normalizedDate.year}-${normalizedDate.month}-${normalizedDate.day}";
        if (!uniqueDays.contains(dayKey)) {
          uniqueDays.add(dayKey);
          workoutDaysThisWeek++;
        }
      }
    }
    return workoutDaysThisWeek;
  }

  void _loadMockData() {
    _currentStreak = 12;
    _longestStreak = 15;
    _totalWorkouts = 45;

    workoutDates = [
      DateTime.now(),
      DateTime.now().subtract(const Duration(days: 1)),
      DateTime.now().subtract(const Duration(days: 2)),
      DateTime.now().subtract(const Duration(days: 3)),
      DateTime.now().subtract(const Duration(days: 4)),
      DateTime.now().subtract(const Duration(days: 5)),
      DateTime.now().subtract(const Duration(days: 6)),
      DateTime.now().subtract(const Duration(days: 8)),
      DateTime.now().subtract(const Duration(days: 9)),
      DateTime.now().subtract(const Duration(days: 10)),
      DateTime.now().subtract(const Duration(days: 20)),
      DateTime.now().subtract(const Duration(days: 21)),
      DateTime.now().subtract(const Duration(days: 22)),
    ];

    // NEW: recompute week days in mock as well
    _updateWeekActiveDays();

    _calculateAndUpdateBadges();
    _isLoading = false;
    notifyListeners();
  }

  int _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool hasWorkoutOnDate(DateTime date) {
    return workoutDates.any((workoutDate) =>
    workoutDate.year == date.year &&
        workoutDate.month == date.month &&
        workoutDate.day == date.day);
  }

  bool isInCurrentStreak(DateTime date) {
    final streakStart = getStreakStartDate();
    if (streakStart == null) return false;

    final now = DateTime.now();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(streakStart.year, streakStart.month, streakStart.day);
    final normalizedNow = DateTime(now.year, now.month, now.day);

    return normalizedDate.isAfter(normalizedStart.subtract(const Duration(days: 1))) &&
        normalizedDate.isBefore(normalizedNow.add(const Duration(days: 1))) &&
        hasWorkoutOnDate(date);
  }

  DateTime? getStreakStartDate() {
    if (workoutDates.isEmpty || currentStreak == 0) return null;

    final sortedDates = List<DateTime>.from(workoutDates)
      ..sort((a, b) => b.compareTo(a));
    DateTime streakStart = sortedDates.first;

    for (int i = 0; i < sortedDates.length - 1; i++) {
      final diff = sortedDates[i].difference(sortedDates[i + 1]).inDays;
      if (diff > 1) break;
      streakStart = sortedDates[i + 1];
    }

    return streakStart;
  }

  void updateSelectedMonth(int monthDelta) {
    _selectedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + monthDelta,
    );
    notifyListeners();
  }

  Future<Map<String, dynamic>> getBadgeStats() async {
    return await _badgeService.getBadgeStats(
      gymId: gymId,
      memberId: memberId,
    );
  }

  Future<List<BadgeModel>> getRecentlyUnlockedBadges({int limit = 3}) async {
    return await _badgeService.getRecentlyUnlockedBadges(
      gymId: gymId,
      memberId: memberId,
      limit: limit,
    );
  }

  @override
  void dispose() {
    _themeController.close();
    super.dispose();
  }
}
