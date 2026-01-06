import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/app_theme.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({Key? key}) : super(key: key);

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? _gymId;

  late TabController _tabController;
  int _currentTabIndex = 0;

  // Search and Filters
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _selectedLevel = 'all';
  String _selectedDay = 'all';
  String _selectedStatus = 'all';

  // Calendar
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDate;
  final List<String> _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Filter Options
  final List<String> _categories = [
    'all', 'yoga', 'hiit', 'strength', 'cardio', 'dance',
    'martial_arts', 'senior', 'pilates', 'cycling', 'boxing', 'swimming'
  ];

  final List<String> _levels = ['all', 'beginner', 'intermediate', 'advanced', 'expert'];
  final List<String> _statuses = ['all', 'active', 'inactive', 'full', 'cancelled'];

  // Data
  List<Map<String, dynamic>> _trainers = [];
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _classTemplates = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _selectedDate = _focusedDay;
    _loadGymIdAndData();
    _initializeRooms();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.index != _currentTabIndex) {
      setState(() => _currentTabIndex = _tabController.index);
    }
  }

  // =========================== DATA MANAGEMENT ===========================
  Future<void> _loadGymIdAndData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final gymSnap = await _firestore
        .collection('gyms')
        .where('ownerId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (gymSnap.docs.isEmpty) return;

    setState(() => _gymId = gymSnap.docs.first.id);
    _loadTrainers();
    _loadClassTemplates();
  }

  Future<void> _loadTrainers() async {
    if (_gymId == null) return;

    final trainerSnap = await _firestore
        .collection('gyms/$_gymId/staff')
        .where('role', whereIn: ['trainer', 'manager', 'instructor'])
        .get();

    setState(() {
      _trainers = trainerSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Trainer',
          'specialty': data['specialization'] ?? data['specialty'] ?? 'Fitness',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'rate': data['hourlyRate'] ?? 0.0,
          'image': data['profileImage'] ?? '',
        };
      }).toList();
    });
  }

  void _initializeRooms() {
    _rooms = [
      {'id': 'room1', 'name': 'Main Studio', 'capacity': 30, 'equipment': 'Mats, Weights'},
      {'id': 'room2', 'name': 'Yoga Room', 'capacity': 20, 'equipment': 'Mats, Blocks'},
      {'id': 'room3', 'name': 'Cycling Studio', 'capacity': 25, 'equipment': 'Bikes'},
      {'id': 'room4', 'name': 'Boxing Area', 'capacity': 15, 'equipment': 'Bags, Gloves'},
      {'id': 'room5', 'name': 'Pool Area', 'capacity': 10, 'equipment': 'Swim Gear'},
    ];
  }

  Future<void> _loadClassTemplates() async {
    if (_gymId == null) return;

    final templatesSnap = await _firestore
        .collection('gyms/$_gymId/class_templates')
        .get();

    setState(() {
      _classTemplates = templatesSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'category': data['category'],
          'level': data['level'],
          'duration': data['duration'],
          'color': data['color'],
          'description': data['description'],
        };
      }).toList();
    });
  }

  Future<void> _saveAsTemplate(Map<String, dynamic> classData) async {
    if (_gymId == null) return;

    final template = {
      'name': classData['className'],
      'category': classData['category'],
      'level': classData['level'],
      'duration': classData['duration'],
      'color': classData['color'],
      'description': classData['description'],
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('gyms/$_gymId/class_templates').add(template);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "${classData['className']}" as template'), backgroundColor: AppTheme.fitnessgreen),
      );
    }
  }

  // =========================== STREAMS ===========================
  Stream<QuerySnapshot> _classesStream() {
    if (_gymId == null) return const Stream.empty();
    return _firestore
        .collection('gyms/$_gymId/classes')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _classBookingsStream(String classId) {
    if (_gymId == null) return const Stream.empty();
    return _firestore
        .collection('gyms/$_gymId/classes/$classId/bookings')
        .orderBy('bookedAt', descending: true)
        .snapshots();
  }

  // =========================== UTILITY METHODS ===========================
  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) hexColor = "FF$hexColor";
    if (hexColor.length == 8) {
      return Color(int.parse("0x$hexColor"));
    }
    return const Color(0xFF4CAF50);
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'yoga': return 'Yoga';
      case 'hiit': return 'HIIT';
      case 'strength': return 'Strength Training';
      case 'cardio': return 'Cardio';
      case 'dance': return 'Dance';
      case 'martial_arts': return 'Martial Arts';
      case 'senior': return 'Senior Fitness';
      case 'pilates': return 'Pilates';
      case 'cycling': return 'Cycling';
      case 'boxing': return 'Boxing';
      case 'swimming': return 'Swimming';
      default: return category.split('_').map((e) => e[0].toUpperCase() + e.substring(1)).join(' ');
    }
  }

  String _getLevelDisplayName(String level) {
    switch (level) {
      case 'beginner': return 'Beginner';
      case 'intermediate': return 'Intermediate';
      case 'advanced': return 'Advanced';
      case 'expert': return 'Expert';
      default: return level[0].toUpperCase() + level.substring(1);
    }
  }

  // =========================== FILTERING ===========================
  List<Map<String, dynamic>> _filterClasses(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).where((c) {
      final name = (c['className'] ?? '').toString().toLowerCase();
      final trainer = (c['trainer'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      final matchesSearch = query.isEmpty || name.contains(query) || trainer.contains(query);
      final matchesCategory = _selectedCategory == 'all' || c['category'] == _selectedCategory;
      final matchesLevel = _selectedLevel == 'all' || c['level'] == _selectedLevel;
      final matchesDay = _selectedDay == 'all' || (c['days'] as List<dynamic>?)?.contains(_selectedDay) == true;
      final matchesStatus = _selectedStatus == 'all' || _getClassStatus(c) == _selectedStatus;

      return matchesSearch && matchesCategory && matchesLevel && matchesDay && matchesStatus;
    }).toList();
  }

  String _getClassStatus(Map<String, dynamic> classData) {
    final participants = classData['participants'] as int? ?? 0;
    final capacity = classData['capacity'] as int? ?? 20;
    final isActive = classData['isActive'] as bool? ?? true;
    final isCancelled = classData['isCancelled'] as bool? ?? false;

    if (isCancelled) return 'cancelled';
    if (!isActive) return 'inactive';
    if (participants >= capacity) return 'full';
    return 'active';
  }

  // =========================== ANALYTICS ===========================
  Map<String, dynamic> _calculateAnalytics(List<Map<String, dynamic>> classes) {
    if (classes.isEmpty) {
      return {
        'totalClasses': 0,
        'totalCapacity': 0,
        'totalParticipants': 0,
        'totalRevenue': 0.0,
        'avgOccupancy': 0.0,
        'mostPopularCategory': 'None',
        'mostPopularTrainer': 'None',
        'classesByDay': <String, int>{'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0},
        'classesByCategory': <String, int>{},
        'classesByTrainer': <String, int>{},
        'revenueByCategory': <String, double>{},
      };
    }

    int totalClasses = classes.length;
    int totalCapacity = 0;
    int totalParticipants = 0;
    double totalRevenue = 0.0;

    final dayCount = <String, int>{'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0};
    final categoryCount = <String, int>{};
    final trainerCount = <String, int>{};
    final revenueByCategory = <String, double>{};

    for (var c in classes) {
      final cap = c['capacity'] as int? ?? 20;
      final part = c['participants'] as int? ?? 0;
      final price = (c['price'] as num?)?.toDouble() ?? 0.0;

      totalCapacity += cap;
      totalParticipants += part;
      totalRevenue += part * price;

      final days = c['days'] as List<dynamic>? ?? [];
      for (var d in days) {
        final dayStr = d.toString();
        if (dayCount.containsKey(dayStr)) {
          dayCount[dayStr] = (dayCount[dayStr] ?? 0) + 1;
        }
      }

      final cat = c['category']?.toString() ?? 'unknown';
      categoryCount[cat] = (categoryCount[cat] ?? 0) + 1;
      revenueByCategory[cat] = (revenueByCategory[cat] ?? 0.0) + (part * price);

      final trainer = c['trainer']?.toString() ?? 'Unknown';
      trainerCount[trainer] = (trainerCount[trainer] ?? 0) + 1;
    }

    final avgOccupancy = totalCapacity > 0 ? (totalParticipants / totalCapacity) * 100 : 0.0;

    // Find top category without using reduce
    String topCategory = 'None';
    int maxCategoryCount = 0;
    for (final entry in categoryCount.entries) {
      if (entry.value > maxCategoryCount) {
        maxCategoryCount = entry.value;
        topCategory = entry.key;
      }
    }

    // Find top trainer without using reduce
    String topTrainer = 'None';
    int maxTrainerCount = 0;
    for (final entry in trainerCount.entries) {
      if (entry.value > maxTrainerCount) {
        maxTrainerCount = entry.value;
        topTrainer = entry.key;
      }
    }

    return {
      'totalClasses': totalClasses,
      'totalCapacity': totalCapacity,
      'totalParticipants': totalParticipants,
      'totalRevenue': totalRevenue,
      'avgOccupancy': avgOccupancy,
      'mostPopularCategory': _getCategoryDisplayName(topCategory),
      'mostPopularTrainer': topTrainer,
      'classesByDay': dayCount,
      'classesByCategory': categoryCount,
      'classesByTrainer': trainerCount,
      'revenueByCategory': revenueByCategory,
    };
  }

  // =========================== UI COMPONENTS ===========================
  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 20,
                fontWeight: FontWeight.bold
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsView(List<Map<String, dynamic>> classes) {
    final analytics = _calculateAnalytics(classes);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              _buildAnalyticsCard('Total Classes', '${analytics['totalClasses']}', Icons.class_, AppTheme.primaryGreen),
              _buildAnalyticsCard('Total Revenue', '\$${analytics['totalRevenue'].toStringAsFixed(2)}', Icons.attach_money, Colors.amber),
              _buildAnalyticsCard('Avg Occupancy', '${analytics['avgOccupancy'].toStringAsFixed(1)}%', Icons.trending_up, Colors.cyan),
              _buildAnalyticsCard('Participants', '${analytics['totalParticipants']}', Icons.people, Colors.blue),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Top Performers',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyticsCard(
                          'Popular Category',
                          analytics['mostPopularCategory'],
                          Icons.category,
                          Colors.purple
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAnalyticsCard(
                          'Top Trainer',
                          analytics['mostPopularTrainer'],
                          Icons.star,
                          Colors.orange
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Classes by Day',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildDayProgressBars(analytics['classesByDay']),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revenue by Category',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildRevenueProgressBars(analytics['revenueByCategory']),
              ],
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

// Helper method to build day progress bars without reduce issues
  List<Widget> _buildDayProgressBars(Map<String, dynamic> classesByDay) {
    final dayEntries = classesByDay.entries.toList();
    if (dayEntries.isEmpty) return [const Text('No data available')];

    // Find max count without using reduce
    int maxCount = 0;
    for (final entry in dayEntries) {
      final count = (entry.value as num).toInt();
      if (count > maxCount) maxCount = count;
    }

    return dayEntries.map<Widget>((entry) {
      final day = entry.key;
      final count = (entry.value as num).toInt();
      final percentage = maxCount > 0 ? count / maxCount : 0.0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                  day,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[800],
                color: AppTheme.primaryGreen,
                minHeight: 6,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      );
    }).toList();
  }

// Helper method to build revenue progress bars without reduce issues
  List<Widget> _buildRevenueProgressBars(Map<String, dynamic> revenueByCategory) {
    final revenueEntries = revenueByCategory.entries.toList();
    if (revenueEntries.isEmpty) return [const Text('No data available')];

    // Find max revenue without using reduce
    double maxRevenue = 0.0;
    for (final entry in revenueEntries) {
      final revenue = (entry.value as num).toDouble();
      if (revenue > maxRevenue) maxRevenue = revenue;
    }

    return revenueEntries.map<Widget>((entry) {
      final category = entry.key;
      final revenue = (entry.value as num).toDouble();
      final percentage = maxRevenue > 0 ? revenue / maxRevenue : 0.0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                _getCategoryDisplayName(category),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[800],
                color: Colors.amber,
                minHeight: 6,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${revenue.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildClassCard(Map<String, dynamic> c) {
    final color = _getColorFromHex(c['color'] ?? '#FFFF6B35');
    final participants = c['participants'] as int? ?? 0;
    final capacity = c['capacity'] as int? ?? 20;
    final waitlist = c['waitlist'] as int? ?? 0;
    final progress = capacity > 0 ? participants / capacity : 0.0;
    final isFull = participants >= capacity;
    final status = _getClassStatus(c);

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(Icons.fitness_center, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                c['className'] ?? '',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusBadge(status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${c['time']} • ${c['trainer']}',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    _getLevelDisplayName(c['level']),
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    _getCategoryDisplayName(c['category']),
                    style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    children: (c['days'] as List? ?? []).map<Widget>((d) =>
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            d,
                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        )
                    ).toList(),
                  ),
                ),
                Text(
                  isFull ? 'FULL' : '$participants/$capacity',
                  style: TextStyle(
                      color: isFull ? AppTheme.primaryGreen : Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600
                  ),
                ),
                if (waitlist > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '+$waitlist',
                      style: const TextStyle(color: Colors.orange, fontSize: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 6,
              decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(3)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                      color: isFull ? Colors.orange : color,
                      borderRadius: BorderRadius.circular(3)
                  ),
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showClassDetails(c),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'active':
        color = AppTheme.fitnessgreen;
        text = 'Active';
        break;
      case 'full':
        color = Colors.orange;
        text = 'Full';
        break;
      case 'inactive':
        color = Colors.grey;
        text = 'Inactive';
        break;
      case 'cancelled':
        color = AppTheme.alertRed;
        text = 'Cancelled';
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  // =========================== CLASS MANAGEMENT ===========================
  void _showAddClassDialog() {
    if (_trainers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one trainer first'), backgroundColor: AppTheme.alertRed),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '20');
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0.0');
    final durationCtrl = TextEditingController(text: '60');

    List<String> selectedDays = ['Mon', 'Wed', 'Fri'];
    String selectedCategory = 'yoga';
    String selectedLevel = 'beginner';
    String selectedTrainerId = _trainers.first['id'];
    String selectedRoom = _rooms.first['id'];
    bool bookingRequired = true;
    bool isActive = true;
    String cancellationPolicy = '24 hours';
    Color selectedColor = const Color(0xFF4CAF50);

    final colorOptions = [
      const Color(0xFF4CAF50), const Color(0xFF2196F3), const Color(0xFFFF9800),
      const Color(0xFF9C27B0), const Color(0xFFF44336), const Color(0xFF607D8B),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => Container(
          height: MediaQuery.of(context).size.height * 0.95,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: 60, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 18),
                Text(
                  'Create New Class',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 18),

                // Class Name
                _buildFormField(controller: nameCtrl, label: 'Class Name', hint: 'Morning Yoga'),
                const SizedBox(height: 14),

                // Trainer Selection
                _buildDropdownField(
                  value: selectedTrainerId,
                  label: 'Trainer',
                  items: _trainers.map((t) => t['id'] as String).toList(),
                  displayItems: _trainers.map((t) => t['name'] as String).toList(),
                  onChanged: (v) => setStateDialog(() => selectedTrainerId = v!),
                ),
                const SizedBox(height: 14),

                // Time and Duration
                Row(
                  children: [
                    Expanded(child: _buildFormField(controller: timeCtrl, label: 'Time', hint: '7:00 AM - 8:00 AM')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildFormField(controller: durationCtrl, label: 'Duration (min)', hint: '60', keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 14),

                // Category and Level
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                        value: selectedCategory,
                        label: 'Category',
                        items: _categories.where((c) => c != 'all').toList(),
                        displayItems: _categories.where((c) => c != 'all').map(_getCategoryDisplayName).toList(),
                        onChanged: (v) => setStateDialog(() => selectedCategory = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdownField(
                        value: selectedLevel,
                        label: 'Level',
                        items: _levels.where((l) => l != 'all').toList(),
                        displayItems: _levels.where((l) => l != 'all').map(_getLevelDisplayName).toList(),
                        onChanged: (v) => setStateDialog(() => selectedLevel = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Capacity and Price
                Row(
                  children: [
                    Expanded(child: _buildFormField(controller: capacityCtrl, label: 'Capacity', hint: '20', keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildFormField(controller: priceCtrl, label: 'Price (\$)', hint: '15.00', keyboardType: TextInputType.numberWithOptions(decimal: true))),
                  ],
                ),
                const SizedBox(height: 14),

                // Room Selection - IMPROVED UI
                _buildRoomSelector(selectedRoom, (v) => setStateDialog(() => selectedRoom = v!)),
                const SizedBox(height: 14),

                // Description
                _buildFormField(controller: descCtrl, label: 'Description', hint: 'Enter description...', maxLines: 3),
                const SizedBox(height: 18),

                // Days Selection
                _buildDaysSelector(_weekDays, selectedDays, (day) => setStateDialog(() {
                  if (selectedDays.contains(day)) {
                    selectedDays.remove(day);
                  } else {
                    selectedDays.add(day);
                  }
                })),
                const SizedBox(height: 18),

                // Color Selection
                _buildColorSelector(colorOptions, selectedColor, (c) => setStateDialog(() => selectedColor = c)),
                const SizedBox(height: 18),

                // Toggles
                _buildToggleRow(label: 'Booking Required', value: bookingRequired, onChanged: (v) => setStateDialog(() => bookingRequired = v)),
                const SizedBox(height: 12),
                _buildToggleRow(label: 'Active Class', value: isActive, onChanged: (v) => setStateDialog(() => isActive = v)),
                const SizedBox(height: 12),

                // Cancellation Policy
                _buildDropdownField(
                  value: cancellationPolicy,
                  label: 'Cancellation Policy',
                  items: const ['Flexible', '6 hours', '12 hours', '24 hours', '48 hours'],
                  displayItems: const ['Flexible', '6 hours', '12 hours', '24 hours', '48 hours'],
                  onChanged: (v) => setStateDialog(() => cancellationPolicy = v!),
                ),
                const SizedBox(height: 26),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[300],
                            side: BorderSide(color: Colors.grey[700]!)
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty || selectedDays.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fill required fields'), backgroundColor: AppTheme.alertRed),
                            );
                            return;
                          }

                          final selectedTrainer = _trainers.firstWhere((t) => t['id'] == selectedTrainerId);
                          final selectedRoomData = _rooms.firstWhere((r) => r['id'] == selectedRoom);

                          final data = {
                            'className': nameCtrl.text.trim(),
                            'trainer': selectedTrainer['name'],
                            'trainerId': selectedTrainerId,
                            'time': timeCtrl.text.trim(),
                            'days': selectedDays,
                            'capacity': int.tryParse(capacityCtrl.text) ?? 20,
                            'participants': 0,
                            'waitlist': 0,
                            'color': '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                            'description': descCtrl.text.trim(),
                            'category': selectedCategory,
                            'level': selectedLevel,
                            'duration': int.tryParse(durationCtrl.text) ?? 60,
                            'price': double.tryParse(priceCtrl.text) ?? 0.0,
                            'room': selectedRoomData['name'],
                            'roomId': selectedRoom,
                            'bookingRequired': bookingRequired,
                            'cancellationPolicy': cancellationPolicy,
                            'isActive': isActive,
                            'isCancelled': false,
                            'createdAt': FieldValue.serverTimestamp(),
                          };

                          try {
                            await _firestore.collection('gyms/$_gymId/classes').add(data);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Class created!'), backgroundColor: AppTheme.fitnessgreen),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to create class'), backgroundColor: AppTheme.alertRed),
                              );
                            }
                          }
                        },
                        child: const Text('Create Class', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // IMPROVED: Better room selector UI
  Widget _buildRoomSelector(String selectedRoom, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Room',
          style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
              fontSize: 14
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: selectedRoom,
            dropdownColor: Theme.of(context).cardColor,
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: _rooms.map<DropdownMenuItem<String>>((room) {
              return DropdownMenuItem<String>(
                value: room['id'] as String,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      room['name'] as String,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Capacity: ${room['capacity']} • ${room['equipment']}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _showEditClassDialog(Map<String, dynamic> classData) {
    final nameCtrl = TextEditingController(text: classData['className']);
    final timeCtrl = TextEditingController(text: classData['time']);
    final capacityCtrl = TextEditingController(text: (classData['capacity'] ?? 20).toString());
    final descCtrl = TextEditingController(text: classData['description'] ?? '');
    final priceCtrl = TextEditingController(text: (classData['price'] ?? 0.0).toString());
    final durationCtrl = TextEditingController(text: (classData['duration'] ?? 60).toString());

    List<String> selectedDays = List.from(classData['days'] ?? ['Mon', 'Wed', 'Fri']);
    String selectedCategory = classData['category'] ?? 'yoga';
    String selectedLevel = classData['level'] ?? 'beginner';
    String selectedTrainerId = classData['trainerId'] ?? (_trainers.isNotEmpty ? _trainers.first['id'] : '');
    String selectedRoom = classData['roomId'] ?? (_rooms.isNotEmpty ? _rooms.first['id'] : '');
    bool bookingRequired = classData['bookingRequired'] ?? true;
    bool isActive = classData['isActive'] ?? true;
    String cancellationPolicy = classData['cancellationPolicy'] ?? '24 hours';
    Color selectedColor = _getColorFromHex(classData['color'] ?? '#FFFF6B35');

    final colorOptions = [
      const Color(0xFF4CAF50), const Color(0xFF2196F3), const Color(0xFFFF9800),
      const Color(0xFF9C27B0), const Color(0xFFF44336), const Color(0xFF607D8B),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => Container(
          height: MediaQuery.of(context).size.height * 0.95,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: 60, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 18),
                Text(
                  'Edit Class',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold
                  ),
                ),
                const SizedBox(height: 18),

                // Class Name
                _buildFormField(controller: nameCtrl, label: 'Class Name', hint: 'Morning Yoga'),
                const SizedBox(height: 14),

                // Trainer Selection
                _buildDropdownField(
                  value: selectedTrainerId,
                  label: 'Trainer',
                  items: _trainers.map((t) => t['id'] as String).toList(),
                  displayItems: _trainers.map((t) => t['name'] as String).toList(),
                  onChanged: (v) => setStateDialog(() => selectedTrainerId = v!),
                ),
                const SizedBox(height: 14),

                // Time and Duration
                Row(
                  children: [
                    Expanded(child: _buildFormField(controller: timeCtrl, label: 'Time', hint: '7:00 AM - 8:00 AM')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildFormField(controller: durationCtrl, label: 'Duration (min)', hint: '60', keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 14),

                // Category and Level
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                        value: selectedCategory,
                        label: 'Category',
                        items: _categories.where((c) => c != 'all').toList(),
                        displayItems: _categories.where((c) => c != 'all').map(_getCategoryDisplayName).toList(),
                        onChanged: (v) => setStateDialog(() => selectedCategory = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdownField(
                        value: selectedLevel,
                        label: 'Level',
                        items: _levels.where((l) => l != 'all').toList(),
                        displayItems: _levels.where((l) => l != 'all').map(_getLevelDisplayName).toList(),
                        onChanged: (v) => setStateDialog(() => selectedLevel = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Capacity and Price
                Row(
                  children: [
                    Expanded(child: _buildFormField(controller: capacityCtrl, label: 'Capacity', hint: '20', keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildFormField(controller: priceCtrl, label: 'Price (\$)', hint: '15.00', keyboardType: TextInputType.numberWithOptions(decimal: true))),
                  ],
                ),
                const SizedBox(height: 14),

                // Room Selection
                _buildRoomSelector(selectedRoom, (v) => setStateDialog(() => selectedRoom = v!)),
                const SizedBox(height: 14),

                // Description
                _buildFormField(controller: descCtrl, label: 'Description', hint: 'Enter description...', maxLines: 3),
                const SizedBox(height: 18),

                // Days Selection
                _buildDaysSelector(_weekDays, selectedDays, (day) => setStateDialog(() {
                  if (selectedDays.contains(day)) {
                    selectedDays.remove(day);
                  } else {
                    selectedDays.add(day);
                  }
                })),
                const SizedBox(height: 18),

                // Color Selection
                _buildColorSelector(colorOptions, selectedColor, (c) => setStateDialog(() => selectedColor = c)),
                const SizedBox(height: 18),

                // Toggles
                _buildToggleRow(label: 'Booking Required', value: bookingRequired, onChanged: (v) => setStateDialog(() => bookingRequired = v)),
                const SizedBox(height: 12),
                _buildToggleRow(label: 'Active Class', value: isActive, onChanged: (v) => setStateDialog(() => isActive = v)),
                const SizedBox(height: 12),

                // Cancellation Policy
                _buildDropdownField(
                  value: cancellationPolicy,
                  label: 'Cancellation Policy',
                  items: const ['Flexible', '6 hours', '12 hours', '24 hours', '48 hours'],
                  displayItems: const ['Flexible', '6 hours', '12 hours', '24 hours', '48 hours'],
                  onChanged: (v) => setStateDialog(() => cancellationPolicy = v!),
                ),
                const SizedBox(height: 26),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[300],
                            side: BorderSide(color: Colors.grey[700]!)
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty || selectedDays.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fill required fields'), backgroundColor: AppTheme.alertRed),
                            );
                            return;
                          }

                          final selectedTrainer = _trainers.firstWhere((t) => t['id'] == selectedTrainerId);
                          final selectedRoomData = _rooms.firstWhere((r) => r['id'] == selectedRoom);

                          final data = {
                            'className': nameCtrl.text.trim(),
                            'trainer': selectedTrainer['name'],
                            'trainerId': selectedTrainerId,
                            'time': timeCtrl.text.trim(),
                            'days': selectedDays,
                            'capacity': int.tryParse(capacityCtrl.text) ?? 20,
                            'color': '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                            'description': descCtrl.text.trim(),
                            'category': selectedCategory,
                            'level': selectedLevel,
                            'duration': int.tryParse(durationCtrl.text) ?? 60,
                            'price': double.tryParse(priceCtrl.text) ?? 0.0,
                            'room': selectedRoomData['name'],
                            'roomId': selectedRoom,
                            'bookingRequired': bookingRequired,
                            'cancellationPolicy': cancellationPolicy,
                            'isActive': isActive,
                            'updatedAt': FieldValue.serverTimestamp(),
                          };

                          try {
                            await _firestore.collection('gyms/$_gymId/classes').doc(classData['id']).update(data);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Class updated!'), backgroundColor: AppTheme.fitnessgreen),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to update class'), backgroundColor: AppTheme.alertRed),
                              );
                            }
                          }
                        },
                        child: const Text('Update Class', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClassDetails(Map<String, dynamic> classData) {
    final color = _getColorFromHex(classData['color'] ?? '#FFFF6B35');
    final participants = classData['participants'] as int? ?? 0;
    final capacity = classData['capacity'] as int? ?? 20;
    final waitlist = classData['waitlist'] as int? ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 60, height: 4,
              decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                          child: Icon(Icons.fitness_center, color: color, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                classData['className'] ?? '',
                                style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold
                                ),
                              ),
                              Text(
                                'Trainer: ${classData['trainer']}',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                              const SizedBox(height: 4),
                              _buildStatusBadge(_getClassStatus(classData)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(child: _buildInfoCard('Capacity', '$participants/$capacity', Icons.people, color)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInfoCard('Waitlist', '$waitlist', Icons.list_alt, Colors.orange)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInfoCard('Duration', '${classData['duration'] ?? 60} min', Icons.timer, color)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInfoCard('Price', '\$${classData['price']?.toStringAsFixed(2) ?? '0.00'}', Icons.attach_money, AppTheme.primaryGreen)),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Class Details
                    _buildDetailRow('Category', _getCategoryDisplayName(classData['category'])),
                    _buildDetailRow('Level', _getLevelDisplayName(classData['level'])),
                    _buildDetailRow('Room', classData['room'] ?? 'Not specified'),
                    _buildDetailRow('Time', classData['time'] ?? 'Not specified'),
                    _buildDetailRow('Days', (classData['days'] as List?)?.join(', ') ?? 'Not specified'),
                    _buildDetailRow('Booking Required', classData['bookingRequired'] == true ? 'Yes' : 'No'),
                    _buildDetailRow('Cancellation Policy', classData['cancellationPolicy'] ?? 'Not specified'),

                    const SizedBox(height: 20),

                    // Description
                    Text(
                      'Description',
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      classData['description']?.isNotEmpty == true ? classData['description'] : 'No description provided.',
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 14,
                          height: 1.6
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Bookings Section
                    StreamBuilder<QuerySnapshot>(
                      stream: _classBookingsStream(classData['id']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final bookings = snapshot.data?.docs ?? [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bookings ($participants)',
                              style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...bookings.map((doc) {
                              final booking = doc.data() as Map<String, dynamic>;
                              return ListTile(
                                leading: CircleAvatar(child: Text((booking['memberName'] ?? 'M')[0])),
                                title: Text(booking['memberName'] ?? 'Unknown Member'),
                                subtitle: Text('Booked: ${DateFormat('MMM dd, yyyy').format((booking['bookedAt'] as Timestamp).toDate())}'),
                                trailing: booking['status'] == 'cancelled'
                                    ? const Text('Cancelled', style: TextStyle(color: Colors.red))
                                    : const Text('Confirmed', style: TextStyle(color: Colors.green)),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[400],
                        side: BorderSide(color: Colors.grey[700]!)
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDeleteClass(classData);
                    },
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        backgroundColor: Colors.red.withOpacity(0.08)
                    ),
                    child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditClassDialog(classData);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: color),
                    child: const Text('Edit Class', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12)
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 16,
                fontWeight: FontWeight.bold
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteClass(Map<String, dynamic> classData) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
            'Delete "${classData['className']}"?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        content: const Text('This action cannot be undone. All bookings for this class will also be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Delete class and its bookings
                final batch = _firestore.batch();
                batch.delete(_firestore.collection('gyms/$_gymId/classes').doc(classData['id']));

                // Delete all bookings for this class
                final bookings = await _firestore.collection('gyms/$_gymId/classes/${classData['id']}/bookings').get();
                for (final booking in bookings.docs) {
                  batch.delete(booking.reference);
                }

                await batch.commit();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('${classData['className']} deleted'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete class'), backgroundColor: AppTheme.alertRed),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // =========================== FORM WIDGETS ===========================
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
              fontSize: 14
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[500]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required List<String> items,
    required List<String> displayItems,
    required Function(String?) onChanged,
  }) {
    final safeValue = items.isEmpty ? null : (items.contains(value) ? value : items.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
              fontSize: 14
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonFormField<String>(
            value: safeValue,
            dropdownColor: Theme.of(context).cardColor,
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            decoration: const InputDecoration(border: InputBorder.none),
            items: items.asMap().entries.map((e) => DropdownMenuItem(
              value: e.value,
              child: Text(
                displayItems[e.key],
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
            )).toList(),
            onChanged: items.isEmpty ? null : onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDaysSelector(List<String> days, List<String> selected, Function(String) onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Class Days',
          style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
              fontSize: 14
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: days.map((d) {
            final active = selected.contains(d);
            return GestureDetector(
              onTap: () => onTap(d),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? AppTheme.primaryGreen : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? AppTheme.primaryGreen : Colors.grey[700]!),
                ),
                child: Text(
                  d,
                  style: TextStyle(
                      color: active ? Colors.white : Colors.grey[300],
                      fontWeight: FontWeight.w600
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildColorSelector(List<Color> colors, Color selected, Function(Color) onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Class Color',
          style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
              fontSize: 14
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((c) {
            final active = c == selected;
            return GestureDetector(
              onTap: () => onTap(c),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(color: active ? AppTheme.primaryGreen : Colors.transparent, width: 3),
                ),
                child: active ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildToggleRow({required String label, required bool value, required Function(bool) onChanged}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500
            ),
          ),
          Switch(value: value, activeColor: AppTheme.primaryGreen, onChanged: onChanged),
        ],
      ),
    );
  }

  // =========================== SEARCH AND FILTERS ===========================
  Widget _buildSearchAndFilters() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12)
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search classes...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Category', _selectedCategory, _categories, (v) => setState(() => _selectedCategory = v), _getCategoryDisplayName),
                const SizedBox(width: 8),
                _buildFilterChip('Level', _selectedLevel, _levels, (v) => setState(() => _selectedLevel = v), _getLevelDisplayName),
                const SizedBox(width: 8),
                _buildFilterChip('Day', _selectedDay, ['all', ..._weekDays], (v) => setState(() => _selectedDay = v), (v) => v == 'all' ? 'All Days' : v),
                const SizedBox(width: 8),
                _buildFilterChip('Status', _selectedStatus, _statuses, (v) => setState(() => _selectedStatus = v), (v) => v[0].toUpperCase() + v.substring(1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String selected, List<String> values, Function(String) onSelected, String Function(String) display) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: values.map((v) {
              final active = selected == v;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(display(v)),
                  selected: active,
                  onSelected: (_) => onSelected(v),
                  backgroundColor: Theme.of(context).cardColor,
                  selectedColor: AppTheme.primaryGreen,
                  labelStyle: TextStyle(color: active ? Colors.white : Colors.grey[300]),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // =========================== CALENDAR VIEW WITH TABLE_CALENDAR ===========================
  Widget _buildCalendarView(List<Map<String, dynamic>> classes) {
    // Get classes for selected date
    final classesForSelectedDate = _selectedDate != null ? _getClassesForDate(classes, _selectedDate!) : [];

    return Column(
      children: [
        // Calendar
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              defaultTextStyle: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              weekendTextStyle: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryGreen),
                borderRadius: BorderRadius.circular(8),
              ),
              formatButtonTextStyle: TextStyle(color: AppTheme.primaryGreen),
              titleTextStyle: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: Theme.of(context).iconTheme.color),
              rightChevronIcon: Icon(Icons.chevron_right, color: Theme.of(context).iconTheme.color),
            ),
          ),
        ),

        // Selected Date Classes
        Expanded(
          child: classesForSelectedDate.isEmpty
              ? _buildEmptyState('No classes on ${_selectedDate != null ? DateFormat('EEEE, MMM d').format(_selectedDate!) : 'selected day'}', Icons.event_busy)
              : ListView.builder(
            itemCount: classesForSelectedDate.length,
            itemBuilder: (_, i) => _buildClassCard(classesForSelectedDate[i]),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getClassesForDate(List<Map<String, dynamic>> classes, DateTime date) {
    final dayName = DateFormat('EEE').format(date);
    return classes.where((classData) {
      final days = classData['days'] as List<dynamic>? ?? [];
      return days.contains(dayName);
    }).toList();
  }

  // Helper function for table_calendar
  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // =========================== TEMPLATES VIEW ===========================
  Widget _buildTemplatesView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Class Templates',
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.bold
            ),
          ),
        ),
        Expanded(
          child: _classTemplates.isEmpty
              ? _buildEmptyState('No templates yet\nCreate a class and save it as template', Icons.library_books)
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _classTemplates.length,
            itemBuilder: (context, index) {
              final template = _classTemplates[index];
              final color = _getColorFromHex(template['color'] ?? '#FFFF6B35');

              return Card(
                color: Theme.of(context).cardColor,
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                    child: Icon(Icons.library_books, color: color),
                  ),
                  title: Text(
                    template['name'],
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                  subtitle: Text('${_getCategoryDisplayName(template['category'])} • ${template['duration']} min'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.play_arrow, color: AppTheme.primaryGreen),
                        onPressed: () => _createFromTemplate(template),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTemplate(template),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _createFromTemplate(Map<String, dynamic> template) {
    // Pre-fill the add class dialog with template data
    _showAddClassDialog(); // This would need modification to accept template data
  }

  void _deleteTemplate(Map<String, dynamic> template) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${template['name']}"?'),
        content: const Text('This template will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _firestore.collection('gyms/$_gymId/class_templates').doc(template['id']).delete();
              if (mounted) {
                Navigator.pop(context);
                _loadClassTemplates();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // =========================== MAIN VIEWS ===========================
  Widget _buildListView(List<Map<String, dynamic>> classes) {
    return Column(
      children: [
        _buildSearchAndFilters(),
        Expanded(
          child: classes.isEmpty
              ? _buildEmptyState('No matching classes', Icons.search_off)
              : ListView.builder(
            itemCount: classes.length,
            itemBuilder: (_, i) => _buildClassCard(classes[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Fitness Classes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? Colors.black : theme.appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'LIST', icon: Icon(Icons.list)),
            Tab(text: 'CALENDAR', icon: Icon(Icons.calendar_today)),
            Tab(text: 'ANALYTICS', icon: Icon(Icons.analytics)),
            Tab(text: 'TEMPLATES', icon: Icon(Icons.library_books)),
          ],
        ),
      ),
      body: _gymId == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : StreamBuilder<QuerySnapshot>(
        stream: _classesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState('No classes yet\nTap + to create your first class', Icons.fitness_center);
          }

          final docs = snapshot.data!.docs;
          final filtered = _filterClasses(docs);
          final allClasses = docs.map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id}).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildListView(filtered),
              _buildCalendarView(allClasses),
              _buildAnalyticsView(allClasses),
              _buildTemplatesView(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryGreen,
        onPressed: _showAddClassDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}