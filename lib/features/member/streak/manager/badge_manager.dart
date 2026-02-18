import 'package:flutter/material.dart';
import '../../streak/models/badge_model.dart';
import '../../streak/service/badge_service.dart';
import '../../streak/models/streak_view_model.dart';
import '../widgets/overlays/badge_unlock_overlay.dart';

class BadgeManager {
  static final BadgeManager _instance = BadgeManager._();
  factory BadgeManager() => _instance;
  BadgeManager._();

  final BadgeService _badgeService = BadgeService();

  // Temporary list to hold newly unlocked badges until displayed
  final List<BadgeModel> _pendingBadges = [];

  Future<void> checkForNewBadges(BuildContext context, {required String gymId, required String memberId}) async {
    // We can reuse the calculation logic from StreakViewModel, but that's tied to UI.
    // Ideally, we'd move calculation here.
    // However, to save time and avoid massive refactoring, we'll instantiate a temporary ViewModel-like checker
    // or just listen to the badge service updates if we modify it to return "newly unlocked".
    
    // For now, let's create a specialized checker here that mimics the ViewModel logic.
    // This is "Dynamic" as requested.
    
    // 1. Load data essential for badges (Total Workouts, Streak, Weekly)
    // We need 'streak' and 'totalWorkouts' and 'workoutDates' to recalculate.
    // This fetching is duplicated from StreakViewModel but necessary if we want to check from anywhere.
    
    try {
      final viewModel = StreakViewModel(gymId: gymId, memberId: memberId);
      // We need to wait for it to load & calculate
      await viewModel.loadStreakData(); 
      
      // After loading, we can check which badges are NEW.
      // The ViewModel logic already saves them to Firestore as unlocked.
      // But we need to know WHICH ones were just unlocked.
      
      // To create a true "Event", we can enhance BadgeService to return the list of newly unlocked items.
      // But without changing BadgeService too much, we can check "isNew" flag on returned badges?
      // The ViewModel logic doesn't persist "isNew" across sessions well unless we handle it.
      
      // Let's modify BadgeService or ViewModel to return the *new* badges.
      // Actually, StreakViewModel updates `badges` list and marks `isNew = true` for fresh unlocks.
      
      final newBadges = viewModel.badges.where((b) => b.isNew).toList();
      
      if (newBadges.isNotEmpty) {
        _pendingBadges.addAll(newBadges);
        _showOverlay(context);
      }
      
    } catch (e) {
      debugPrint("Error checking badges: $e");
    }
  }

  void _showOverlay(BuildContext context) {
    if (_pendingBadges.isEmpty) return;
    
    // We need to find a way to show overlay on top of everything.
    // Using Overlay.of(context) or similar.
    // Or just a dialog since it's an achievement.
    
    // Ideally user wants an overlay.
    // We can use a global key if context is tricky, but passing context from Dashboard is fine.
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent, // We handle blur inside overlay
      builder: (ctx) {
        // Capture specific badges for this dialog instance
        final badgesToShow = List<BadgeModel>.from(_pendingBadges);
        _pendingBadges.clear(); // Clear immediately so we don't show twice
        
        return BadgeUnlockOverlay(
          unlockedBadges: badgesToShow,
          onDismiss: () {
             Navigator.of(ctx).pop();
          },
        );
      },
    );
  }
}
