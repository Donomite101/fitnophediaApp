import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../routes/app_routes.dart';

class StaffTrainerDashboard extends StatefulWidget {
  const StaffTrainerDashboard({Key? key}) : super(key: key);

  @override
  State<StaffTrainerDashboard> createState() => _StaffTrainerDashboardState();
}

class _StaffTrainerDashboardState extends State<StaffTrainerDashboard> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? _gymId;
  String? _staffId;
  String? _role;
  String? _userName;
  String? _profileImageUrl;
  bool _loading = true;
  bool _attendanceMarkedToday = false;

  @override
  void initState() {
    super.initState();
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        _gymId = userData['gymId'];
        _role = userData['role'];
        _staffId = userData['staffId']; // We assume staffId is stored in users doc for staff accounts
        
        if (_gymId != null && _staffId != null) {
          final staffDoc = await _firestore
              .collection('gyms')
              .doc(_gymId)
              .collection('staff')
              .doc(_staffId)
              .get();
          
          if (staffDoc.exists) {
            final staffData = staffDoc.data()!;
            setState(() {
              _userName = staffData['name'];
              _profileImageUrl = staffData['photoUrl'];
              _loading = false;
            });
            _checkAttendance();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading staff data: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _checkAttendance() async {
    if (_gymId == null || _staffId == null) return;
    
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final attendanceDoc = await _firestore
        .collection('gyms')
        .doc(_gymId)
        .collection('staff')
        .doc(_staffId)
        .collection('attendance')
        .doc(today)
        .get();
    
    if (attendanceDoc.exists) {
      setState(() => _attendanceMarkedToday = true);
    }
  }

  Future<void> _markAttendance() async {
    if (_gymId == null || _staffId == null || _attendanceMarkedToday) return;

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    
    await _firestore
        .collection('gyms')
        .doc(_gymId)
        .collection('staff')
        .doc(_staffId)
        .collection('attendance')
        .doc(today)
        .set({
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'present',
      'date': today,
    });

    // Also update lastAttendanceDate on staff doc
    await _firestore
        .collection('gyms')
        .doc(_gymId)
        .collection('staff')
        .doc(_staffId)
        .update({'lastAttendanceDate': FieldValue.serverTimestamp()});

    setState(() => _attendanceMarkedToday = true);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance marked successfully!'), backgroundColor: AppTheme.primaryGreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAttendanceSection(isDark),
                  const SizedBox(height: 24),
                  _buildStatsSection(isDark),
                  const SizedBox(height: 24),
                  _buildQuickServices(isDark),
                  const SizedBox(height: 24),
                  if (_role == 'trainer') ...[
                    _buildSectionHeader('Today\'s Classes', () {}),
                    const SizedBox(height: 12),
                    _buildTodayClasses(isDark),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Recent Trainees', () {}),
                    const SizedBox(height: 12),
                    _buildRecentTrainees(isDark),
                  ],
                  if (_role == 'staff' || _role == 'receptionist' || _role == 'manager') ...[
                    _buildSectionHeader('Payment Overview', () {}),
                    const SizedBox(height: 12),
                    _buildPaymentOverview(isDark),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickServices(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Services',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildServiceItem('Trainee Payments', Iconsax.empty_wallet_add, Colors.blue, isDark, () {}),
            _buildServiceItem('Performance', Iconsax.chart_2, Colors.orange, isDark, () {}),
            _buildServiceItem('Leave Request', Iconsax.calendar_edit, Colors.red, isDark, () {}),
            _buildServiceItem('My Schedule', Iconsax.clock, Colors.purple, isDark, () {}),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceItem(String label, IconData icon, Color color, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: () => _showLogoutDialog(context),
          icon: const Icon(Iconsax.logout, color: Colors.white),
        ),
        IconButton(
          icon: const Icon(Iconsax.notification, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Iconsax.setting_2, color: Colors.white),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryGreen.withOpacity(0.8),
                AppTheme.primaryGreen,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Icon(Iconsax.flash, size: 150, color: Colors.white.withOpacity(0.1)),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          image: _profileImageUrl != null
                              ? DecorationImage(image: NetworkImage(_profileImageUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _profileImageUrl == null
                            ? const Icon(Iconsax.user, color: Colors.white, size: 30)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hello, ${_userName ?? 'User'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _role?.toUpperCase() ?? 'STAFF',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'ID: ${_staffId?.substring(0, 8).toUpperCase() ?? '...'}',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today\'s Attendance',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _attendanceMarkedToday ? 'Already Marked' : 'Not Marked Yet',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _attendanceMarkedToday ? AppTheme.primaryGreen : Colors.grey,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _attendanceMarkedToday ? null : _markAttendance,
            style: ElevatedButton.styleFrom(
              backgroundColor: _attendanceMarkedToday ? Colors.grey.withOpacity(0.1) : AppTheme.primaryGreen,
              foregroundColor: _attendanceMarkedToday ? Colors.grey : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_attendanceMarkedToday ? Iconsax.tick_circle : Iconsax.finger_scan, size: 18),
                const SizedBox(width: 8),
                Text(
                  _attendanceMarkedToday ? 'Done' : 'Mark',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(bool isDark) {
    final List<Map<String, dynamic>> stats = [
      {'label': 'Revenue', 'value': '₹24,500', 'icon': Iconsax.wallet_check, 'color': Colors.blue},
      {'label': 'Sessions', 'value': '42', 'icon': Iconsax.timer_1, 'color': Colors.orange},
      {'label': 'Rating', 'value': '4.9', 'icon': Iconsax.star, 'color': Colors.yellow},
      {'label': 'Members', 'value': '12', 'icon': Iconsax.people, 'color': AppTheme.primaryGreen},
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        itemBuilder: (context, index) {
          final s = stats[index];
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(s['icon'], size: 16, color: s['color']),
                    const SizedBox(width: 8),
                    Text(
                      s['label'],
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  s['value'],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: const Text('View All', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildTodayClasses(bool isDark) {
    if (_gymId == null || _staffId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('gyms')
          .doc(_gymId)
          .collection('classes')
          .where('trainerId', isEqualTo: _staffId)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Iconsax.calendar_remove, color: Colors.grey.withOpacity(0.5)),
                const SizedBox(width: 12),
                Text(
                  'No classes assigned to you today.',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['className'] ?? 'Nutrition Class';
            final time = '${data['startTime'] ?? '08:00'} - ${data['endTime'] ?? '09:00'}';
            final location = data['room'] ?? 'Studio A';
            final colorValue = data['color'] ?? Colors.blue.value;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildClassCard(isDark, title, time, location, Color(colorValue)),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildClassCard(bool isDark, String title, String time, String location, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                Text(
                  time,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              location,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTrainees(bool isDark) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 25,
                  backgroundColor: AppTheme.primaryGreen,
                  child: Icon(Iconsax.user, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Member $index',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentOverview(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildPaymentRow('Basic Salary', '₹15,000', Colors.grey),
          const Divider(height: 24),
          _buildPaymentRow('Incentives', '₹9,500', AppTheme.primaryGreen),
          const Divider(height: 24),
          _buildPaymentRow('Total Payout', '₹24,500', AppTheme.primaryGreen, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String amount, Color color, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.plusJakartaSans(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to logout from your account?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.logout();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
