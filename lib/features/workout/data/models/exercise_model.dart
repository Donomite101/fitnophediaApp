class Exercise {
  final String id;
  final String name;
  final String bodyPart;
  final String equipment;
  final String target;                     // primary muscle
  final List<String> secondaryMuscles;
  final String gifUrl;                     // image/gif from ExerciseDB
  final String instructions;               // formatted text
  final List<String> steps;                // instructions split into steps
  final String imageUrl;                   // alias for gifUrl (UI compatibility)
  final String videoUrl;                   // optional external video
  final String category;                   // optional additional tagging

  Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.target,
    required this.secondaryMuscles,
    required this.gifUrl,
    required this.instructions,
    required this.steps,
    required this.imageUrl,
    required this.videoUrl,
    required this.category,
  });

  // -----------------------------
  // FROM JSON → MODEL
  // -----------------------------
  factory Exercise.fromJson(Map<String, dynamic> json) {
    final List instructionsList =
    json["instructions"] is List ? json["instructions"] : [];

    return Exercise(
      id: json["id"].toString(),
      name: json["name"] ?? "Unknown Exercise",
      bodyPart: json["bodyPart"] ?? "",
      equipment: json["equipment"] ?? "",
      target: json["target"] ?? "",
      secondaryMuscles: List<String>.from(json["secondaryMuscles"] ?? []),

      // ExerciseDB uses gifUrl → use as main media everywhere
      gifUrl: json["gifUrl"] ?? "",
      imageUrl: json["gifUrl"] ?? "",

      // Steps converted from instructions array
      instructions: instructionsList.join(". "),
      steps: instructionsList.map((e) => e.toString()).toList(),

      // Optional fields (your UI uses them)
      videoUrl: json["videoUrl"] ?? "",    // ExerciseDB does NOT provide video
      category: json["category"] ?? "",    // optional custom tag
    );
  }

  // -----------------------------
  // MODEL → JSON
  // -----------------------------
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "bodyPart": bodyPart,
      "equipment": equipment,
      "target": target,
      "secondaryMuscles": secondaryMuscles,
      "gifUrl": gifUrl,
      "instructions": steps,
      "videoUrl": videoUrl,
      "category": category,
    };
  }
}
