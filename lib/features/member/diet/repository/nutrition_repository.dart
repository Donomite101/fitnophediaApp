import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/nutrition_models.dart';

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
  Future<void> recalculateSummary(DateTime date) async {
    final mealsSnap = await _mealsCol(date).get();
    double calories = 0, protein = 0, carbs = 0, fat = 0, sugar = 0;

    for (final doc in mealsSnap.docs) {
      final m = NutritionMeal.fromDoc(doc);
      calories += m.totalCalories;
      protein += m.totalProtein;
      carbs += m.totalCarbs;
      fat += m.totalFat;
      sugar += m.totalSugar;
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
}
