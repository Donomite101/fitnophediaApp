import 'dart:math';

/// A simple K-Nearest Neighbors (KNN) classifier
/// built from scratch to act as a supervised ML model
/// for dynamic badge unlocking.
class KNNBadgeClassifier {
  final int k;

  // Training Data Features: e.g., [streak_days, workout_count, total_calories_thousands]
  final List<List<double>> X = [];

  // Training Data Labels: the badge names
  final List<String> y = [];

  KNNBadgeClassifier({this.k = 3}) {
    _loadTrainingData();
  }

  // A simulated supervised training dataset for badge prediction
  // Real datasets would be much larger and fetched from an API
  void _loadTrainingData() {
    // [Streak, Workouts, Calories(k)] => Badge ID
    _addTrainingData([1.0, 1.0, 0.5], 'Beginner Journey');
    _addTrainingData([2.0, 3.0, 1.0], 'Beginner Journey');

    _addTrainingData([7.0, 5.0, 2.5], 'Strong Pass');
    _addTrainingData([10.0, 8.0, 4.0], 'Strong Pass');
    _addTrainingData([14.0, 12.0, 5.5], 'Strong Pass');

    _addTrainingData([30.0, 25.0, 10.0], 'Beast Mode');
    _addTrainingData([50.0, 40.0, 20.0], 'Beast Mode');
  }

  void _addTrainingData(List<double> features, String label) {
    X.add(features);
    y.add(label);
  }

  /// Predicts the recommended badge category an actor belongs to based on real stats
  String predictBadge(List<double> inputFeatures) {
    if (X.isEmpty) return "Unknown";

    // Calculate Euclidean distances
    List<Map<String, dynamic>> distances = [];
    for (int i = 0; i < X.length; i++) {
      double dist = _euclideanDistance(inputFeatures, X[i]);
      distances.add({"label": y[i], "distance": dist});
    }

    // Sort neighbors by shortest distance to the target vector
    distances.sort(
      (a, b) => (a["distance"] as double).compareTo(b["distance"] as double),
    );

    // Gather votes for the top 'K' nearest neighbors
    Map<String, int> counts = {};
    for (int i = 0; i < k && i < distances.length; i++) {
      String label = distances[i]["label"];
      counts[label] = (counts[label] ?? 0) + 1;
    }

    // Determine the majority vote
    String bestLabel = counts.keys.first;
    int maxCount = counts[bestLabel]!;
    for (var entry in counts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        bestLabel = entry.key;
      }
    }

    return bestLabel;
  }

  double _euclideanDistance(List<double> a, List<double> b) {
    double sum = 0.0;
    for (int i = 0; i < a.length && i < b.length; i++) {
      num diff = a[i] - b[i];
      sum += (diff * diff);
    }
    return sqrt(sum);
  }
}
