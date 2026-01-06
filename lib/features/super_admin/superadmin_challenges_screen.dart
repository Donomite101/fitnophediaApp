// lib/features/superadmin/challenges/superadmin_challenges_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class SuperAdminChallengesScreen extends StatefulWidget {
  const SuperAdminChallengesScreen({Key? key}) : super(key: key);

  @override
  State<SuperAdminChallengesScreen> createState() =>
      _SuperAdminChallengesScreenState();
}

class _SuperAdminChallengesScreenState
    extends State<SuperAdminChallengesScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _challengesRef =>
      _db.collection('global_challenges');

  final Color _bg = const Color(0xFF0E0E10);
  final Color _surface = const Color(0xFF141416);
  final Color _card = const Color(0xFF17181B);
  final Color _accentGreen = const Color(0xFF00E676);
  final Color _accentRed = const Color(0xFFFF5252);
  final Color _accentYellow = const Color(0xFFFFD54F);

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final dt = ts.toDate();
    return DateFormat('dd MMM yyyy').format(dt);
  }

  Future<void> _confirmDelete(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: Text(
          'Delete challenge?',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently delete "$title". This action cannot be undone.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: _accentRed),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _challengesRef.doc(id).delete();
    }
  }

  Future<void> _toggleActive(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final isActive = data['isActive'] == true;
    await _challengesRef.doc(doc.id).update({
      'isActive': !isActive,
      'status': !isActive ? 'active' : 'inactive',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _openCreate() {
    _openForm();
  }

  void _openEdit(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final model = AdminChallengeModel.fromMap(doc.id, data);
    _openForm(existing: model);
  }

  Future<void> _openForm({AdminChallengeModel? existing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AdminChallengeFormSheet(
          existing: existing,
          onSaved: (model) async {
            if (existing == null) {
              await _challengesRef.add(model.toFirestoreCreate());
            } else {
              await _challengesRef.doc(existing.id).set(
                model.toFirestoreUpdate(),
                SetOptions(merge: true),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Challenges (SuperAdmin)',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _accentGreen,
        icon: const Icon(Icons.add, color: Colors.black),
        label: Text(
          'New Challenge',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: _openCreate,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
        _challengesRef.orderBy('createdAt', descending: true).snapshots(),
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

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No challenges created yet.\nTap "New Challenge" to add one.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white60),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};

              final isActive = data['isActive'] == true;
              final title = (data['title'] ?? 'Untitled').toString();
              final description = (data['description'] ?? '').toString();
              final xpReward = (data['xpReward'] ?? 0) is num
                  ? (data['xpReward'] as num).toInt()
                  : int.tryParse(data['xpReward']?.toString() ?? '0') ?? 0;
              final startAt = data['startAt'] is Timestamp
                  ? data['startAt'] as Timestamp
                  : null;
              final endAt = data['endAt'] is Timestamp
                  ? data['endAt'] as Timestamp
                  : null;
              final winnerType =
              (data['winnerType'] ?? 'xp').toString().toUpperCase();
              final scope =
              (data['scope'] ?? 'global').toString().toUpperCase();
              final type =
              (data['type'] ?? 'generic').toString().toUpperCase();
              final workoutId = (data['workoutId'] ?? '').toString();

              final metric =
              (data['metric'] ?? 'xp').toString().toUpperCase();
              final targetValue = (data['targetValue'] ?? 0);
              final rewardBadgeId =
              (data['rewardBadgeId'] ?? '').toString();

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openEdit(doc),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + status
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
                                color: isActive
                                    ? Colors.green.withOpacity(0.18)
                                    : Colors.red.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isActive ? 'ACTIVE' : 'INACTIVE',
                                style: GoogleFonts.poppins(
                                  color:
                                  isActive ? _accentGreen : _accentRed,
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
                        // Meta row
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _metaChip(
                              icon: Icons.bolt,
                              label: '$xpReward XP',
                              color: _accentYellow,
                            ),
                            _metaChip(
                              icon: Icons.flag_circle_outlined,
                              label: winnerType,
                              color: Colors.lightBlueAccent,
                            ),
                            _metaChip(
                              icon: Icons.public,
                              label: scope,
                              color: Colors.purpleAccent,
                            ),
                            _metaChip(
                              icon: Icons.category_outlined,
                              label: type,
                              color: Colors.orangeAccent,
                            ),
                            _metaChip(
                              icon: Icons.stacked_line_chart,
                              label: 'METRIC: $metric',
                              color: Colors.tealAccent,
                            ),
                            if (targetValue != null &&
                                (targetValue is num) &&
                                targetValue > 0)
                              _metaChip(
                                icon: Icons.track_changes,
                                label: 'TARGET: $targetValue',
                                color: Colors.lightGreenAccent,
                              ),
                            if (workoutId.isNotEmpty &&
                                type == 'WORKOUT')
                              _metaChip(
                                icon: Icons.fitness_center,
                                label: workoutId,
                                color: Colors.cyanAccent,
                              ),
                            if (rewardBadgeId.isNotEmpty)
                              _metaChip(
                                icon: Icons.emoji_events_outlined,
                                label: 'BADGE: $rewardBadgeId',
                                color: Colors.amberAccent,
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
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _openEdit(doc),
                              icon: const Icon(Icons.edit,
                                  size: 16, color: Colors.white70),
                              label: Text(
                                'Edit',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _toggleActive(doc),
                              icon: Icon(
                                isActive
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                                size: 18,
                                color: isActive
                                    ? _accentYellow
                                    : _accentGreen,
                              ),
                              label: Text(
                                isActive ? 'Deactivate' : 'Activate',
                                style: GoogleFonts.poppins(
                                  color: isActive
                                      ? _accentYellow
                                      : _accentGreen,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () =>
                                  _confirmDelete(doc.id, title),
                              icon: Icon(Icons.delete_outline,
                                  size: 16, color: _accentRed),
                              label: Text(
                                'Delete',
                                style: GoogleFonts.poppins(
                                  color: _accentRed,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

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
}

// -------------------------------------------------------------
// ADMIN CHALLENGE MODEL
// -------------------------------------------------------------

class AdminChallengeModel {
  final String? id;
  final String title;
  final String description;
  final String image;
  final int xpReward; // XP reward on completion
  final DateTime? startAt;
  final DateTime? endAt;
  final bool isActive;
  final String winnerType;
  final String scope;

  // existing:
  final String type;      // 'generic' | 'workout' | 'referral'
  final String workoutId;

  // NEW:
  final String metric;      // 'xp' | 'workout' | 'referral' | 'visit' | 'promo'
  final num targetValue;    // required amount (XP, workouts, referrals, visits..)
  final String rewardBadgeId;

  AdminChallengeModel({
    this.id,
    required this.title,
    required this.description,
    required this.image,
    required this.xpReward,
    required this.startAt,
    required this.endAt,
    required this.isActive,
    required this.winnerType,
    required this.scope,
    required this.type,
    required this.workoutId,
    required this.metric,
    required this.targetValue,
    required this.rewardBadgeId,
  });

  factory AdminChallengeModel.fromMap(String id, Map<String, dynamic> map) {
    num _numField(dynamic v) {
      if (v is num) return v;
      return num.tryParse(v?.toString() ?? '0') ?? 0;
    }

    int _intField(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '0') ?? 0;
    }

    return AdminChallengeModel(
      id: id,
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      image: (map['image'] ?? '').toString(),
      xpReward: _intField(map['xpReward']),
      startAt: map['startAt'] is Timestamp
          ? (map['startAt'] as Timestamp).toDate()
          : null,
      endAt: map['endAt'] is Timestamp
          ? (map['endAt'] as Timestamp).toDate()
          : null,
      isActive: map['isActive'] == true,
      winnerType: (map['winnerType'] ?? 'xp').toString(),
      scope: (map['scope'] ?? 'global').toString(),
      type: (map['type'] ?? 'generic').toString(),
      workoutId: (map['workoutId'] ?? '').toString(),
      metric: (map['metric'] ?? 'xp').toString(),
      targetValue: _numField(map['targetValue']),
      rewardBadgeId: (map['rewardBadgeId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'image': image.trim(),
      'xpReward': xpReward,
      'startAt': startAt != null ? Timestamp.fromDate(startAt!) : null,
      'endAt': endAt != null ? Timestamp.fromDate(endAt!) : null,
      'isActive': isActive,
      'status': isActive ? 'active' : 'inactive',
      'winnerType': winnerType,
      'scope': scope,
      'type': type,
      'workoutId': workoutId.trim(),

      // NEW
      'metric': metric,
      'targetValue': targetValue,
      'rewardBadgeId': rewardBadgeId.trim(),

      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'joinedBy': <String>[],
      'completedBy': <String>[],
      'progress': <String, dynamic>{},
    }..removeWhere((key, value) => value == null);
  }

  Map<String, dynamic> toFirestoreUpdate() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'image': image.trim(),
      'xpReward': xpReward,
      'startAt': startAt != null ? Timestamp.fromDate(startAt!) : null,
      'endAt': endAt != null ? Timestamp.fromDate(endAt!) : null,
      'isActive': isActive,
      'status': isActive ? 'active' : 'inactive',
      'winnerType': winnerType,
      'scope': scope,
      'type': type,
      'workoutId': workoutId.trim(),

      // NEW
      'metric': metric,
      'targetValue': targetValue,
      'rewardBadgeId': rewardBadgeId.trim(),

      'updatedAt': FieldValue.serverTimestamp(),
    }..removeWhere((key, value) => value == null);
  }

  AdminChallengeModel copyWith({
    String? id,
    String? title,
    String? description,
    String? image,
    int? xpReward,
    DateTime? startAt,
    DateTime? endAt,
    bool? isActive,
    String? winnerType,
    String? scope,
    String? type,
    String? workoutId,
    String? metric,
    num? targetValue,
    String? rewardBadgeId,
  }) {
    return AdminChallengeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      image: image ?? this.image,
      xpReward: xpReward ?? this.xpReward,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      isActive: isActive ?? this.isActive,
      winnerType: winnerType ?? this.winnerType,
      scope: scope ?? this.scope,
      type: type ?? this.type,
      workoutId: workoutId ?? this.workoutId,
      metric: metric ?? this.metric,
      targetValue: targetValue ?? this.targetValue,
      rewardBadgeId: rewardBadgeId ?? this.rewardBadgeId,
    );
  }
}

// -------------------------------------------------------------
// BOTTOM SHEET FORM
// -------------------------------------------------------------

class AdminChallengeFormSheet extends StatefulWidget {
  final AdminChallengeModel? existing;
  final Future<void> Function(AdminChallengeModel model) onSaved;

  const AdminChallengeFormSheet({
    Key? key,
    this.existing,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<AdminChallengeFormSheet> createState() =>
      _AdminChallengeFormSheetState();
}

class _AdminChallengeFormSheetState
    extends State<AdminChallengeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _imageCtrl;
  late TextEditingController _xpCtrl;
  late TextEditingController _workoutIdCtrl;
  late TextEditingController _targetCtrl;
  late TextEditingController _rewardBadgeCtrl;

  DateTime? _startAt;
  DateTime? _endAt;
  bool _isActive = true;
  String _winnerType = 'xp';
  String _type = 'generic';
  String _metric = 'xp';

  bool _isSaving = false;

  final Color _sheetBg = const Color(0xFF141416);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _imageCtrl = TextEditingController(text: e?.image ?? '');
    _xpCtrl = TextEditingController(
      text: e != null ? e.xpReward.toString() : '50',
    );
    _workoutIdCtrl = TextEditingController(text: e?.workoutId ?? '');
    _startAt = e?.startAt;
    _endAt = e?.endAt;
    _isActive = e?.isActive ?? true;
    _winnerType = e?.winnerType ?? 'xp';
    _type = e?.type ?? 'generic';
    _metric = e?.metric ?? 'xp';
    _targetCtrl = TextEditingController(
      text: e != null ? e.targetValue.toString() : '100',
    );
    _rewardBadgeCtrl = TextEditingController(
      text: e?.rewardBadgeId ?? '',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _imageCtrl.dispose();
    _xpCtrl.dispose();
    _workoutIdCtrl.dispose();
    _targetCtrl.dispose();
    _rewardBadgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startAt : _endAt) ?? DateTime.now();
    final first = DateTime.now().subtract(const Duration(days: 365));
    final last = DateTime.now().add(const Duration(days: 365 * 3));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00E676),
              surface: Color(0xFF1C1D20),
              onSurface: Colors.white,
              onPrimary: Colors.black,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startAt = picked;
        } else {
          _endAt = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final xp = int.tryParse(_xpCtrl.text.trim()) ?? 0;
    final workoutId = _type == 'workout' ? _workoutIdCtrl.text.trim() : '';
    final target = num.tryParse(_targetCtrl.text.trim()) ?? 0;

    final model = AdminChallengeModel(
      id: widget.existing?.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      image: _imageCtrl.text.trim(),
      xpReward: xp,
      startAt: _startAt,
      endAt: _endAt,
      isActive: _isActive,
      winnerType: _winnerType,
      scope: 'global',
      type: _type,
      workoutId: workoutId,
      metric: _metric,
      targetValue: target,
      rewardBadgeId: _rewardBadgeCtrl.text.trim(),
    );

    setState(() => _isSaving = true);
    try {
      await widget.onSaved(model);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.existing != null;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(
        bottom: bottomInset,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEdit ? 'Edit Challenge' : 'Create New Challenge',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _textField(
                          label: 'Title',
                          controller: _titleCtrl,
                          hint: '30-Day Fat Loss Challenge',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Title is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        _textField(
                          label: 'Description',
                          controller: _descCtrl,
                          hint:
                          'Explain the challenge rules, requirements and goals.',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 10),
                        _textField(
                          label: 'Banner Image URL (optional)',
                          controller: _imageCtrl,
                          hint: 'https://...',
                        ),
                        const SizedBox(height: 10),
                        _textField(
                          label: 'XP Reward for Completion',
                          controller: _xpCtrl,
                          hint: 'e.g. 100',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'XP is required';
                            }
                            final val = int.tryParse(v.trim());
                            if (val == null || val <= 0) {
                              return 'Enter a positive number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _dateField(
                                label: 'Start date',
                                value: _startAt,
                                onTap: () => _pickDate(isStart: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _dateField(
                                label: 'End date',
                                value: _endAt,
                                onTap: () => _pickDate(isStart: false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _winnerType,
                                dropdownColor: _sheetBg,
                                decoration: _inputDecoration(
                                  label: 'Winner type',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'xp', child: Text('XP')),
                                  DropdownMenuItem(
                                      value: 'steps',
                                      child: Text('Steps / Distance')),
                                  DropdownMenuItem(
                                      value: 'streak',
                                      child: Text('Streak')),
                                  DropdownMenuItem(
                                      value: 'custom',
                                      child: Text('Custom logic')),
                                ],
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() => _winnerType = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _type,
                                dropdownColor: _sheetBg,
                                decoration: _inputDecoration(
                                  label: 'Challenge type',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'generic',
                                      child: Text('Generic')),
                                  DropdownMenuItem(
                                      value: 'workout',
                                      child: Text('Workout')),
                                  DropdownMenuItem(
                                      value: 'referral',
                                      child: Text('Referral')),
                                ],
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() => _type = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Metric + target
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _metric,
                                dropdownColor: _sheetBg,
                                decoration: _inputDecoration(
                                  label: 'Metric',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'xp',
                                      child: Text('XP earned')),
                                  DropdownMenuItem(
                                      value: 'workout',
                                      child: Text('Workout count')),
                                  DropdownMenuItem(
                                      value: 'referral',
                                      child: Text('Referrals')),
                                  DropdownMenuItem(
                                      value: 'visit',
                                      child: Text('Gym visits')),
                                  DropdownMenuItem(
                                      value: 'promo',
                                      child: Text('Promotion tasks')),
                                ],
                                onChanged: (val) {
                                  if (val == null) return;
                                  setState(() => _metric = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _textField(
                                label: 'Target value',
                                controller: _targetCtrl,
                                hint: 'e.g. 500 XP or 10 workouts',
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Target is required';
                                  }
                                  final val = num.tryParse(v.trim());
                                  if (val == null || val <= 0) {
                                    return 'Enter positive number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_type == 'workout')
                          _textField(
                            label: 'Workout ID (for workout challenge)',
                            controller: _workoutIdCtrl,
                            hint: 'e.g. CHEST_DAY_A',
                            validator: (v) {
                              if (_type != 'workout') return null;
                              if (v == null || v.trim().isEmpty) {
                                return 'Workout ID is required';
                              }
                              return null;
                            },
                          ),
                        if (_type == 'workout') const SizedBox(height: 12),
                        _textField(
                          label: 'Reward badge ID (optional)',
                          controller: _rewardBadgeCtrl,
                          hint: 'e.g. BEAST_MODE_30',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SwitchListTile(
                                value: _isActive,
                                onChanged: (v) =>
                                    setState(() => _isActive = v),
                                title: Text(
                                  'Active',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70, fontSize: 13),
                                ),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                activeColor: const Color(0xFF00E676),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E676),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                AlwaysStoppedAnimation<Color>(
                                    Colors.black),
                              ),
                            )
                                : Text(
                              isEdit
                                  ? 'Save Changes'
                                  : 'Create Challenge',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.poppins(
        color: Colors.white70,
        fontSize: 12,
      ),
      hintStyle: GoogleFonts.poppins(
        color: Colors.white38,
        fontSize: 12,
      ),
      filled: true,
      fillColor: const Color(0xFF1B1C20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00E676)),
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: _inputDecoration(label: label, hint: hint),
      validator: validator,
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration(label: label),
        child: Text(
          value != null
              ? DateFormat('dd MMM yyyy').format(value)
              : 'Select',
          style: GoogleFonts.poppins(
            color: value != null ? Colors.white : Colors.white38,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
