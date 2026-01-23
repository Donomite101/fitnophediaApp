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
      
      // DEBUG: Print unique body parts
      final uniqueBodyParts = _exercises.map((e) => e.bodyPart).toSet().toList();
      debugPrint("🏷️ Available Body Parts: $uniqueBodyParts");
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
  // -------------------------------------------------------------
  // CATEGORY FILTER
  // -------------------------------------------------------------
  List<Exercise> filterByBodyPart(String category) {
    final cat = category.toLowerCase();
    
    // Define mappings from UI Category -> DB Body Parts
    final Map<String, List<String>> categoryMap = {
      'chest': ['chest'],
      'back': ['lats', 'middle back', 'lower back', 'traps'],
      'legs': ['quadriceps', 'hamstrings', 'calves', 'adductors', 'abductors', 'glutes'],
      'arms': ['biceps', 'triceps', 'forearms'],
      'shoulders': ['shoulders', 'neck'],
      'core': ['abdominals'],
      'cardio': ['cardio'],
    };

    final targetParts = categoryMap[cat];

    List<Exercise> list;
    if (targetParts != null) {
      // Filter if bodyPart matches ANY of the target parts
      list = _exercises.where((ex) {
        return targetParts.contains(ex.bodyPart.toLowerCase());
      }).toList();
    } else {
      // Fallback: exact match
      list = _exercises.where((ex) {
        return ex.bodyPart.toLowerCase() == cat;
      }).toList();
    }

    debugPrint("📌 [WorkoutProvider] Filtered by $category → ${list.length} items");
    _filteredExercises = list; // Auto-update filtered list
    notifyListeners();
    return list;
  }

  // -------------------------------------------------------------
  // RESET FILTERS
  // -------------------------------------------------------------
  // -------------------------------------------------------------
  // WARMUP EXERCISES
  // -------------------------------------------------------------
  List<Exercise> _warmupExercises = [];
  List<Exercise> get warmupExercises => _warmupExercises;

  List<Exercise> _filteredWarmupExercises = [];
  List<Exercise> get filteredWarmupExercises => _filteredWarmupExercises;

  Future<void> loadWarmupExercises() async {
    if (_warmupExercises.isNotEmpty) return; // Already loaded

    debugPrint("🔍 [WorkoutProvider] Loading warmup exercises…");
    _isLoading = true;
    notifyListeners();

    try {
      final data = await repository.loadWarmupExercises();
      _warmupExercises = data;
      _filteredWarmupExercises = data;
      debugPrint("✅ [WorkoutProvider] Loaded ${_warmupExercises.length} warmup exercises");
    } catch (e) {
      debugPrint("❌ [WorkoutProvider] Warmup load error: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  void searchWarmupExercises(String query) {
    if (query.isEmpty) {
      _filteredWarmupExercises = List.from(_warmupExercises);
    } else {
      final q = query.toLowerCase();
      _filteredWarmupExercises = _warmupExercises.where((ex) {
        return ex.name.toLowerCase().contains(q) ||
            ex.bodyPart.toLowerCase().contains(q) ||
            ex.target.toLowerCase().contains(q);
      }).toList();
    }
    notifyListeners();
  }

  void resetFilters() {
    _filteredExercises = List.from(_exercises);
    notifyListeners();
  }
}
