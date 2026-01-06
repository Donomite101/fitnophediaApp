import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../member/streak/service/streak_service.dart';
import '../../../member/streak/StreakCelebrationOverlay.dart';
import '../../data/providers/workout_provider.dart';
import '../../data/models/exercise_model.dart';

class WorkoutLogScreen extends StatefulWidget {
  final String gymId;
  final String memberId;
  final Map<String, dynamic> workoutData;
  final String? initialDayName;

  const WorkoutLogScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
    required this.workoutData,
    this.initialDayName,
  }) : super(key: key);

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  // Timer
  Timer? _workoutTimer;
  int _secondsElapsed = 0;
  bool _isPaused = false;

  // Navigation & State
  late PageController _pageController;
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  List<Map<String, dynamic>> _exercises = [];
  final Map<int, List<Map<String, dynamic>>> _logs = {};
  
  // Day Selection
  bool _needsDaySelection = false;
  List<dynamic> _availableDays = [];
  String _selectedDayName = "";

  // Rest Timer
  Timer? _restTimer;
  int _restSecondsRemaining = 0;
  bool _isResting = false;
  bool _showRestOverlay = false;
  
  // Music Mock
  bool _isPlayingMusic = false;

  // Cache for exercise lookups to prevent UI lag during timer ticks
  final Map<String, Exercise> _matchCache = {};

  // Background Timing & Persistence
  DateTime? _backgroundTimestamp;
  String get _draftKey => "workout_draft_${widget.memberId}_${widget.gymId}_${widget.workoutData['id'] ?? 'global'}";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
    _initializeWorkout();
    _startWorkoutTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDraft(); // Save when navigating away
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundTimestamp = DateTime.now();
      _saveDraft();
    } else if (state == AppLifecycleState.resumed && _backgroundTimestamp != null) {
      final difference = DateTime.now().difference(_backgroundTimestamp!).inSeconds;
      setState(() {
        _secondsElapsed += difference;
        if (_isResting) {
          if (_restSecondsRemaining > difference) {
            _restSecondsRemaining -= difference;
          } else {
            _restSecondsRemaining = 0;
            _onRestTimerFinished();
          }
        }
      });
      _backgroundTimestamp = null;
    }
  }

  void _initializeWorkout() async {
    // Check for draft first
    final hasDraft = await _checkAndLoadDraft();
    if (hasDraft) return;

    // Check for schedule
    if (widget.workoutData['plan'] != null && widget.workoutData['plan']['schedule'] != null) {
      final schedule = widget.workoutData['plan']['schedule'] as List;
      if (schedule.isNotEmpty) {
        _availableDays = schedule;
        
        // Try initial day if provided
        if (widget.initialDayName != null) {
          final match = schedule.firstWhere(
            (d) => d['day'].toString().toLowerCase() == widget.initialDayName!.toLowerCase(),
            orElse: () => null,
          );
          if (match != null) {
            _loadDay(match);
            return;
          }
        }

        // Try to match today
        final today = DateFormat('EEEE').format(DateTime.now()); // e.g., "Monday"
        final match = schedule.firstWhere(
          (d) => d['day'].toString().toLowerCase() == today.toLowerCase(),
          orElse: () => null,
        );

        if (match != null) {
          _loadDay(match);
        } else {
          setState(() => _needsDaySelection = true);
        }
        return;
      }
    }
    
    // Fallback: Load all exercises
    List<dynamic> raw = widget.workoutData['exercises'] ?? widget.workoutData['plan']['exercises'] ?? [];
    _parseExercises(raw);
  }

  void _loadDay(Map<String, dynamic> dayData) {
    setState(() {
      _selectedDayName = dayData['day'] ?? "Workout";
      _needsDaySelection = false;
    });
    _parseExercises(dayData['exercises'] ?? []);
  }

  void _parseExercises(List<dynamic> rawExercises) {
    _exercises = rawExercises.map((e) => e as Map<String, dynamic>).toList();
    
    for (int i = 0; i < _exercises.length; i++) {
      _logs[i] = [];
      int targetSets = int.tryParse(_exercises[i]['sets']?.toString() ?? '3') ?? 3;
      double lastWeight = 0.0; // Auto-suggest logic placeholder
      
      for (int j = 0; j < targetSets; j++) {
        _logs[i]!.add({
          'weight': lastWeight,
          'reps': int.tryParse(_exercises[i]['reps']?.toString() ?? '10') ?? 10,
          'completed': false,
        });
      }
    }
    if (mounted) setState(() {});
    _saveDraft();
  }

  // --- Draft Persistence Logic ---
  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = {
        'secondsElapsed': _secondsElapsed,
        'currentExerciseIndex': _currentExerciseIndex,
        'currentSetIndex': _currentSetIndex,
        'isResting': _isResting,
        'restSecondsRemaining': _restSecondsRemaining,
        'exercises': _exercises,
        'logs': _logs.map((key, value) => MapEntry(key.toString(), value)),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_draftKey, jsonEncode(draft));
    } catch (e) {
      debugPrint("Error saving draft: $e");
    }
  }

  Future<bool> _checkAndLoadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftString = prefs.getString(_draftKey);
      if (draftString == null) return false;

      final draft = jsonDecode(draftString);
      final timestamp = draft['timestamp'] as int;
      
      // If draft is older than 4 hours, ignore it
      if (DateTime.now().millisecondsSinceEpoch - timestamp > 14400000) {
        await prefs.remove(_draftKey);
        return false;
      }

      final resume = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
          title: const Text("Resume Workout?"),
          content: const Text("We found an unfinished workout. Would you like to continue?"),
          actions: [
            TextButton(
              onPressed: () {
                prefs.remove(_draftKey);
                Navigator.pop(ctx, false);
              },
              child: const Text("Start New", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Resume", style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (resume != true) return false;

      setState(() {
        _secondsElapsed = draft['secondsElapsed'];
        _currentExerciseIndex = draft['currentExerciseIndex'];
        _currentSetIndex = draft['currentSetIndex'];
        _isResting = draft['isResting'] ?? false;
        _restSecondsRemaining = draft['restSecondsRemaining'] ?? 0;
        _exercises = List<Map<String, dynamic>>.from(draft['exercises']);
        
        final Map<String, dynamic> rawLogs = draft['logs'];
        rawLogs.forEach((key, value) {
          _logs[int.parse(key)] = List<Map<String, dynamic>>.from(value);
        });

        _pageController = PageController(initialPage: _currentExerciseIndex);
        
        if (_isResting && _restSecondsRemaining > 0) {
          _startRestTimerInternal(_restSecondsRemaining);
        }
      });

      return true;
    } catch (e) {
      debugPrint("Error loading draft: $e");
      return false;
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  void _startWorkoutTimer() {
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) setState(() => _secondsElapsed++);
    });
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _logSetAndRest() {
    if (_isResting) return;

    setState(() {
      final currentLog = _logs[_currentExerciseIndex]![_currentSetIndex];
      currentLog['completed'] = true;
      
      // Auto-Suggest next set weight
      if (_currentSetIndex < _logs[_currentExerciseIndex]!.length - 1) {
        _logs[_currentExerciseIndex]![_currentSetIndex + 1]['weight'] = currentLog['weight'];
      }
    });

    // Determine Rest Duration
    int restDuration = (_currentSetIndex < _logs[_currentExerciseIndex]!.length - 1) ? 60 : 90;
    
    // Auto-advance logic for exercise transitions
    if (_currentSetIndex < _logs[_currentExerciseIndex]!.length - 1) {
      _startRestTimerInternal(restDuration, showOverlay: true);
    } else {
      // LAST SET transition
      if (_currentExerciseIndex < _exercises.length - 1) {
        _startRestTimerInternal(90, showOverlay: true);
      } else {
        _finishWorkout();
      }
    }

    _saveDraft();
  }

  void _onRestTimerFinished() {
    setState(() {
      _isResting = false;
      _showRestOverlay = false;

      // HANDS-FREE TRANSITION LOGIC
      if (_currentSetIndex >= _logs[_currentExerciseIndex]!.length - 1) {
        // We finished an exercise exercise entirely
        if (_currentExerciseIndex < _exercises.length - 1) {
          _currentExerciseIndex++;
          _currentSetIndex = 0;
          _pageController.animateToPage(
            _currentExerciseIndex,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
          );
        }
      } else {
        // Just move to the next set in the same exercise
        _currentSetIndex++;
      }
    });
  }

  // Internal helper to setup timer without triggering its own setState immediately
  void _startRestTimerInternal(int seconds, {bool showOverlay = true}) {
    _restTimer?.cancel();
    _isResting = true;
    _showRestOverlay = showOverlay;
    _restSecondsRemaining = seconds;

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_restSecondsRemaining > 0) {
          _restSecondsRemaining--;
        } else {
          timer.cancel();
          _onRestTimerFinished();
        }
      });
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    _onRestTimerFinished();
  }

  void _updateValue(String key, double change) {
    setState(() {
      double current = (_logs[_currentExerciseIndex]![_currentSetIndex][key] as num).toDouble();
      double newValue = (current + change).clamp(0, 999);
      if (key == 'reps') newValue = newValue.roundToDouble();
      _logs[_currentExerciseIndex]![_currentSetIndex][key] = newValue;
    });
  }

  Future<void> _finishWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Workout Complete!"),
        content: const Text("Great job! Log this workout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Finish", style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _clearDraft(); // Success! Clear the draft
      final result = await StreakService.instance.recordAttendanceAndUpdateStreak(
        gymId: widget.gymId,
        memberId: widget.memberId,
        skipGeofence: true, // Allow logging workout from anywhere
      );

      if (mounted) {
        // Show celebration if it's a new streak day OR if we just want to show the current streak
        if (result.newStreakCount != null && result.newStreakCount! > 0) {
          final activeDays = await StreakService.instance.getActiveDaysForCurrentWeek(
            gymId: widget.gymId,
            memberId: widget.memberId,
          );
          
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StreakCelebrationOverlay(
                  currentStreak: result.newStreakCount!,
                  activeDays: activeDays,
                  onContinue: () => Navigator.pop(context),
                ),
              ),
            );
          }
        }

        Navigator.pop(context); // Pop WorkoutLogScreen
        Navigator.pop(context); // Pop SavedWorkoutDetailScreen
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message.isNotEmpty ? result.message : "Workout Logged! 🔥"), 
            backgroundColor: const Color(0xFF00E676)
          ),
        );
      }
    } catch (e) {
      debugPrint("Error finishing workout: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : Colors.black;

    if (_needsDaySelection) {
      return _buildDaySelectionScreen(isDark, textColor);
    }

    // if (_isResting) {
    //   return _buildRestScreen(isDark, textColor);
    // }

    if (_exercises.isEmpty) {
      return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
    }

    final totalSets = _logs[_currentExerciseIndex]!.length;
    final progress = (_currentExerciseIndex + (_currentSetIndex / totalSets)) / _exercises.length;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Sticky Header
                _buildTopBar(context, textColor, progress),

                // Swipeable Exercise View
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _currentExerciseIndex = index;
                        _currentSetIndex = 0; // Reset to first set when swiping manually
                      });
                    },
                    itemCount: _exercises.length,
                    itemBuilder: (context, index) {
                      return _buildExercisePage(context, index, isDark, textColor);
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Rest Overlay
          if (_showRestOverlay)
            Positioned.fill(
              child: Container(
                color: isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
                child: _buildRestScreen(isDark, textColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDaySelectionScreen(bool isDark, Color textColor) {
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Select Day", style: TextStyle(color: textColor, fontFamily: 'Outfit')),
        leading: IconButton(icon: Icon(Iconsax.arrow_left, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _availableDays.length,
        itemBuilder: (context, index) {
          final day = _availableDays[index];
          return GestureDetector(
            onTap: () => _loadDay(day),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.transparent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    day['day'] ?? "Day ${index + 1}",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Outfit'),
                  ),
                  const Icon(Iconsax.arrow_right_3, color: Color(0xFF00E676)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExercisePage(BuildContext context, int index, bool isDark, Color textColor) {
    final exercise = _exercises[index];
    final currentSetData = _logs[index]![_currentSetIndex];
    final totalSets = _logs[index]!.length;

    // Optimized Image Logic with caching
    String? imageUrl;
    final exerciseName = exercise['name']?.toString().toLowerCase() ?? "";
    
    if (_matchCache.containsKey(exerciseName)) {
      imageUrl = _matchCache[exerciseName]!.imageUrl;
    } else {
      try {
        final provider = Provider.of<WorkoutProvider>(context, listen: false);
        final match = provider.exercises.firstWhere(
          (e) => e.name.toLowerCase().contains(exerciseName), 
          orElse: () => provider.exercises.first
        );
        _matchCache[exerciseName] = match;
        imageUrl = match.imageUrl;
      } catch (_) {}
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Collapsible Image Card
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: MediaQuery.of(context).size.height * 0.25,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(20),
                        image: imageUrl != null ? DecorationImage(image: CachedNetworkImageProvider(imageUrl), fit: BoxFit.cover) : null,
                      ),
                      child: imageUrl == null 
                          ? Center(child: Icon(Iconsax.activity, size: 60, color: Colors.white.withOpacity(0.2))) 
                          : null,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Exercise Info
                    Text(
                      exercise['name'] ?? "Exercise",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    
                    // Expandable Instructions Card
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final provider = Provider.of<WorkoutProvider>(context, listen: false);
                        final exerciseName = exercise['name']?.toString() ?? "Exercise";
                        final exerciseKey = exerciseName.toLowerCase();
                        
                        Exercise? match = _matchCache[exerciseKey];
                        if (match == null) {
                          try {
                            match = provider.exercises.firstWhere(
                              (e) => e.name.toLowerCase().contains(exerciseKey),
                              orElse: () => throw Exception(),
                            );
                            _matchCache[exerciseKey] = match;
                          } catch (_) {
                            match = Exercise(
                              id: 'default',
                              name: exerciseName,
                              bodyPart: 'General',
                              equipment: 'None',
                              target: 'Full Body',
                              secondaryMuscles: [],
                              gifUrl: '',
                              instructions: "Focus on controlled movements and proper form. Maintain a steady breathing pattern throughout the set.",
                              steps: [
                                "Start with a stable posture and engage your core.",
                                "Perform the movement with a full range of motion.",
                                "Exhale during the exertion phase of the exercise.",
                                "Control the weight on the way back to the starting position."
                              ],
                              imageUrl: '',
                              videoUrl: '',
                              category: '',
                            );
                          }
                        }
                        
                        // Ensure match is not null for the following sections
                        final exerciseMatch = match!;
                        
                        return Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Iconsax.info_circle, size: 20, color: Color(0xFF00E676)),
                              ),
                              title: Text(
                                "Instructions",
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                "Tap to view steps",
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                              children: [
                                if ((match?.steps ?? []).isNotEmpty)
                                  ...(match?.steps ?? []).asMap().entries.map((entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${entry.key + 1}.",
                                          style: const TextStyle(
                                            color: Color(0xFF00E676),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            entry.value,
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.4,
                                              color: textColor.withOpacity(0.8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )).toList()
                                else
                                  Text(
                                    (match?.instructions ?? "").isNotEmpty ? match!.instructions : "No instructions available.",
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      color: textColor.withOpacity(0.8),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }
                    ),

                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Set ${_currentSetIndex + 1} of $totalSets",
                        style: const TextStyle(fontFamily: 'Outfit', color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                      ),
                    ),

                    const Spacer(),
                    const SizedBox(height: 20),

                    // Controls (Zero Typing)
                    Row(
                      children: [
                        Expanded(child: _buildControl(isDark, "Weight (kg)", currentSetData['weight'], (v) => _updateValue('weight', v), 2.5)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildControl(isDark, "Reps", currentSetData['reps'], (v) => _updateValue('reps', v), 1)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Log Button
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton(
                        onPressed: _logSetAndRest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 10,
                          shadowColor: const Color(0xFF00E676).withOpacity(0.4),
                        ),
                        child: Text(
                          _currentSetIndex < totalSets - 1 ? "LOG SET" : "REST", 
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildControl(bool isDark, String label, dynamic value, Function(double) onChanged, double step) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20), // Slightly smaller radius
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)), // Reduced font size
          const SizedBox(height: 8), // Reduced spacing
          Text(
            value.toStringAsFixed(value is int ? 0 : 1),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black), // Reduced font size
          ),
          const SizedBox(height: 8), // Reduced spacing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleBtn(Icons.remove, () => onChanged(-step)),
              _circleBtn(Icons.add, () => onChanged(step)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: const Color(0xFF00E676)),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Color textColor, double progress) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: Icon(Iconsax.close_circle, color: textColor), onPressed: () => Navigator.pop(context)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Iconsax.timer_1, size: 16, color: Color(0xFF00E676)),
                    const SizedBox(width: 6),
                    Text(_formatTime(_secondsElapsed), style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, color: textColor)),
                  ],
                ),
              ),
              if (_isResting)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.refresh, size: 16, color: Color(0xFF00E676)),
                      const SizedBox(width: 6),
                      Text(
                        "REST: ${_formatTime(_restSecondsRemaining)}",
                        style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                      ),
                    ],
                  ),
                ),
              IconButton(
                icon: Icon(_isPlayingMusic ? Iconsax.music_circle5 : Iconsax.music_circle, color: _isPlayingMusic ? const Color(0xFF00E676) : textColor),
                onPressed: () => setState(() => _isPlayingMusic = !_isPlayingMusic),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearPercentIndicator(
            lineHeight: 8,
            percent: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.withOpacity(0.2),
            progressColor: const Color(0xFF00E676),
            barRadius: const Radius.circular(4),
            animation: true,
            animateFromLastPercent: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRestScreen(bool isDark, Color textColor) {
    // Determine Next State (Next Set vs Next Exercise)
    String titleText = "Rest";
    String subtitleText = "Next Set";
    String? imageUrl;
    
    final provider = Provider.of<WorkoutProvider>(context, listen: false);

    if (_currentSetIndex < _logs[_currentExerciseIndex]!.length - 1) {
      // Resting between sets of SAME exercise
      final name = _exercises[_currentExerciseIndex]['name']?.toString().toLowerCase() ?? "";
      titleText = _exercises[_currentExerciseIndex]['name'] ?? "Rest";
      subtitleText = "Set ${_currentSetIndex + 2} of ${_logs[_currentExerciseIndex]!.length}";
      
      // Use Cached image
      if (_matchCache.containsKey(name)) {
        imageUrl = _matchCache[name]!.imageUrl;
      } else {
        try {
          final match = provider.exercises.firstWhere((e) => e.name.toLowerCase().contains(name), orElse: () => provider.exercises.first);
          _matchCache[name] = match;
          imageUrl = match.imageUrl;
        } catch (_) {}
      }

    } else if (_currentExerciseIndex < _exercises.length - 1) {
      // Resting before NEXT exercise - The "Transition Card"
      final nextName = _exercises[_currentExerciseIndex + 1]['name']?.toString().toLowerCase() ?? "";
      final finishedName = _exercises[_currentExerciseIndex]['name'] ?? "Exercise";
      
      titleText = "EXERCISE COMPLETE";
      subtitleText = "UP NEXT: ${_exercises[_currentExerciseIndex + 1]['name'] ?? "NEXT"}";
      
      // Use Cached image of the NEXT exercise
      if (_matchCache.containsKey(nextName)) {
        imageUrl = _matchCache[nextName]!.imageUrl;
      } else {
        try {
          final nextMatch = provider.exercises.firstWhere((e) => e.name.toLowerCase().contains(nextName), orElse: () => provider.exercises.first);
          _matchCache[nextName] = nextMatch;
          imageUrl = nextMatch.imageUrl;
        } catch (_) {}
      }
    } else {
      titleText = "WORKOUT COMPLETE";
      subtitleText = "GREAT WORK TODAY!";
    }

    return Stack(
      children: [
        // 1. Top Banner Image (if available)
        if (imageUrl != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4, // Top 40%
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                ),
                // Gradient fade to blend with background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F5),
                      ],
                      stops: const [0.6, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // 2. Content Overlay
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3), 
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  titleText.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 36, 
                    letterSpacing: 1.5, 
                    fontWeight: FontWeight.w400, 
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitleText.toUpperCase(),
                style: TextStyle(
                  fontSize: 12, 
                  letterSpacing: 5, 
                  fontWeight: FontWeight.bold, 
                  color: const Color(0xFF00E676).withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 40),
              
              // Timer
              Text(
                _formatTime(_restSecondsRemaining),
                style: GoogleFonts.teko(
                  fontSize: 150, 
                  fontWeight: FontWeight.w400, 
                  color: const Color(0xFF00E676),
                  height: 0.8,
                  shadows: [
                    Shadow(blurRadius: 2, color: const Color(0xFF00E676).withOpacity(0.15), offset: const Offset(0,0))
                  ]
                ),
              ),
                
              const Spacer(flex: 3),

              // Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _restControlBtn(Icons.remove, "-10s", () => setState(() => _restSecondsRemaining = (_restSecondsRemaining - 10).clamp(0, 300)), isDark),
                    ElevatedButton(
                      onPressed: _skipRest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 10,
                        shadowColor: const Color(0xFF00E676).withOpacity(0.5),
                      ),
                      child: const Text("SKIP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    _restControlBtn(Icons.add, "+10s", () => setState(() => _restSecondsRemaining += 10), isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _restControlBtn(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? Colors.white24 : Colors.black12)
            ),
            child: Icon(icon, color: isDark ? Colors.white : Colors.black),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
      ],
    );
  }

  void _showInstructions(BuildContext context, Exercise exercise, bool isDark, Color textColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                exercise.name,
                style: TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 16),
              
              // Tags
              Row(
                children: [
                  _buildTag(exercise.bodyPart, Colors.blue),
                  const SizedBox(width: 8),
                  _buildTag(exercise.target, Colors.orange),
                ],
              ),
              const SizedBox(height: 24),
              
              // Instructions
              const Text(
                "INSTRUCTIONS",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              
              if (exercise.steps.isNotEmpty)
                ...exercise.steps.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "${entry.key + 1}",
                          style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(fontSize: 16, height: 1.5, color: textColor.withOpacity(0.9)),
                        ),
                      ),
                    ],
                  ),
                )).toList()
              else
                Text(
                  exercise.instructions.isNotEmpty ? exercise.instructions : "No instructions available.",
                  style: TextStyle(fontSize: 16, height: 1.5, color: textColor.withOpacity(0.9)),
                ),
                
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
