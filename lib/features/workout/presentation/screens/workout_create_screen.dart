import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/exercise_model.dart';
import '../../data/providers/workout_provider.dart';

class CreateWorkoutScreen extends StatefulWidget {
  const CreateWorkoutScreen({Key? key}) : super(key: key);

  @override
  State<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends State<CreateWorkoutScreen> {
  final TextEditingController _workoutName = TextEditingController();
  final List<Map<String, dynamic>> selectedExercises = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(
          "Create Workout",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      body: Column(
        children: [

          // WORKOUT NAME INPUT
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _workoutName,
              decoration: InputDecoration(
                labelText: "Workout Name",
                labelStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ADD EXERCISE BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _addExerciseButton(context),
          ),

          SizedBox(height: 14),

          // LIST OF SELECTED EXERCISES
          Expanded(
            child: selectedExercises.isEmpty
                ? _emptyState()
                : ReorderableListView(
              physics: BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = selectedExercises.removeAt(oldIndex);
                  selectedExercises.insert(newIndex, item);
                });
              },
              children: [
                for (int i = 0; i < selectedExercises.length; i++)
                  _exerciseItem(i, selectedExercises[i])
              ],
            ),
          ),

          // SAVE BUTTON
          _saveButton(),
        ],
      ),
    );
  }

  // PREMIUM "ADD EXERCISE" BUTTON
  Widget _addExerciseButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final provider = Provider.of<WorkoutProvider>(context, listen: false);

        await provider.loadExercises(); // ensure latest

        Navigator.pushNamed(context, "/exerciseLibrary", arguments: true)
            .then((selected) {
          if (selected != null && selected is Exercise) {
            setState(() {
              selectedExercises.add({
                "exercise": selected,
                "sets": 3,
                "reps": "12",
                "weight": "",
              });
            });
          }
        });
      },
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade400,
              Colors.blue.shade400,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            "Add Exercise +",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  // EMPTY STATE
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, size: 70, color: Colors.grey.shade400),
          SizedBox(height: 14),
          Text(
            "No exercises added",
            style: TextStyle(
              fontSize: 17,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // EACH SELECTED EXERCISE ITEM CARD
  Widget _exerciseItem(int index, Map<String, dynamic> item) {
    final Exercise exercise = item["exercise"];

    return Container(
      key: ValueKey(index),
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // HEADER ROW
          Row(
            children: [
              Expanded(
                child: Text(
                  exercise.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              // REMOVE BUTTON
              GestureDetector(
                onTap: () {
                  setState(() => selectedExercises.removeAt(index));
                },
                child: Icon(Icons.close, color: Colors.grey.shade600),
              )
            ],
          ),

          SizedBox(height: 10),

          // SETS & REPS ROW
          Row(
            children: [
              _numberField(
                label: "Sets",
                value: item["sets"].toString(),
                onChanged: (v) => item["sets"] = int.tryParse(v) ?? 1,
              ),
              SizedBox(width: 12),
              _textField(
                label: "Reps",
                value: item["reps"],
                onChanged: (v) => item["reps"] = v,
              ),
              SizedBox(width: 12),
              _textField(
                label: "Weight",
                value: item["weight"],
                onChanged: (v) => item["weight"] = v,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // SMALL NUMBER FIELD (SETS)
  Widget _numberField({
    required String label,
    required String value,
    required Function(String) onChanged,
  }) {
    return Expanded(
      child: TextField(
        keyboardType: TextInputType.number,
        onChanged: onChanged,
        controller: TextEditingController(text: value),
        decoration: _inputDecoration(label),
      ),
    );
  }

  // SMALL TEXT FIELD (REPS & WEIGHT)
  Widget _textField({
    required String label,
    required String value,
    required Function(String) onChanged,
  }) {
    return Expanded(
      child: TextField(
        onChanged: onChanged,
        controller: TextEditingController(text: value),
        decoration: _inputDecoration(label),
      ),
    );
  }

  // INPUT DECORATION
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  // SAVE BUTTON
  Widget _saveButton() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: GestureDetector(
          onTap: () {
            if (_workoutName.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Enter workout name"),
                ),
              );
              return;
            }

            Navigator.pop(context, {
              "name": _workoutName.text.trim(),
              "exercises": selectedExercises,
            });
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade400,
                  Colors.green.shade400,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                "Save Workout",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
