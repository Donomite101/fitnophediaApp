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
    // Handle instructions (could be String or List)
    List<String> stepsList = [];
    String instructionsText = "";

    if (json["instructions"] is List) {
      stepsList = List<String>.from(json["instructions"]);
      instructionsText = stepsList.join(" ");
    } else if (json["instructions"] is String) {
      instructionsText = json["instructions"];
      stepsList = instructionsText.split(". ");
    }

    // Construct Image URL
    // Base URL for Supabase Storage (bucket is 'workouts')
    const String storageBaseUrl = "https://ojjwvrdigxerkuetxfar.supabase.co/storage/v1/object/public/workouts";
    
    String imgPath = json["image_path"] ?? json["gif_path"] ?? "";
    String fullImageUrl = "";
    if (imgPath.isNotEmpty) {
      if (imgPath.startsWith("http")) {
        fullImageUrl = imgPath;
      } else {
        fullImageUrl = "$storageBaseUrl/$imgPath";
      }
    }

    return Exercise(
      id: json["id"].toString(),
      name: json["name"] ?? "Unknown Exercise",
      bodyPart: json["body_part"] ?? json["bodyPart"] ?? "",
      equipment: json["equipment"] ?? "",
      target: json["target"] ?? "", // Supabase might not have this, usage depends on DB
      secondaryMuscles: [], // Supabase data shown doesn't have this column
      gifUrl: fullImageUrl,
      imageUrl: fullImageUrl,
      instructions: instructionsText,
      steps: stepsList,
      videoUrl: "",
      category: json["category"] ?? "",
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
