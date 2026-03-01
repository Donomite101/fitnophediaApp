import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MigrationTool {
  static Future<void> migrateExercises() async {
    const filePath = 'assets/workouts/exercises_rows.csv';
    
    debugPrint("📖 Reading migration file from assets...");
    String content;
    try {
      content = await rootBundle.loadString(filePath);
    } catch (e) {
      debugPrint("❌ Migration File not found in assets. Make sure it's in pubspec.yaml: $e");
      return;
    }

    if (content.isEmpty) {
      debugPrint("⚠️ Migration file is empty.");
      return;
    }

    // Robust CSV Parsing for multiline instructions
    final List<Map<String, dynamic>> exercises = [];
    
    final rows = _parseCsv(content);
    if (rows.isEmpty) return;

    final headers = rows[0];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < headers.length) continue;

      final Map<String, dynamic> exercise = {};
      for (var j = 0; j < headers.length; j++) {
        exercise[headers[j]] = row[j];
      }
      exercises.add(exercise);
    }

    debugPrint("🚀 Starting migration of ${exercises.length} exercises to Firestore...");
    
    final collection = FirebaseFirestore.instance.collection('exercises');
    final batchSize = 400; // Firestore limit is 500
    
    for (var i = 0; i < exercises.length; i += batchSize) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = exercises.sublist(i, i + batchSize > exercises.length ? exercises.length : i + batchSize);
      
      for (var exercise in chunk) {
        final id = exercise['id']?.toString();
        if (id == null || id.isEmpty) continue;
        
        // Transform the data to match our Exercise model
        final data = {
          'name': exercise['name'],
          'body_part': exercise['body_part'],
          'equipment': exercise['equipment'],
          'image_path': exercise['image_path'],
          'gif_path': exercise['gif_path'],
          'instructions': _parseInstructions(exercise['instructions']),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        batch.set(collection.doc(id), data);
      }
      
      await batch.commit();
      debugPrint("✅ Progress: ${i + chunk.length}/${exercises.length} uploaded");
    }
    
    debugPrint("🏁 MIGRATION COMPLETE!");
  }

  static dynamic _parseInstructions(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw;
    final String text = raw.toString();
    // Split by common delimiters and clean up
    return text
        .split(RegExp(r'\. |\n|(?<=[a-z])\.(?=[A-Z])'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 2)
        .toList();
  }

  static List<List<String>> _parseCsv(String csvText) {
    List<List<String>> results = [];
    List<String> currentRow = [];
    StringBuffer currentField = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < csvText.length; i++) {
        String char = csvText[i];

        if (inQuotes) {
            if (char == '"') {
                if (i + 1 < csvText.length && csvText[i + 1] == '"') {
                    currentField.write('"');
                    i++; 
                } else {
                    inQuotes = false;
                }
            } else {
                currentField.write(char);
            }
        } else {
            if (char == '"') {
                inQuotes = true;
            } else if (char == ',') {
                currentRow.add(currentField.toString().trim());
                currentField.clear();
            } else if (char == '\n' || char == '\r') {
                if (currentRow.isNotEmpty || currentField.isNotEmpty) {
                    currentRow.add(currentField.toString().trim());
                    results.add(List.from(currentRow));
                    currentRow.clear();
                    currentField.clear();
                }
                if (char == '\r' && i + 1 < csvText.length && csvText[i + 1] == '\n') {
                    i++;
                }
            } else {
                currentField.write(char);
            }
        }
    }
    
    if (currentRow.isNotEmpty || currentField.isNotEmpty) {
        currentRow.add(currentField.toString().trim());
        results.add(currentRow);
    }

    return results;
  }
}
