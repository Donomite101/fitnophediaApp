// Image reference (uploaded by user): /mnt/data/3da296b4-c4d9-4f7b-ac0c-8111b5d4625f.png

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/app_theme.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({Key? key}) : super(key: key);

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? _gymId;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _noticesStream;

  // Filter & Search
  String _currentFilter = 'all';
  final List<String> _filters = ['all', 'active', 'inactive', 'high', 'medium', 'low', 'archived'];
  String _searchQuery = '';

  // Selection & optimistic
  final Set<String> _selected = {};
  final Set<String> _optimisticallyArchived = {};

  @override
  void initState() {
    super.initState();
    _loadGymId();
  }

  Future<void> _loadGymId() async {
    final user = _auth.currentUser;
    if (user != null) {
      final gyms = await _firestore.collection('gyms').where('ownerId', isEqualTo: user.uid).limit(1).get();
      if (gyms.docs.isNotEmpty) {
        setState(() {
          _gymId = gyms.docs.first.id;
          _noticesStream = _firestore
              .collection('gyms')
              .doc(_gymId)
              .collection('notices')
              .orderBy('createdAt', descending: true)
              .snapshots();
        });
      }
    }
  }

  Map<String, dynamic> _mapDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return {
      'id': doc.id,
      'title': data['title'] ?? '',
      'message': data['message'] ?? '',
      'priority': data['priority'] ?? 'medium',
      'category': data['category'] ?? 'general',
      'targetAudience': data['targetAudience'] ?? ['all'],
      'startDate': data['startDate'],
      'endDate': data['endDate'],
      'createdBy': data['createdBy'] ?? 'Admin',
      'isActive': data['isActive'] ?? true,
      'createdAt': data['createdAt'],
      'views': data['views'] ?? 0,
      'acknowledgedBy': data['acknowledgedBy'] ?? [],
      'imageUrl': data['imageUrl'],
      'isRecurring': data['isRecurring'] ?? false,
      'recurringPattern': data['recurringPattern'],
      'isArchived': data['isArchived'] ?? false,
    };
  }

  /// Optimistic archive (soft-delete)
  Future<void> _archiveNotices(List<String> ids) async {
    if (_gymId == null || ids.isEmpty) return;

    setState(() {
      _optimisticallyArchived.addAll(ids);
      _selected.removeAll(ids);
    });

    final futures = ids.map((id) {
      return _firestore.collection('gyms').doc(_gymId).collection('notices').doc(id).update({
        'isArchived': true,
        'updatedAt': Timestamp.fromDate(DateTime.now())
      });
    }).toList();

    final scaffold = ScaffoldMessenger.of(context);
    scaffold.clearSnackBars();
    scaffold.showSnackBar(
      SnackBar(
        content: Text(ids.length == 1 ? 'Notice archived' : '${ids.length} notices archived'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () async {
            try {
              await Future.wait(ids.map((id) => _firestore.collection('gyms').doc(_gymId).collection('notices').doc(id).update({
                'isArchived': false,
                'updatedAt': Timestamp.fromDate(DateTime.now())
              })));
            } catch (e) {
              debugPrint('Undo archive failed: $e');
            } finally {
              setState(() {
                _optimisticallyArchived.removeAll(ids);
              });
            }
          },
        ),
        duration: const Duration(seconds: 6),
        backgroundColor: Colors.black87,
      ),
    );

    try {
      await Future.wait(futures);
      setState(() {
        _optimisticallyArchived.removeAll(ids);
      });
    } catch (e) {
      setState(() {
        _optimisticallyArchived.removeAll(ids);
      });
      scaffold.showSnackBar(SnackBar(content: Text('Error archiving: $e'), backgroundColor: AppTheme.alertRed));
    }
  }

  Future<void> _deleteNotices(List<String> ids) async {
    if (_gymId == null || ids.isEmpty) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice?'),
        content: const Text('This action cannot be undone. Are you sure you want to permanently delete this notice?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _optimisticallyArchived.addAll(ids);
      _selected.removeAll(ids);
    });

    try {
      await Future.wait(ids.map((id) => 
        _firestore.collection('gyms').doc(_gymId).collection('notices').doc(id).delete()
      ));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notice deleted'), backgroundColor: AppTheme.primaryGreen));
    } catch (e) {
      setState(() {
        _optimisticallyArchived.removeAll(ids);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.alertRed));
    }
  }

  Future<void> _restoreNotices(List<String> ids) async {
    if (_gymId == null || ids.isEmpty) return;
    try {
      await Future.wait(ids.map((id) => _firestore.collection('gyms').doc(_gymId).collection('notices').doc(id).update({
        'isArchived': false,
        'updatedAt': Timestamp.fromDate(DateTime.now())
      })));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Restored'), backgroundColor: AppTheme.primaryGreen));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.alertRed));
    }
  }

  Future<void> _toggleNoticeStatus(String id, bool status) async {
    await _firestore.collection('gyms').doc(_gymId).collection('notices').doc(id).update({
      'isActive': !status,
      'updatedAt': Timestamp.fromDate(DateTime.now())
    });
  }

  // ---------- Create / Edit dialogs ----------
  void _showAddNoticeDialog() {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String selectedPriority = 'medium';
    String selectedCategory = 'general';
    List<String> selectedAudience = ['all'];
    DateTime? startDate;
    DateTime? endDate;
    bool isRecurring = false;
    String recurringPattern = 'weekly';

    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        return SafeArea(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              Container(width: 60, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 14),
              Text('Create Notice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(children: [
                    _modernTextField(controller: titleCtrl, label: 'Title *', theme: theme),
                    const SizedBox(height: 12),
                    _modernTextField(controller: messageCtrl, label: 'Message *', maxLines: 5, theme: theme),
                    const SizedBox(height: 12),
                    // Category + Priority (now both dropdowns)
                    Row(
                      children: [
                        Expanded(child: _modernCategoryPicker(selectedCategory, (v) => setStateDialog(() => selectedCategory = v), theme)),
                        const SizedBox(width: 12),
                        Expanded(child: _modernPriorityDropdown(selectedPriority, (v) => setStateDialog(() => selectedPriority = v), theme)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildAudienceSelector(selectedAudience, (v) => setStateDialog(() {
                      if (v == 'all') {
                        selectedAudience = ['all'];
                      } else {
                        if (selectedAudience.contains('all')) selectedAudience = [v];
                        else {
                          selectedAudience.contains(v) ? selectedAudience.remove(v) : selectedAudience.add(v);
                        }
                      }
                    }), theme),
                    const SizedBox(height: 12),
                    _buildDateRangeSelector(startDate, endDate, (s, e) => setStateDialog(() {
                      startDate = s;
                      endDate = e;
                    }), theme),
                    const SizedBox(height: 12),
                    _buildRecurringSelector(isRecurring, recurringPattern, (r, p) => setStateDialog(() {
                      isRecurring = r;
                      recurringPattern = p;
                    }), theme),
                    const SizedBox(height: 18),
                  ]),
                ),
              ),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                      foregroundColor: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Please fill required fields'), backgroundColor: AppTheme.alertRed));
                        return;
                      }
                      try {
                        await _firestore.collection('gyms').doc(_gymId).collection('notices').add({
                          'title': titleCtrl.text.trim(),
                          'message': messageCtrl.text.trim(),
                          'priority': selectedPriority,
                          'category': selectedCategory,
                          'targetAudience': selectedAudience,
                          'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
                          'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
                          'isRecurring': isRecurring,
                          'recurringPattern': isRecurring ? recurringPattern : null,
                          'createdBy': _auth.currentUser?.displayName ?? 'Admin',
                          'isActive': true,
                          'views': 0,
                          'acknowledgedBy': [],
                          'createdAt': Timestamp.fromDate(DateTime.now()),
                          'isArchived': false,
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Notice created'), backgroundColor: AppTheme.primaryGreen));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.alertRed));
                      }
                    },
                    child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ])
            ]),
          ),
        );
      }),
    );
  }

  void _showEditNoticeDialog(Map<String, dynamic> notice, ThemeData theme) {
    final titleCtrl = TextEditingController(text: notice['title']);
    final messageCtrl = TextEditingController(text: notice['message']);
    String selectedPriority = notice['priority'] ?? 'medium';
    String selectedCategory = notice['category'] ?? 'general';
    List<String> selectedAudience = List<String>.from(notice['targetAudience'] ?? ['all']);
    DateTime? startDate;
    DateTime? endDate;
    if (notice['startDate'] is Timestamp) startDate = (notice['startDate'] as Timestamp).toDate();
    if (notice['endDate'] is Timestamp) endDate = (notice['endDate'] as Timestamp).toDate();
    bool isRecurring = notice['isRecurring'] ?? false;
    String recurringPattern = notice['recurringPattern'] ?? 'weekly';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        return SafeArea(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              Container(width: 60, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 14),
              Text('Edit Notice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(children: [
                    _modernTextField(controller: titleCtrl, label: 'Title *', theme: theme),
                    const SizedBox(height: 12),
                    _modernTextField(controller: messageCtrl, label: 'Message *', maxLines: 5, theme: theme),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _modernCategoryPicker(selectedCategory, (v) => setStateDialog(() => selectedCategory = v), theme)),
                        const SizedBox(width: 12),
                        Expanded(child: _modernPriorityDropdown(selectedPriority, (v) => setStateDialog(() => selectedPriority = v), theme)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildAudienceSelector(selectedAudience, (v) => setStateDialog(() {
                      if (v == 'all') {
                        selectedAudience = ['all'];
                      } else {
                        if (selectedAudience.contains('all')) selectedAudience = [v];
                        else {
                          selectedAudience.contains(v) ? selectedAudience.remove(v) : selectedAudience.add(v);
                        }
                      }
                    }), theme),
                    const SizedBox(height: 12),
                    _buildDateRangeSelector(startDate, endDate, (s, e) => setStateDialog(() {
                      startDate = s;
                      endDate = e;
                    }), theme),
                    const SizedBox(height: 12),
                    _buildRecurringSelector(isRecurring, recurringPattern, (r, p) => setStateDialog(() {
                      isRecurring = r;
                      recurringPattern = p;
                    }), theme),
                    const SizedBox(height: 18),
                  ]),
                ),
              ),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                      foregroundColor: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await _firestore.collection('gyms').doc(_gymId).collection('notices').doc(notice['id']).update({
                          'title': titleCtrl.text.trim(),
                          'message': messageCtrl.text.trim(),
                          'priority': selectedPriority,
                          'category': selectedCategory,
                          'targetAudience': selectedAudience,
                          'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
                          'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
                          'isRecurring': isRecurring,
                          'recurringPattern': isRecurring ? recurringPattern : null,
                          'updatedAt': Timestamp.fromDate(DateTime.now()),
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Updated'), backgroundColor: AppTheme.primaryGreen));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.alertRed));
                      }
                    },
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ])
            ]),
          ),
        );
      }),
    );
  }

  // NEW: Priority as Dropdown
  Widget _modernPriorityDropdown(String current, Function(String) onChanged, ThemeData theme) {
    final priorities = [
      {'value': 'low', 'label': 'Low'},
      {'value': 'medium', 'label': 'Medium'},
      {'value': 'high', 'label': 'High'},
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: current,
          items: priorities.map((p) => DropdownMenuItem(value: p['value'] as String, child: Text(p['label']!))).toList(),
          onChanged: (v) => onChanged(v ?? current),
        ),
      ),
    );
  }

  Widget _modernCategoryPicker(String current, Function(String) onChanged, ThemeData theme) {
    final categories = [
      {'value': 'general', 'label': 'General'},
      {'value': 'class', 'label': 'Class'},
      {'value': 'maintenance', 'label': 'Maint'},
      {'value': 'promotion', 'label': 'Promo'},
      {'value': 'emergency', 'label': 'Emergency'},
      {'value': 'holiday', 'label': 'Holiday'},
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(10)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: current,
          items: categories.map((c) => DropdownMenuItem(value: c['value'] as String, child: Text(c['label']!))).toList(),
          onChanged: (v) => onChanged(v ?? current),
        ),
      ),
    );
  }

  Widget _modernTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: label,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      )
    ]);
  }

  Widget _buildAudienceSelector(List<String> selected, Function(String) onChanged, ThemeData theme) {
    const audiences = [
      {'value': 'all', 'label': 'All'},
      {'value': 'premium', 'label': 'Premium'},
      {'value': 'basic', 'label': 'Basic'},
      {'value': 'trainers', 'label': 'Trainers'},
      {'value': 'staff', 'label': 'Staff'},
    ];
    return Wrap(spacing: 8, children: audiences.map((a) {
      final isSelected = selected.contains(a['value']);
      return ChoiceChip(
        label: Text(a['label']!),
        selected: isSelected,
        onSelected: (_) => onChanged(a['value']!),
        selectedColor: AppTheme.primaryGreen,
        backgroundColor: Theme.of(context).cardColor,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey[600]),
      );
    }).toList());
  }

  Widget _buildDateRangeSelector(DateTime? start, DateTime? end, Function(DateTime?, DateTime?) onChanged, ThemeData theme) {
    return Row(children: [
      Expanded(
        child: GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: start ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
            if (picked != null) onChanged(picked, end);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(start == null ? 'Start' : DateFormat('MMM dd').format(start), overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: end ?? (start ?? DateTime.now()).add(const Duration(days: 7)), firstDate: start ?? DateTime.now(), lastDate: DateTime(2100));
            if (picked != null) onChanged(start, picked);
            },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(end == null ? 'End' : DateFormat('MMM dd').format(end), overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      )
    ]);
  }

  Widget _buildRecurringSelector(bool isRecurring, String pattern, Function(bool, String) onChanged, ThemeData theme) {
    final patterns = ['daily', 'weekly', 'monthly'];
    final isDark = theme.brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Switch(value: isRecurring, onChanged: (v) => onChanged(v, pattern), activeColor: AppTheme.primaryGreen),
        const SizedBox(width: 6),
        const Text('Recurring', style: TextStyle(fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: patterns.map((p) {
        final isSelected = pattern == p && isRecurring;
        return ChoiceChip(
          selected: isSelected,
          onSelected: isRecurring ? (_) => onChanged(true, p) : null,
          label: Text(p.capitalize()),
          selectedColor: AppTheme.primaryGreen,
          backgroundColor: isDark ? const Color(0xFF111111) : Theme.of(context).cardColor,
          labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey[700])),
        );
      }).toList())
    ]);
  }

  IconData _getPriorityIcon(String p) => {'high': Icons.priority_high, 'medium': Icons.report_problem, 'low': Icons.check_circle}[p] ?? Icons.help;
  IconData _getCategoryIcon(String c) => {
    'class': Icons.fitness_center,
    'maintenance': Icons.build,
    'promotion': Icons.local_offer,
    'emergency': Icons.warning,
    'holiday': Icons.beach_access
  }[c] ?? Icons.announcement;

  Color _getPriorityColor(String p) => {'high': AppTheme.alertRed, 'medium': AppTheme.primaryGreen, 'low': AppTheme.fitnessgreen}[p] ?? AppTheme.primaryGreen;
  Color _getCategoryColor(String c) => {
    'class': AppTheme.primaryGreen,
    'maintenance': AppTheme.primaryGreen,
    'promotion': AppTheme.primaryGreen,
    'emergency': AppTheme.alertRed,
    'holiday': Colors.purple
  }[c] ?? Colors.grey;

  String _getPriorityText(String p) => {'high': 'High', 'medium': 'Medium', 'low': 'Low'}[p] ?? 'Notice';
  String _getCategoryText(String c) => {
    'class': 'Class',
    'maintenance': 'Maintenance',
    'promotion': 'Promotion',
    'emergency': 'Emergency',
    'holiday': 'Holiday'
  }[c] ?? 'General';

  Widget _statCardStyle({
    required String label,
    required String value,
    required IconData icon,
    required double size,
    double delta = 0.0,
    String deltaText = '+0.0%',
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? Colors.black : theme.scaffoldBackgroundColor;
    final valueColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? Colors.white70 : Colors.black54;

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: isDark ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Spacer(),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 18, color: AppTheme.primaryGreen),
            ),
          ]),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: valueColor)),
          const SizedBox(height: 6),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: delta >= 0 ? AppTheme.fitnessgreen.withOpacity(0.12) : AppTheme.alertRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                deltaText,
                style: TextStyle(color: delta >= 0 ? AppTheme.fitnessgreen : AppTheme.alertRed, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, color: labelColor)),
          ]),
        ]),
      ),
    );
  }

  Widget _categoryCircle(String category, ThemeData theme) {
    final color = _getCategoryColor(category);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.95), color.withOpacity(0.65)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 6))],
      ),
      child: Center(child: Icon(_getCategoryIcon(category), color: Colors.white, size: 26)),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  List<Map<String, dynamic>> _applySearchAndFilter(List<Map<String, dynamic>> list) {
    var filtered = list.where((n) {
      if (_currentFilter == 'archived') return (n['isArchived'] ?? false) == true;
      return (n['isArchived'] ?? false) == false;
    }).toList();

    switch (_currentFilter) {
      case 'active':
        filtered = filtered.where((n) => n['isActive'] == true).toList();
        break;
      case 'inactive':
        filtered = filtered.where((n) => n['isActive'] == false).toList();
        break;
      case 'high':
        filtered = filtered.where((n) => n['priority'] == 'high').toList();
        break;
      case 'medium':
        filtered = filtered.where((n) => n['priority'] == 'medium').toList();
        break;
      case 'low':
        filtered = filtered.where((n) => n['priority'] == 'low').toList();
        break;
      case 'archived':
        break;
    }

    return filtered;
  }

  void _showFilterDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Filter Notices'),
        content: SingleChildScrollView(
          child: Wrap(spacing: 8, children: _filters.map((f) {
            final isSelected = _currentFilter == f;
            return ChoiceChip(
              label: Text(f.capitalize()),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _currentFilter = f);
                Navigator.pop(context);
              },
              selectedColor: AppTheme.primaryGreen,
            );
          }).toList()),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showNoticeDetails(Map<String, dynamic> notice, ThemeData theme) {
    final hasDateRange = notice['startDate'] != null && notice['endDate'] != null;
    final start = hasDateRange && notice['startDate'] is Timestamp ? (notice['startDate'] as Timestamp).toDate() : null;
    final end = hasDateRange && notice['endDate'] is Timestamp ? (notice['endDate'] as Timestamp).toDate() : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Container(width: 60, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 12),
            Row(children: [
              _categoryCircle(notice['category'], Theme.of(context)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(notice['title'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                const SizedBox(height: 6),
                if (notice['createdAt'] is Timestamp)
                  Text('Created on ${DateFormat('MMM dd, yyyy').format((notice['createdAt'] as Timestamp).toDate())} by ${notice['createdBy']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ]))
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              _badge(_getPriorityText(notice['priority']), _getPriorityColor(notice['priority'])),
              _badge(_getCategoryText(notice['category']), _getCategoryColor(notice['category'])),
              if (notice['isRecurring']) _badge('Recurring', AppTheme.primaryGreen),
              if (notice['isArchived'] == true) _badge('Archived', Colors.grey),
            ]),
            const SizedBox(height: 12),
            if (hasDateRange)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${DateFormat('MMM dd, yyyy').format(start!)} - ${DateFormat('MMM dd, yyyy').format(end!)}')),
                ]),
              ),
            const SizedBox(height: 12),
            Expanded(child: SingleChildScrollView(child: Text(notice['message'], style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)))),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close sheet first
                    _deleteNotices([notice['id']]);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Delete'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditNoticeDialog(notice, Theme.of(context));
                  },
                  child: const Text('Edit', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                ),
              ),
            ])
          ]),
        ),
      ),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice, ThemeData theme) {
    final id = notice['id'] as String;
    if (_optimisticallyArchived.contains(id)) return const SizedBox.shrink();

    final isArchived = notice['isArchived'] == true;
    final isSelected = _selected.contains(id);
    final isActive = notice['isActive'] ?? true;
    final hasDateRange = notice['startDate'] != null && notice['endDate'] != null;
    final isRecurring = notice['isRecurring'] ?? false;

    return Material(
      color: theme.cardColor,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showNoticeDetails(notice, theme),
        onLongPress: () {
          setState(() {
            if (isSelected)
              _selected.remove(id);
            else
              _selected.add(id);
          });
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _categoryCircle(notice['category'], theme),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(notice['title'], style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (isRecurring) const SizedBox(width: 6),
                  if (isRecurring) Icon(Icons.repeat, size: 16, color: AppTheme.primaryGreen),
                ]),
                const SizedBox(height: 6),
                Text(notice['message'], style: TextStyle(color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [
                  _badge(_getPriorityText(notice['priority']), _getPriorityColor(notice['priority'])),
                  const SizedBox(width: 6),
                  _badge(_getCategoryText(notice['category']), _getCategoryColor(notice['category'])),
                  const Spacer(),
                  if (hasDateRange && notice['startDate'] is Timestamp && notice['endDate'] is Timestamp)
                    Flexible(child: Text('${DateFormat('MMM dd').format((notice['startDate'] as Timestamp).toDate())} - ${DateFormat('MMM dd').format((notice['endDate'] as Timestamp).toDate())}', style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                ])
              ]),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 36, maxWidth: 56),
              child: PopupMenuButton<int>(
                icon: Icon(Icons.more_vert, color: theme.iconTheme.color),
                onSelected: (i) async {
                  if (i == 0) _showEditNoticeDialog(notice, theme);
                  if (i == 1) await _toggleNoticeStatus(id, isActive);
                  if (i == 2) {
                    if (isArchived)
                      await _restoreNotices([id]);
                    else
                      await _archiveNotices([id]);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 0, child: Text('Edit')),
                  PopupMenuItem(value: 1, child: Text(isActive ? 'Pause' : 'Activate')),
                  PopupMenuItem(value: 2, child: Text(isArchived ? 'Restore' : 'Archive')),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ---------- Compact & Modern UI Implementation ----------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101010) : const Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          _selected.isEmpty ? 'Notices' : '${_selected.length} Selected',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20
          ),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        actions: _buildAppBarActions(context),
      ),
      body: Column(
        children: [
          // 1. Stats Row (Horizontal Scroll)
          SizedBox(
            height: 90,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _noticesStream,
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                final all = docs.map((d) => d.data()).toList();
                final total = all.length;
                final active = all.where((n) => (n['isActive'] ?? true) && (n['isArchived'] ?? false) == false).length;
                final archived = all.where((n) => (n['isArchived'] ?? false) == true).length;
                final high = all.where((n) => n['priority'] == 'high' && (n['isArchived'] ?? false) == false).length;

                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    _buildCompactStatCard('Total', '$total', Iconsax.note_text, Colors.blue),
                    const SizedBox(width: 12),
                    _buildCompactStatCard('Active', '$active', Iconsax.tick_circle, AppTheme.primaryGreen),
                    const SizedBox(width: 12),
                    _buildCompactStatCard('High Priority', '$high', Iconsax.warning_2, AppTheme.alertRed),
                    const SizedBox(width: 12),
                    _buildCompactStatCard('Archived', '$archived', Iconsax.archive, Colors.grey),
                  ],
                );
              },
            ),
          ),

          // 2. Search & Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search notices...',
                        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        prefixIcon: Icon(Iconsax.search_normal, size: 18, color: Colors.grey.shade500),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildFilterButton(),
              ],
            ),
          ),

          // 3. Compact List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _noticesStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
                }
                
                final docs = snap.data?.docs ?? [];
                final notices = docs.map(_mapDoc).toList();
                
                // Client-side search & filter
                final filtered = _applySearchAndFilter(notices);

                if (filtered.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final notice = filtered[index];
                    return _buildCompactNoticeCard(notice, isDark);
                  },
                );
              }, 
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNoticeDialog,
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Iconsax.add, color: Colors.white),
        elevation: 4,
        shape: const CircleBorder(),
      ),
    );
  }

  // --- New Compact Components ---

  List<Widget> _buildAppBarActions(BuildContext context) {
    if (_selected.isNotEmpty) {
      return [
        IconButton(
          icon: const Icon(Iconsax.archive_tick, color: Colors.grey),
          onPressed: () => _confirmArchiveSelected(),
        ),
        IconButton(
          icon: const Icon(Iconsax.close_circle, color: Colors.grey),
          onPressed: () => setState(() => _selected.clear()),
        ),
        const SizedBox(width: 8),
      ];
    }
    return [
      IconButton(
        icon: Icon(_currentFilter == 'archived' ? Iconsax.archive_1 : Iconsax.archive_add, size: 22),
        onPressed: () => setState(() => _currentFilter = _currentFilter == 'archived' ? 'all' : 'archived'),
        tooltip: 'Toggle Archives',
      ),
      const SizedBox(width: 8),
    ];
  }

  Widget _buildCompactStatCard(String label, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 125, // Compact width
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade100),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const Spacer(),
              Text(value, style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87
              )),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500
          )),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _currentFilter != 'all' && _currentFilter != 'archived';
    
    return GestureDetector(
      onTap: _showFilterDialog,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryGreen.withOpacity(0.15) : (isDark ? const Color(0xFF1F1F1F) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? AppTheme.primaryGreen.withOpacity(0.3) : (isDark ? Colors.transparent : Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Icon(Iconsax.filter, size: 18, color: isActive ? AppTheme.primaryGreen : Colors.grey.shade600),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                _currentFilter.capitalize(),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCompactNoticeCard(Map<String, dynamic> notice, bool isDark) {
    final id = notice['id'] as String;
    final priorityColor = _getPriorityColor(notice['priority']);
    final isSelected = _selected.contains(id);
    final isArchived = notice['isArchived'] == true;
    final isActive = notice['isActive'] ?? true;
    final date = notice['createdAt'] is Timestamp 
        ? DateFormat('MMM d').format((notice['createdAt'] as Timestamp).toDate()) 
        : '';
        
    if (_optimisticallyArchived.contains(id)) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _selected.isNotEmpty 
          ? setState(() => isSelected ? _selected.remove(id) : _selected.add(id))
          : _showNoticeDetails(notice, Theme.of(context)),
      onLongPress: () => setState(() => isSelected ? _selected.remove(id) : _selected.add(id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryGreen.withOpacity(0.08) 
              : (isDark ? const Color(0xFF1F1F1F) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : (isDark ? Colors.transparent : Colors.grey.shade100)
          ),
          boxShadow: isDark || isSelected ? [] : [
            BoxShadow(color: Colors.grey.shade200.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 2))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Priority Strip
                Container(width: 4, color: priorityColor.withOpacity(0.8)),
                
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                notice['title'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                  decoration: isArchived ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              date,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'Outfit'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notice['message'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            height: 1.3
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _compactBadge(
                              _getCategoryText(notice['category']),
                              isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100, 
                              isDark ? Colors.grey.shade300 : Colors.grey.shade700
                            ),
                            if (notice['isRecurring'] == true) ...[
                              const SizedBox(width: 6),
                              Icon(Iconsax.repeat, size: 14, color: Colors.grey.shade500),
                            ],
                            const Spacer(),
                            if (!isActive)
                              _compactBadge('Inactive', Colors.red.withOpacity(0.1), Colors.red)
                            else if (notice['views'] != null && notice['views'] > 0)
                              Row(
                                children: [
                                  Icon(Iconsax.eye, size: 14, color: Colors.grey.shade400),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${notice['views']}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Active/Menu Indicator
                if (!isSelected)
                  PopupMenuButton<int>(
                    icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade400),
                    padding: EdgeInsets.zero,
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (i) async {
                      if (i == 0) _showEditNoticeDialog(notice, Theme.of(context));
                      if (i == 1) await _toggleNoticeStatus(id, isActive);
                      if (i == 2) {
                        if (isArchived)
                          await _restoreNotices([id]);
                        else
                          await _archiveNotices([id]);
                      }
                      if (i == 3) await _deleteNotices([id]);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 0, child: Row(children: [Icon(Iconsax.edit, size: 16), SizedBox(width: 8), Text('Edit')])),
                      PopupMenuItem(value: 1, child: Row(children: [Icon(isActive ? Iconsax.pause : Iconsax.play, size: 16), const SizedBox(width: 8), Text(isActive ? 'Pause' : 'Activate')])),
                      PopupMenuItem(value: 2, child: Row(children: [Icon(isArchived ? Iconsax.arrow_circle_left : Iconsax.archive, size: 16), const SizedBox(width: 8), Text(isArchived ? 'Restore' : 'Archive')])),
                      const PopupMenuItem(value: 3, child: Row(children: [Icon(Iconsax.trash, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text, 
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg, fontFamily: 'Outfit'),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.clipboard_text, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No notices found',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey.shade800
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty 
              ? 'Try adjusting your search' 
              : 'Create a notice to keep members informed',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmArchiveSelected() async {
    final ids = _selected.toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog( 
        title: Text('Archive ${ids.length} items?'),
        content: const Text('These notices will be moved to the archive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
        ],
      ),
    );
    if (confirm == true) {
      await _archiveNotices(ids);
      setState(() => _selected.clear());
    }
  }

  // --- Helper Icons (Keep usage of Iconsax) ---
  // Note: Iconsax needs to be imported: import 'package:iconsax/iconsax.dart';
  // If not available, we should swap to Material icons, but assuming it is based on code base context.
}

extension StringCasing on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}