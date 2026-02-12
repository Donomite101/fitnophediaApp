// lib/features/member/challenges/member_challenges_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';


class MemberChallengesScreen extends StatefulWidget {
  final String gymId;
  final String memberId;

  final String? initialChallengeId;
  final Map<String, dynamic>? initialChallengeData;

  const MemberChallengesScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
    this.initialChallengeId,
    this.initialChallengeData,
  }) : super(key: key);

  @override
  State<MemberChallengesScreen> createState() =>
      _MemberChallengesScreenState();
}

class _MemberChallengesScreenState extends State<MemberChallengesScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    if (widget.initialChallengeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openInitialChallenge();
      });
    }
  }

  Future<void> _openInitialChallenge() async {
    try {
      final challengeDoc = await _challengesRef.doc(widget.initialChallengeId).get();
      if (!challengeDoc.exists) return;

      final achSnap = await _achievementDoc(widget.initialChallengeId!).get();
      final achData = achSnap.data() as Map<String, dynamic>? ?? {};

      if (mounted) {
        _openDetails(challengeDoc, achData);
      }
    } catch (e) {
      debugPrint('Error opening initial challenge: $e');
    }
  }

  CollectionReference get _challengesRef =>
      _db.collection('global_challenges');

  CollectionReference get _achievementsCol => _db
      .collection('gyms')
      .doc(widget.gymId)
      .collection('members')
      .doc(widget.memberId)
      .collection('achievements')
      .doc('challenges')
      .collection('items');

  DocumentReference _achievementDoc(String challengeId) {
    return _achievementsCol.doc(challengeId);
  }

  final Color _bg = const Color(0xFF0E0E10);
  final Color _card = const Color(0xFF17181B);
  final Color _accentGreen = const Color(0xFF00E676);
  final Color _accentRed = const Color(0xFFFF5252);
  final Color _accentYellow = const Color(0xFFFFD54F);

  // ---------- helpers ----------

  num _parseNum(dynamic v) {
    if (v is num) return v;
    if (v == null) return 0;
    return num.tryParse(v.toString()) ?? 0;
  }

  int _parseInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final dt = ts.toDate();
    return DateFormat('dd MMM').format(dt);
  }

  bool _isWithinDates(Timestamp? startAt, Timestamp? endAt) {
    final now = DateTime.now();
    final start = startAt?.toDate();
    final end = endAt?.toDate();
    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;
    return true;
  }

  String _sectionLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'starter':
        return 'Starter Challenges';
      case 'consistency':
        return 'Consistency';
      case 'advanced':
        return 'Advanced';
      default:
        return 'More Challenges';
    }
  }

  // ---------- JOIN / LEAVE ----------

  Future<void> _joinChallenge(DocumentSnapshot challengeDoc) async {
    final String challengeId = challengeDoc.id;
    final achievementRef = _achievementDoc(challengeId);
    final challengeRef = _challengesRef.doc(challengeId);

    try {
      await _db.runTransaction((tx) async {
        // READS first
        final challengeSnap = await tx.get(challengeRef);
        final challengeRaw = challengeSnap.data();
        final challengeData = challengeRaw is Map<String, dynamic>
            ? challengeRaw
            : <String, dynamic>{};

        final num challengeTarget = _parseNum(challengeData['targetValue']);

        final achSnap = await tx.get(achievementRef);
        final achRaw = achSnap.data();
        final existing =
        achRaw is Map<String, dynamic> ? achRaw : <String, dynamic>{};

        final num existingProgress = _parseNum(existing['progressValue']);
        final num existingTarget = _parseNum(existing['targetValue']);
        final targetToUse =
        existingTarget > 0 ? existingTarget : challengeTarget;

        final existingStartedAt = existing['startedAt'];
        final now = FieldValue.serverTimestamp();

        // WRITES after all reads
        tx.update(challengeRef, {
          'joinedBy': FieldValue.arrayUnion([widget.memberId]),
        });

        tx.set(
          achievementRef,
          {
            'challengeId': challengeId,
            'status': 'joined',
            'progressValue': existingProgress,
            'targetValue': targetToUse,
            'startedAt': existingStartedAt ?? now,
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      debugPrint('Error joining challenge $challengeId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join challenge: $e'),
          ),
        );
      }
    }
  }

  Future<void> _leaveChallenge(DocumentSnapshot challengeDoc) async {
    final challengeId = challengeDoc.id;
    final achievementRef = _achievementDoc(challengeId);
    final challengeRef = _challengesRef.doc(challengeId);

    try {
      await _db.runTransaction((tx) async {
        tx.update(challengeRef, {
          'joinedBy': FieldValue.arrayRemove([widget.memberId]),
        });

        tx.set(
          achievementRef,
          {
            'status': 'left',
          },
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      debugPrint('Error leaving challenge $challengeId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave challenge: $e'),
          ),
        );
      }
    }
  }

  // ---------- WORKOUT NAV FROM SINGLE_WORKOUT CHALLENGE ----------

  Future<void> _startSingleWorkoutChallenge({
    required String challengeId,
    required String workoutKey,
    required String title,
  }) async {
    // Simple payload: one exercise, reps-only (no timer)
    final Map<String, dynamic> workoutData = {
      'id': workoutKey,
      'workoutId': workoutKey,
      'name': title.isNotEmpty ? title : 'Challenge Workout',
      'duration': 10,
      'difficulty': 'Intermediate',
      'exercises': [
        {
          'name': title.isNotEmpty ? title : 'Challenge Exercise',
          'sets': 1,
          'reps': 20, // later map from challenge.targetValue if you want
          'restSeconds': 0,
          'estimatedTime': 0,
          'noTimer': true,
        },
      ],
    };

    // if (!mounted) return;
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => WorkoutPlayerScreen(
    //       gymId: widget.gymId,
    //       memberId: widget.memberId,
    //       workoutData: workoutData,
    //       workoutId: workoutKey,
    //       linkedChallengeId: challengeId,
    //       linkedChallengeScope: 'global',
    //       linkedChallengeXp: null,
    //     ),
    //   ),
    // );
  }

  // ---------- DETAILS SHEET ----------

  void _openDetails(
      DocumentSnapshot challengeDoc,
      Map<String, dynamic> achData,
      ) {
    final raw = challengeDoc.data();
    final data =
    raw is Map<String, dynamic> ? raw : <String, dynamic>{};

    final challengeId = challengeDoc.id;
    final title = (data['title'] ?? 'Untitled').toString();
    final description = (data['description'] ?? '').toString();
    final xpReward = _parseInt(data['xpReward']);
    final startAt = data['startAt'] is Timestamp
        ? data['startAt'] as Timestamp
        : null;
    final endAt = data['endAt'] is Timestamp
        ? data['endAt'] as Timestamp
        : null;
    final typeRaw = (data['type'] ?? 'COUNT_WORKOUTS').toString();
    final type = typeRaw.toUpperCase();
    final section = (data['section'] ?? '').toString();
    final workoutId = (data['workoutId'] ?? '').toString();
    final bool hasLinkedWorkout = workoutId.isNotEmpty;

    final status = (achData['status'] ?? 'none').toString();
    final isJoined = status == 'joined';
    final isCompleted = status == 'completed';
    final progress = _parseNum(achData['progressValue']);
    final target = _parseNum(achData['targetValue']);

    final isAvailable =
        (data['isActive'] == true) && _isWithinDates(startAt, endAt);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141416),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Status chip + dates
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? _accentYellow.withOpacity(0.18)
                              : (isJoined
                              ? Colors.green.withOpacity(0.18)
                              : Colors.blue.withOpacity(0.18)),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isCompleted
                              ? 'COMPLETED'
                              : (isJoined ? 'JOINED' : 'NEW'),
                          style: GoogleFonts.poppins(
                            color: isCompleted
                                ? _accentYellow
                                : (isJoined
                                ? _accentGreen
                                : Colors.lightBlueAccent),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatDate(startAt)} → ${_formatDate(endAt)}',
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (xpReward > 0)
                        _metaChip(
                          icon: Icons.bolt,
                          label: '$xpReward XP',
                          color: _accentYellow,
                        ),
                      _metaChip(
                        icon: Icons.category_outlined,
                        label: type,
                        color: Colors.orangeAccent,
                      ),
                      if (section.isNotEmpty)
                        _metaChip(
                          icon: Icons.layers,
                          label: section,
                          color: Colors.lightBlueAccent,
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (target > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress: ${progress.toInt()} / ${target.toInt()}',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildProgressBar(progress, target),
                      ],
                    ),

                  const SizedBox(height: 18),

                  // If challenge has a linked workoutId, show Start button
                  if (hasLinkedWorkout) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: (isAvailable && isJoined)
                            ? () async {
                          Navigator.pop(context); // close sheet
                          await _startSingleWorkoutChallenge(
                            challengeId: challengeId,
                            workoutKey: workoutId,
                            title: title,
                          );
                        }
                            : null,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: (isAvailable && isJoined)
                                ? _accentGreen
                                : Colors.white24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(
                          Icons.fitness_center,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          isJoined
                              ? 'Start Challenge Workout'
                              : 'Join to Start Workout',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Join / Leave
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (!isAvailable || isCompleted)
                          ? null
                          : () async {
                        if (isJoined) {
                          await _leaveChallenge(challengeDoc);
                        } else {
                          await _joinChallenge(challengeDoc);
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        isJoined ? Colors.white10 : _accentGreen,
                        foregroundColor:
                        isJoined ? Colors.white : Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isCompleted
                            ? 'Completed'
                            : (isJoined ? 'Leave Challenge' : 'Join Challenge'),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- small widgets ----------

  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(num progress, num target) {
    if (target <= 0) return const SizedBox.shrink();
    final ratio = (progress / target).clamp(0.0, 1.0).toDouble();

    return Container(
      height: 6,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: ratio,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentGreen, _accentYellow],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChallengeCard(
      DocumentSnapshot challengeDoc,
      Map<String, dynamic> achData,
      ) {
    final raw = challengeDoc.data();
    final data =
    raw is Map<String, dynamic> ? raw : <String, dynamic>{};

    final challengeId = challengeDoc.id;
    final title = (data['title'] ?? 'Untitled').toString();
    final description = (data['description'] ?? '').toString();
    final xpReward = _parseInt(data['xpReward']);
    final startAt = data['startAt'] is Timestamp
        ? data['startAt'] as Timestamp
        : null;
    final endAt = data['endAt'] is Timestamp
        ? data['endAt'] as Timestamp
        : null;
    final type = (data['type'] ?? 'COUNT_WORKOUTS')
        .toString()
        .toUpperCase();

    final status = (achData['status'] ?? 'none').toString();
    final isJoined = status == 'joined';
    final isCompleted = status == 'completed';
    final progress = _parseNum(achData['progressValue']);
    final target = _parseNum(achData['targetValue']);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetails(challengeDoc, achData),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? _accentYellow.withOpacity(0.18)
                          : (isJoined
                          ? Colors.green.withOpacity(0.18)
                          : Colors.blue.withOpacity(0.18)),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isCompleted
                          ? 'COMPLETED'
                          : (isJoined ? 'JOINED' : 'NEW'),
                      style: GoogleFonts.poppins(
                        color: isCompleted
                            ? _accentYellow
                            : (isJoined
                            ? _accentGreen
                            : Colors.lightBlueAccent),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (xpReward > 0)
                    _metaChip(
                      icon: Icons.bolt,
                      label: '$xpReward XP',
                      color: _accentYellow,
                    ),
                  _metaChip(
                    icon: Icons.category_outlined,
                    label: type,
                    color: Colors.orangeAccent,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event,
                      size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatDate(startAt)}  →  ${_formatDate(endAt)}',
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  if (!isCompleted)
                    TextButton(
                      onPressed: () {
                        if (isJoined) {
                          _leaveChallenge(challengeDoc);
                        } else {
                          _joinChallenge(challengeDoc);
                        }
                      },
                      child: Text(
                        isJoined ? 'Leave' : 'Join',
                        style: GoogleFonts.poppins(
                          color: isJoined ? _accentRed : _accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              if (target > 0) ...[
                const SizedBox(height: 4),
                _buildProgressBar(progress, target),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Challenges',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _challengesRef
            .where('status', isEqualTo: 'active')
            .orderBy('createdAt', descending: false)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text(
                'Error: ${snap.error}',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter by active + date
          final allDocs = snap.data!.docs.where((doc) {
            final raw = doc.data();
            final data =
            raw is Map<String, dynamic> ? raw : <String, dynamic>{};

            final startAt = data['startAt'] is Timestamp
                ? data['startAt'] as Timestamp
                : null;
            final endAt = data['endAt'] is Timestamp
                ? data['endAt'] as Timestamp
                : null;
            final isActive = data['isActive'] is bool
                ? data['isActive'] as bool
                : true;

            return isActive && _isWithinDates(startAt, endAt);
          }).toList();

          if (allDocs.isEmpty) {
            return Center(
              child: Text(
                'No active challenges right now.\nCheck back soon.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white60),
              ),
            );
          }

          // Now stream achievements to know completed vs active
          return StreamBuilder<QuerySnapshot>(
            stream: _achievementsCol.snapshots(),
            builder: (context, achSnap) {
              if (achSnap.hasError) {
                return Center(
                  child: Text(
                    'Error: ${achSnap.error}',
                    style:
                    GoogleFonts.poppins(color: Colors.white70),
                  ),
                );
              }

              final Map<String, Map<String, dynamic>> achById = {};
              if (achSnap.hasData) {
                for (final d in achSnap.data!.docs) {
                  final data = d.data();
                  achById[d.id] = data is Map<String, dynamic>
                      ? data
                      : <String, dynamic>{};
                }
              }

              // Split into active vs completed per-member
              final List<QueryDocumentSnapshot> activeDocs = [];
              final List<QueryDocumentSnapshot> completedDocs = [];

              for (final doc in allDocs) {
                final achData =
                    achById[doc.id] ?? <String, dynamic>{};
                final status =
                (achData['status'] ?? 'none').toString();
                if (status == 'completed') {
                  completedDocs.add(doc);
                } else {
                  activeDocs.add(doc);
                }
              }

              // Group ACTIVE by "section"
              final Map<String, List<QueryDocumentSnapshot>> bySection =
              {};
              for (final d in activeDocs) {
                final raw = d.data();
                final data = raw is Map<String, dynamic>
                    ? raw
                    : <String, dynamic>{};
                final section = (data['section'] ?? 'other').toString();
                bySection.putIfAbsent(section, () => []).add(d);
              }

              final sections = bySection.keys.toList()
                ..sort((a, b) => a.compareTo(b));

              return ListView(
                padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // ---- ACTIVE CHALLENGES ----
                  Text(
                    'Active Challenges',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (sections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'No active challenges yet.',
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ...sections.map((sectionKey) {
                      final sectionChallenges =
                          bySection[sectionKey] ?? [];

                      return Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 4, right: 4, top: 16),
                            child: Text(
                              _sectionLabel(sectionKey),
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...sectionChallenges.map((challengeDoc) {
                            final achData =
                                achById[challengeDoc.id] ??
                                    <String, dynamic>{};
                            return _buildChallengeCard(
                                challengeDoc, achData);
                          }).toList(),
                        ],
                      );
                    }).toList(),

                  const SizedBox(height: 24),

                  // ---- COMPLETED CHALLENGES ----
                  Text(
                    'Completed Challenges',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (completedDocs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'You have not completed any challenges yet.',
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    ...completedDocs.map((doc) {
                      final achData =
                          achById[doc.id] ?? <String, dynamic>{};
                      return _buildChallengeCard(doc, achData);
                    }).toList(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
