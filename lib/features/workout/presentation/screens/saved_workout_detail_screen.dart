import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import '../../data/providers/workout_provider.dart';
import '../../data/models/exercise_model.dart';
import 'workout_log_screen.dart';

class SavedWorkoutDetailScreen extends StatefulWidget {
  final Map<String, dynamic> workoutData;
  final String? gymId;
  final String? memberId;

  const SavedWorkoutDetailScreen({
    Key? key,
    required this.workoutData,
    this.gymId,
    this.memberId,
  }) : super(key: key);

  @override
  State<SavedWorkoutDetailScreen> createState() => _SavedWorkoutDetailScreenState();
}

class _SavedWorkoutDetailScreenState extends State<SavedWorkoutDetailScreen> {
  late Map<String, dynamic> _localWorkoutData;
  bool _isEditing = false;
  final Color _manageColor = const Color(0xFF00C853); // Premium Green

  @override
  void initState() {
    super.initState();
    _localWorkoutData = Map<String, dynamic>.from(widget.workoutData);
    _deepCopyLocalData();
    
    // Ensure exercises are loaded for image matching
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<WorkoutProvider>(context, listen: false);
      if (provider.exercises.isEmpty) {
        provider.loadExercises();
      }
    });
  }

  void _deepCopyLocalData() {
    if (_localWorkoutData['plan'] != null) {
      _localWorkoutData['plan'] = Map<String, dynamic>.from(_localWorkoutData['plan']);
      if (_localWorkoutData['plan']['schedule'] != null) {
        _localWorkoutData['plan']['schedule'] = List.from(_localWorkoutData['plan']['schedule'])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
            
        for (var day in _localWorkoutData['plan']['schedule']) {
          if (day['exercises'] != null) {
            day['exercises'] = List.from(day['exercises'])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
        }
      } else if (_localWorkoutData['plan']['exercises'] != null) {
         _localWorkoutData['plan']['exercises'] = List.from(_localWorkoutData['plan']['exercises'])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } else if (_localWorkoutData['exercises'] != null) {
       _localWorkoutData['exercises'] = List.from(_localWorkoutData['exercises'])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    }
  }

  int _parseIntValue(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  // --- ACTIONS ---

  void _addExercise() async {
    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    if (provider.exercises.isEmpty) await provider.loadExercises();
    if (!mounted) return;

    final Exercise? selected = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExercisePickerSheet(exercises: provider.exercises),
    );

    if (selected != null) {
      setState(() {
        final newEx = {
          'id': selected.id,
          'name': selected.name,
          'sets': '3',
          'reps': '10',
          'exerciseId': selected.id,
        };
        
        if (_localWorkoutData['plan'] != null && _localWorkoutData['plan']['schedule'] != null) {
          (_localWorkoutData['plan']['schedule'][0]['exercises'] as List).add(newEx);
        } else if (_localWorkoutData['exercises'] != null) {
          (_localWorkoutData['exercises'] as List).add(newEx);
        } else if (_localWorkoutData['plan'] != null && _localWorkoutData['plan']['exercises'] != null) {
          (_localWorkoutData['plan']['exercises'] as List).add(newEx);
        }
      });
    }
  }

  void _deleteExercise(List list, int index) {
     setState(() {
       list.removeAt(index);
     });
  }

  void _onReorder(List list, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
    });
  }

  void _saveWorkoutChanges() async {
    try {
      if (widget.gymId == null || widget.memberId == null || _localWorkoutData['id'] == null) return;
      await FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('members').doc(widget.memberId).collection('workout_plans').doc(_localWorkoutData['id']).update(_localWorkoutData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Training configuration synced", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF00C853),
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        );
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  // --- BUILDERS ---

  @override
  Widget build(BuildContext context) {
    context.watch<WorkoutProvider>(); // Rebuild when exercises load (e.g. for images)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF7F8FA);
    final textColor = isDark ? Colors.white : const Color(0xFF111111);
    final accentColor = const Color(0xFF00C853);

    final title = _localWorkoutData['planName'] ?? _localWorkoutData['name'] ?? "Untitled Workout";
    final isAi = _localWorkoutData['source'] == 'ai_coach' || _localWorkoutData['source'] == 'ai';
    
    // Stats calculation
    int totalExercises = 0;
    int totalSets = 0;
    if (_localWorkoutData['exercises'] != null) {
      final exercises = _localWorkoutData['exercises'] as List;
      totalExercises = exercises.length;
      for (var ex in exercises) totalSets += _parseIntValue(ex['sets'], 3);
    } else if (_localWorkoutData['plan'] != null && _localWorkoutData['plan']['schedule'] != null) {
      for (var day in _localWorkoutData['plan']['schedule']) {
        if (day['exercises'] != null) {
          totalExercises += (day['exercises'] as List).length;
          for (var ex in day['exercises']) totalSets += _parseIntValue(ex['sets'], 3);
        }
      }
    } else if (_localWorkoutData['plan'] != null && _localWorkoutData['plan']['exercises'] != null) {
       final exercises = _localWorkoutData['plan']['exercises'] as List;
       totalExercises = exercises.length;
       for (var ex in exercises) totalSets += _parseIntValue(ex['sets'], 3);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Iconsax.arrow_left, color: textColor, size: 22), onPressed: () => Navigator.pop(context)),
        actions: [
          _buildManagePill(isDark),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Main Title Block
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toString().toUpperCase(),
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 28, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -1, height: 1.1),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _badge(isAi ? "AI PROTOCOL" : "CUSTOM CONFIG", isAi ? accentColor : Colors.blueAccent),
                      const SizedBox(width: 8),
                      _badge("${totalExercises} MODULES", Colors.grey[500]!),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              _buildModernStats(totalExercises, totalSets, isDark, accentColor),
              const SizedBox(height: 40),
              
              // Sequence Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("MODULE SEQUENCE", style: TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5)),
                  if (_isEditing)
                    GestureDetector(
                      onTap: _addExercise,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: accentColor.withOpacity(0.2))),
                        child: Row(children: [Icon(Iconsax.add, size: 14, color: accentColor), const SizedBox(width: 6), Text("ADD COMPONENT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: accentColor))]),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              _buildMainInterface(context, isDark, textColor, accentColor),
              const SizedBox(height: 150),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isEditing ? null : _buildLaunchFAB(accentColor),
    );
  }

  Widget _buildManagePill(bool isDark) {
    final color = _isEditing ? Colors.amber : _manageColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => setState(() {
          if (_isEditing) _saveWorkoutChanges();
          _isEditing = !_isEditing;
        }),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
          child: Row(
            children: [
              Icon(_isEditing ? Iconsax.tick_circle : Iconsax.edit_2, size: 14, color: Colors.white),
              const SizedBox(width: 8),
              Text(_isEditing ? "SAVE" : "MANAGE", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, fontFamily: 'Outfit', color: Colors.white, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
      child: Text(label, style: TextStyle(fontFamily: 'Outfit', fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
    );
  }

  Widget _buildModernStats(int exercises, int sets, bool isDark, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("EXERCISES", exercises.toString(), Iconsax.activity, accentColor),
          _statItem("PLAN VOLUME", "${sets} SETS", Iconsax.flash_1, Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        Text(label, style: const TextStyle(fontFamily: 'Outfit', fontSize: 8, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildMainInterface(BuildContext context, bool isDark, Color textColor, Color accentColor) {
    if (_localWorkoutData['plan'] != null && _localWorkoutData['plan']['schedule'] != null) {
      return Column(
        children: (_localWorkoutData['plan']['schedule'] as List).map((day) {
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(day['day'].toString().toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 12, color: accentColor, letterSpacing: 1)),
               const SizedBox(height: 16),
               _buildFlexibleList(context, day['exercises'] as List, isDark, textColor, accentColor),
               const SizedBox(height: 32),
             ],
           );
        }).toList(),
      );
    }
    final exercises = (_localWorkoutData['exercises'] ?? _localWorkoutData['plan']['exercises']) as List;
    return _buildFlexibleList(context, exercises, isDark, textColor, accentColor);
  }

  Widget _buildFlexibleList(BuildContext context, List exercises, bool isDark, Color textColor, Color accentColor) {
    if (_isEditing) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: exercises.length,
        onReorder: (oldIdx, newIdx) => _onReorder(exercises, oldIdx, newIdx),
        itemBuilder: (context, index) {
          final ex = exercises[index] as Map<String, dynamic>;
          return _buildSlidableEditCard(context, ex, exercises, index, isDark, textColor, accentColor);
        },
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1, // Adjusted for premium visual balance
      ),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final ex = exercises[index] as Map<String, dynamic>;
        return _buildPremiumViewCard(context, ex, isDark, textColor, accentColor);
      },
    );
  }

  Widget _buildPremiumViewCard(BuildContext context, Map<String, dynamic> ex, bool isDark, Color textColor, Color accentColor) {
    final provider = Provider.of<WorkoutProvider>(context, listen: false);
    String? imageUrl;
    String displayName = ex['name'] ?? "Exercise";
    
    try {
      final id = (ex['exerciseId'] ?? ex['id'])?.toString();
      final nameSearch = (ex['name'] ?? "").toString().toLowerCase().trim();
      
      Exercise? exercise;
      if (id != null) {
        exercise = provider.exercises.where((e) => e.id == id).firstOrNull;
      }
      
      if (exercise == null && nameSearch.isNotEmpty) {
        exercise = provider.exercises.where((e) => e.name.toLowerCase() == nameSearch).firstOrNull;
      }
      
      if (exercise != null) {
        imageUrl = exercise.imageUrl;
        displayName = exercise.name;
      }
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: Container(color: isDark ? Colors.black : const Color(0xFFF2F2F2), width: double.infinity, child: imageUrl != null ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover) : null)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(displayName.toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontSize: 9, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _dataTag(ex['sets'].toString(), "SETS", accentColor, isDark),
                    _dataTag(ex['reps'].toString(), "REPS", Colors.blueAccent, isDark),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidableEditCard(BuildContext context, Map<String, dynamic> ex, List list, int index, bool isDark, Color textColor, Color accentColor) {
    return Dismissible(
      key: ValueKey(ex['id'] ?? index),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteExercise(list, index),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
        child: const Icon(Iconsax.trash, color: Colors.white, size: 24),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141414) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            Icon(Iconsax.sort, size: 16, color: textColor.withOpacity(0.1)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((ex['name'] ?? "Module").toUpperCase(), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 13, color: textColor)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _stepper("SETS", _parseIntValue(ex['sets'], 3), (v) => setState(() => ex['sets'] = v.toString()), accentColor, isDark),
                      const SizedBox(width: 24),
                      _stepper("REPS", _parseIntValue(ex['reps'], 10), (v) => setState(() => ex['reps'] = v.toString()), Colors.blueAccent, isDark),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Iconsax.arrow_right_1, color: textColor.withOpacity(0.1), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _dataTag(String val, String label, Color color, bool isDark) {
    return Row(
      children: [
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'Outfit', color: isDark ? Colors.white : Colors.black)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _stepper(String label, int value, Function(int) onChanged, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.grey)),
          const SizedBox(width: 12),
          GestureDetector(onTap: () => onChanged(value > 1 ? value - 1 : 1), child: const Icon(Icons.remove, size: 12, color: Colors.grey)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(value.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900))),
          GestureDetector(onTap: () => onChanged(value + 1), child: Icon(Icons.add, size: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildLaunchFAB(Color accentColor) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: ElevatedButton(
        onPressed: () {
          if (widget.gymId != null && widget.memberId != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutLogScreen(gymId: widget.gymId!, memberId: widget.memberId!, workoutData: _localWorkoutData)));
          }
        },
        style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 12, shadowColor: accentColor.withOpacity(0.4)),
        child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Iconsax.play5, size: 22), SizedBox(width: 12), Text("START TRAINING", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2))])),
      ),
    );
  }

  Future<void> _deleteWorkout(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: Theme.of(context).cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), title: const Text("Terminate Plan?"), content: const Text("Permanent cloud erasure.", style: TextStyle(fontSize: 13)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("TERMINATE", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)))]));
    if (confirmed == true) {
       final user = FirebaseAuth.instance.currentUser;
       if (user != null) {
         await FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('members').doc(user.uid).collection('workout_plans').doc(_localWorkoutData['id']).delete();
         if (mounted) Navigator.pop(context);
       }
    }
  }
}

