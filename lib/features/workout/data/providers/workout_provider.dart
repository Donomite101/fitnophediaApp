import 'package:flutter/foundation.dart';

import '../models/exercise_model.dart';
import '../services/workout_repository.dart';


class WorkoutProvider extends ChangeNotifier {
  final WorkoutRepository repository;

  WorkoutProvider({required this.repository});

  List<Exercise> _exercises = [];
  List<Exercise> get exercises => _exercises;

  List<Exercise> _filteredExercises = [];
  List<Exercise> get filteredExercises => _filteredExercises;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _searchQuery = '';

  // -------------------------------------------------------------
  // LOAD EXERCISES
  // -------------------------------------------------------------
  Future<void> loadExercises() async {
    debugPrint("🔍 [WorkoutProvider] Loading exercises…");

    await Future.delayed(Duration(milliseconds: 10));

    _isLoading = true;
    notifyListeners();

    try {
      final data = await repository.loadExercises();
      _exercises = data;
      _filteredExercises = data;

      debugPrint("✅ [WorkoutProvider] Loaded ${_exercises.length} exercises");
    } catch (e) {
      debugPrint("❌ [WorkoutProvider] Load error: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  // -------------------------------------------------------------
  // SET FILTERED DATA (Setter Method)
  // -------------------------------------------------------------
  void setFilteredExercises(List<Exercise> list) {
    _filteredExercises = list;
    notifyListeners();
  }

  // -------------------------------------------------------------
  // SEARCH FILTER
  // -------------------------------------------------------------
  void searchExercises(String query) {
    _searchQuery = query.toLowerCase();

    if (_searchQuery.isEmpty) {
      _filteredExercises = List.from(_exercises);
    } else {
      _filteredExercises = _exercises.where((ex) {
        return ex.name.toLowerCase().contains(_searchQuery) ||
            ex.bodyPart.toLowerCase().contains(_searchQuery) ||
            ex.target.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    notifyListeners();
  }

  // -------------------------------------------------------------
  // CATEGORY FILTER
  // -------------------------------------------------------------
  List<Exercise> filterByBodyPart(String bodyPart) {
    bodyPart = bodyPart.toLowerCase();

    final list = _exercises.where((ex) {
      return ex.bodyPart.toLowerCase() == bodyPart;
    }).toList();

    debugPrint("📌 [WorkoutProvider] Filtered by $bodyPart → ${list.length} items");
    return list;
  }

  // -------------------------------------------------------------
  // RESET FILTERS
  // -------------------------------------------------------------
  void resetFilters() {
    _filteredExercises = List.from(_exercises);
    notifyListeners();
  }
}
