class StreakResult {
  final bool success;
  final String message;
  final int? newStreakCount;

  StreakResult({
    required this.success,
    required this.message,
    this.newStreakCount,
  });
}