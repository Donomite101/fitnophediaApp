import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/nutrition_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NutritionRepository {
  final FirebaseFirestore _firestore;
  final String gymId;
  final String memberId;

  NutritionRepository({
    FirebaseFirestore? firestore,
    required this.gymId,
    required this.memberId,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

  DocumentReference _dayDoc(DateTime date) {
    final key = _dateKey(date);
    return _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(memberId)
        .collection('diet_plan')
        .doc(key);
  }

  CollectionReference _mealsCol(DateTime date) =>
      _dayDoc(date).collection('meals');

  // STREAMS

  Stream<DailyNutritionSummary?> listenSummary(DateTime date) {
    return _dayDoc(date).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DailyNutritionSummary.fromDoc(doc);
    });
  }

  Stream<List<NutritionMeal>> listenMeals(DateTime date) {
    return _mealsCol(date)
        .orderBy('timeOfDay')
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => NutritionMeal.fromDoc(d))
        .toList());
  }

  Stream<List<Map<String, dynamic>>> listenAiDietPlans() {
    return _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(memberId)
        .collection('diet_plans')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  // WRITE OPERATIONS

  Future<void> saveMeal(DateTime date, NutritionMeal meal) async {
    await _mealsCol(date).doc(meal.mealId).set(
      meal.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> deleteMeal(DateTime date, String mealId) async {
    await _mealsCol(date).doc(mealId).delete();
  }

  Future<void> toggleMealConsumption(DateTime date, String mealId, bool isConsumed) async {
    await _mealsCol(date).doc(mealId).update({
      'isConsumed': isConsumed,
    });
    await recalculateSummary(date);
  }

  Future<void> clearMealsForDay(DateTime date) async {
    final snapshot = await _mealsCol(date).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> deleteMealPlan(String planId) async {
    try {
      await _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('custom_meal_plans')
          .doc(planId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting meal plan: $e');
      rethrow;
    }
  }
  Future<void> recalculateSummary(DateTime date) async {
    final mealsSnap = await _mealsCol(date).get();
    double calories = 0, protein = 0, carbs = 0, fat = 0, sugar = 0;

    for (final doc in mealsSnap.docs) {
      final m = NutritionMeal.fromDoc(doc);
      if (m.isConsumed) {
        calories += m.totalCalories;
        protein += m.totalProtein;
        carbs += m.totalCarbs;
        fat += m.totalFat;
        sugar += m.totalSugar;
      }
    }

    final dayDoc = await _dayDoc(date).get();
    int waterMl = 0;
    int waterGoalMl = 2500;
    if (dayDoc.exists) {
      final d = dayDoc.data() as Map<String, dynamic>;
      waterMl = (d['waterMl'] ?? 0) as int;
      waterGoalMl = (d['waterGoalMl'] ?? 2500) as int;
    }

    final summary = DailyNutritionSummary(
      dateKey: dayDoc.id.isEmpty ? '' : dayDoc.id,
      totalCalories: calories,
      totalProtein: protein,
      totalCarbs: carbs,
      totalFat: fat,
      totalSugar: sugar,
      waterMl: waterMl,
      waterGoalMl: waterGoalMl,
    );

    await updateSummary(date, summary);
  }

  Future<void> updateSummary(
      DateTime date,
      DailyNutritionSummary summary,
      ) async {
    await _dayDoc(date).set(
      summary.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> updateWater(DateTime date, int waterMl) async {
    await _dayDoc(date).set(
      {
        'waterMl': waterMl,
      },
      SetOptions(merge: true),
    );
  }

  Future<List<int>> getWeeklyWaterIntake(DateTime endDate) async {
    List<int> weeklyIntake = [];
    for (int i = 0; i < 7; i++) {
      final date = endDate.subtract(Duration(days: i + 1)); // Previous 7 days, excluding today? Or including? Usually comparison is vs history. Let's do previous 7 days.
      final doc = await _dayDoc(date).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        weeklyIntake.add((data['waterMl'] ?? 0) as int);
      } else {
        weeklyIntake.add(0);
      }
    }
    return weeklyIntake;
  }

  Future<void> updateWaterGoal(DateTime date, int goal) async {
    await _dayDoc(date).set(
      {
        'waterGoalMl': goal,
      },
      SetOptions(merge: true),
    );
  }

  // REMINDER SETTINGS
  Future<void> saveReminderSettings(bool enabled, int startHour, int startMinute, int endHour, int endMinute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hydration_reminders_enabled', enabled);
    await prefs.setInt('hydration_start_hour', startHour);
    await prefs.setInt('hydration_start_minute', startMinute);
    await prefs.setInt('hydration_end_hour', endHour);
    await prefs.setInt('hydration_end_minute', endMinute);
  }

  Future<Map<String, dynamic>> getReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool('hydration_reminders_enabled') ?? false,
      'startHour': prefs.getInt('hydration_start_hour') ?? 8,
      'startMinute': prefs.getInt('hydration_start_minute') ?? 0,
      'endHour': prefs.getInt('hydration_end_hour') ?? 20,
      'endMinute': prefs.getInt('hydration_end_minute') ?? 0,
    };
  }

  // MEAL PREFERENCES

  /// Save user's meal preferences
  Future<void> saveMealPreferences(Map<String, dynamic> preferences) async {
    await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(memberId)
        .collection('meal_preferences')
        .doc('current')
        .set(preferences, SetOptions(merge: true));
  }

  /// Get user's meal preferences
  Future<Map<String, dynamic>?> getMealPreferences() async {
    final doc = await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(memberId)
        .collection('meal_preferences')
        .doc('current')
        .get();

    if (!doc.exists) return null;
    return doc.data();
  }

  /// Check if user has completed meal preferences
  Future<bool> hasCompletedPreferences() async {
    final prefs = await getMealPreferences();
    return prefs != null && prefs.isNotEmpty;
  }

  // MEAL PLANS

  /// Get all available meal plans (system + custom)
  Future<List<Map<String, dynamic>>> getMealPlans() async {
    final snapshot = await _firestore
        .collection('meal_plans')
        .where('isCustom', isEqualTo: false)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Get user's custom meal plans
  Future<List<Map<String, dynamic>>> getCustomMealPlans() async {
    final snapshot = await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(memberId)
        .collection('custom_meal_plans')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Save a custom meal plan
  Future<void> saveMealPlan(Map<String, dynamic> mealPlan) async {
    final id = mealPlan['id'];
    if (id != null) {
      await _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('custom_meal_plans')
          .doc(id)
          .set(mealPlan);
    } else {
      await _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('custom_meal_plans')
          .add(mealPlan);
    }
  }

  /// Get a specific meal plan by ID
  Future<Map<String, dynamic>?> getMealPlanById(String planId) async {
    // Try system plans first
    var doc = await _firestore
        .collection('meal_plans')
        .doc(planId)
        .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        data['id'] = doc.id;
        return data;
      }
    }

    // Try custom plans
    final customSnapshot = await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(memberId)
        .collection('custom_meal_plans')
        .where('id', isEqualTo: planId)
        .limit(1)
        .get();

    if (customSnapshot.docs.isNotEmpty) {
      final data = customSnapshot.docs.first.data();
      data['id'] = customSnapshot.docs.first.id;
      return data;
    }

    return null;
  }
}

