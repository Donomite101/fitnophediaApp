import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../workout/presentation/widgets/unified_workout_card.dart';

typedef WorkoutTapCallback = void Function(String workoutId, Map<String, dynamic> workoutData);

class WorkoutSectionCard extends StatefulWidget {
  final String gymId;
  final String memberId;
  final VoidCallback? onTapSeeAll;
  final WorkoutTapCallback? onTapItem;
  final Color primaryGreen;
  final Color cardBackground;
  final Color textPrimary;
  final Color greyText;
  final int limit;

  const WorkoutSectionCard({
    Key? key,
    required this.gymId,
    required this.memberId,
    required this.primaryGreen,
    required this.cardBackground,
    required this.textPrimary,
    required this.greyText,
    this.onTapSeeAll,
    this.onTapItem,
    this.limit = 5,
  }) : super(key: key);

  @override
  State<WorkoutSectionCard> createState() => _WorkoutSectionCardState();
}

class _WorkoutSectionCardState extends State<WorkoutSectionCard> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _workoutsStream;
  bool _isLoading = true;
  List<Map<String, dynamic>> _workouts = [];

  @override
  void initState() {
    super.initState();
    _initializeWorkoutsStream();
  }

  void _initializeWorkoutsStream() {
    _workoutsStream = FirebaseFirestore.instance
        .collection('member')
        .doc(widget.memberId)
        .collection('workouts')
        .orderBy('createdAt', descending: true)
        .limit(widget.limit)
        .withConverter<Map<String, dynamic>>(
      fromFirestore: (snap, _) => (snap.data() as Map<String, dynamic>?) ?? <String, dynamic>{},
      toFirestore: (value, _) => value,
    )
        .snapshots();
  }

  Future<void> _loadFallbackWorkouts() async {
    try {
      final fallbackDocs = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(widget.gymId)
          .collection('members')
          .doc(widget.memberId)
          .collection('workouts')
          .orderBy('createdAt', descending: true)
          .limit(widget.limit)
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => (snap.data() as Map<String, dynamic>?) ?? <String, dynamic>{},
        toFirestore: (value, _) => value,
      )
          .get();

      if (mounted) {
        setState(() {
          _workouts = fallbackDocs.docs.map((doc) {
            final data = doc.data() ?? <String, dynamic>{};
            return {...data, 'id': doc.id, 'isFirestore': true};
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fallback workouts error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Featured Workouts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: widget.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (widget.onTapSeeAll != null)
                  TextButton(
                    onPressed: widget.onTapSeeAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Iconsax.arrow_right_3,
                          size: 16,
                          color: widget.primaryGreen,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Workout Cards
          SizedBox(
            height: 180,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _workoutsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
                  return _buildLoadingState();
                }

                if (snapshot.hasError) {
                  debugPrint('Workouts stream error: ${snapshot.error}');
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_workouts.isEmpty && _isLoading) {
                      _loadFallbackWorkouts();
                    }
                  });
                  return _buildEmptyOrErrorState();
                }

                final docs = snapshot.data?.docs ?? [];
                List<Map<String, dynamic>> workouts = [];

                if (docs.isNotEmpty) {
                  workouts = docs.map((doc) {
                    final data = doc.data() ?? <String, dynamic>{};
                    return {...data, 'id': doc.id, 'isFirestore': true};
                  }).toList();
                } else if (_workouts.isEmpty) {
                  // Try fallback
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_isLoading) {
                      _loadFallbackWorkouts();
                    }
                  });
                  return _buildLoadingState();
                } else {
                  workouts = _workouts;
                }

                _isLoading = false;

                if (workouts.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildWorkoutCards(workouts);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCards(List<Map<String, dynamic>> workouts) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: workouts.length,
      itemBuilder: (context, index) {
        final workout = workouts[index];
        return Container(
          width: 260,
          margin: EdgeInsets.only(
            right: index == workouts.length - 1 ? 0 : 16,
          ),
          child: UnifiedWorkoutCard(
            data: workout,
            gymId: widget.gymId,
            memberId: widget.memberId,
            isDark: Theme.of(context).brightness == Brightness.dark,
            // workoutProgress: {}, // Optional: Add progress if available in dashboard
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          width: 260,
          margin: EdgeInsets.only(right: index == 2 ? 0 : 16),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: widget.cardBackground.withOpacity(0.6),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.danger,
              size: 48,
              color: widget.greyText.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No workouts available',
              style: TextStyle(
                color: widget.greyText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "View All" to explore',
              style: TextStyle(
                color: widget.greyText.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyOrErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.warning_2,
              size: 48,
              color: widget.greyText.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading workouts...',
              style: TextStyle(
                color: widget.greyText,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