class _ExercisePickerSheet extends StatefulWidget {
  final List<Exercise> exercises;
  const _ExercisePickerSheet({Key? key, required this.exercises}) : super(key: key);
  @override State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _search = "";
  late List<Exercise> _filtered;
  @override void initState() { super.initState(); _filtered = widget.exercises; }
  void _onSearch(String q) { setState(() { _search = q.toLowerCase(); _filtered = widget.exercises.where((e) => e.name.toLowerCase().contains(_search) || e.bodyPart.toLowerCase().contains(_search)).toList(); }); }
  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(color: isDark ? const Color(0xFF101010) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(children: [
        const SizedBox(height: 12), Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24), const Text("SELECT COMPONENT", style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2)),
        const SizedBox(height: 20), Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: TextField(onChanged: _onSearch, decoration: InputDecoration(hintText: "Search movements...", prefixIcon: const Icon(Iconsax.search_normal), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))),
        const SizedBox(height: 20), Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _filtered.length, itemBuilder: (context, index) {
          final ex = _filtered[index];
          return ListTile(onTap: () => Navigator.pop(context, ex), leading: Container(width: 50, height: 50, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.grey.withOpacity(0.1)), clipBehavior: Clip.antiAlias, child: ex.imageUrl != null ? CachedNetworkImage(imageUrl: ex.imageUrl!, fit: BoxFit.cover) : null), title: Text(ex.name.toUpperCase(), style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.1)), subtitle: Text(ex.bodyPart.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1)), trailing: const Icon(Iconsax.add, size: 20));
        })),
      ]),
    );
  }
}
