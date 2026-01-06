import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
            height: 200,
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
          width: 280,
          margin: EdgeInsets.only(
            right: index == workouts.length - 1 ? 0 : 16,
          ),
          child: WorkoutCard(
            workoutData: workout,
            primaryGreen: widget.primaryGreen,
            cardBackground: widget.cardBackground,
            textPrimary: widget.textPrimary,
            greyText: widget.greyText,
            onTap: () {
              if (widget.onTapItem != null) {
                widget.onTapItem!(workout['id'] ?? '', workout);
              }
            },
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
          width: 280,
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

class WorkoutCard extends StatefulWidget {
  final Map<String, dynamic> workoutData;
  final Color primaryGreen;
  final Color cardBackground;
  final Color textPrimary;
  final Color greyText;
  final VoidCallback? onTap;

  const WorkoutCard({
    Key? key,
    required this.workoutData,
    required this.primaryGreen,
    required this.cardBackground,
    required this.textPrimary,
    required this.greyText,
    this.onTap,
  }) : super(key: key);

  @override
  State<WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<WorkoutCard> {
  String? _imageUrl;
  bool _isLoadingImage = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadImage() async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () async {
      try {
        final exercises = widget.workoutData['exercises'] as List<dynamic>?;
        if (exercises == null || exercises.isEmpty) {
          if (mounted) {
            setState(() => _isLoadingImage = false);
          }
          return;
        }

        final first = exercises[0] as Map<String, dynamic>?;
        if (first == null) {
          if (mounted) {
            setState(() => _isLoadingImage = false);
          }
          return;
        }

        // Try direct image path first
        final directImagePath = (first['image_path'] as String?)?.trim();
        if (directImagePath != null && directImagePath.isNotEmpty) {
          final client = Supabase.instance.client;
          final url = client.storage.from('workouts').getPublicUrl(directImagePath);
          if (mounted) {
            setState(() {
              _imageUrl = url;
              _isLoadingImage = false;
            });
          }
          return;
        }

        // Try exercise ID
        final exerciseId = (first['exerciseId'] as String?)?.trim();
        if (exerciseId != null && exerciseId.isNotEmpty) {
          final client = Supabase.instance.client;
          final response = await client
              .from('exercises')
              .select('image_path')
              .eq('id', exerciseId)
              .maybeSingle()
              .timeout(const Duration(seconds: 3));

          if (response != null && response['image_path'] != null) {
            final imagePath = response['image_path'] as String;
            final url = Supabase.instance.client.storage.from('workouts').getPublicUrl(imagePath);
            if (mounted) {
              setState(() {
                _imageUrl = url;
                _isLoadingImage = false;
              });
            }
            return;
          }
        }
      } catch (e) {
        debugPrint('Workout card image load error: $e');
      }

      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
    });
  }

  Color _getDifficultyColor(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return const Color(0xFF10B981); // Green
      case 'intermediate':
        return const Color(0xFFF59E0B); // Amber
      case 'advanced':
        return const Color(0xFFEF4444); // Red
      default:
        return widget.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.workoutData;
    final name = (data['name'] ?? data['title'] ?? 'Workout') as String;
    final durationMin = (data['durationMin'] ?? data['duration'] ?? data['durationMinutes'] ?? 30).toString();
    final level = (data['level'] ?? 'Intermediate') as String;
    final tags = (data['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[];
    final exerciseCount = (data['exercises'] as List<dynamic>?)?.length ?? 0;

    final difficultyColor = _getDifficultyColor(level);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 280,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.35 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Background: image if available, otherwise strong gradient
                Positioned.fill(
                  child: _isLoadingImage
                      ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [difficultyColor.withOpacity(0.95), difficultyColor.withOpacity(0.7)],
                      ),
                    ),
                  )
                      : (_imageUrl != null
                      ? CachedNetworkImage(
                    imageUrl: _imageUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    placeholder: (context, url) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [difficultyColor.withOpacity(0.95), difficultyColor.withOpacity(0.7)],
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [difficultyColor.withOpacity(0.95), difficultyColor.withOpacity(0.7)],
                        ),
                      ),
                    ),
                  )
                      : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [difficultyColor.withOpacity(0.95), difficultyColor.withOpacity(0.7)],
                      ),
                    ),
                  )),
                ),

                // Soft vignette for legibility
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.06), Colors.black.withOpacity(0.45)],
                        stops: const [0.35, 1.0],
                      ),
                    ),
                  ),
                ),

                // Top row: small chips
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Row(
                    children: [
                      if (tags.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Iconsax.tag, size: 12, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                tags.first.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          level.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content: title + stats
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),

                      // Stats row (glass cards)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.06)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Iconsax.activity, size: 14, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '$exerciseCount exercises',
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Iconsax.clock, size: 14, color: difficultyColor),
                                const SizedBox(width: 8),
                                Text(
                                  '$durationMin min',
                                  style: TextStyle(color: difficultyColor, fontSize: 13, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tap overlay (keeps existing ripple behavior)
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTap,
                      splashColor: Colors.white.withOpacity(0.08),
                      highlightColor: Colors.white.withOpacity(0.03),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
