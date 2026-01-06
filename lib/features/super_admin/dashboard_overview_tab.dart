import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardOverviewTab extends StatefulWidget {
  const DashboardOverviewTab({Key? key}) : super(key: key);

  @override
  State<DashboardOverviewTab> createState() => _DashboardOverviewTabState();
}

class _DashboardOverviewTabState extends State<DashboardOverviewTab> {
  int totalGyms = 0;
  int totalMembers = 0;
  int pendingApprovals = 0;
  double totalRevenue = 0.0;
  int expiredSubscriptions = 0;

  List<double> monthlyRevenue = [];
  List<String> monthLabels = [];
  Map<String, int> subscriptionCounts = {};
  List<Map<String, dynamic>> recentActivity = [];

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    // 1. Gym Owners
    _db.collection('users').where('role', isEqualTo: 'gym_owner').snapshots().listen((snapshot) {
      int pending = 0;
      for (var doc in snapshot.docs) {
        if (doc['approved'] == false) pending++;
      }
      if (mounted) {
        setState(() {
          totalGyms = snapshot.size;
          pendingApprovals = pending;
        });
      }
    });

    // 2. Members
    _db.collectionGroup('members').snapshots().listen((snapshot) {
      if (mounted) setState(() => totalMembers = snapshot.size);
    });

    // 3. Subscriptions
    _db.collection('app_subscriptions').snapshots().listen((snapshot) {
      double total = 0;
      int expiredCount = 0;
      final Map<String, int> planCounts = {};
      final Map<String, double> monthlyTotals = {};

      final now = DateTime.now();
      final last6Months = List.generate(6, (i) {
        final dt = DateTime(now.year, now.month - (5 - i), 1);
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      });

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final price = (data['price'] ?? 0).toDouble();
        final plan = (data['planName'] ?? 'Unknown').toString();
        final status = (data['status'] ?? '').toString();

        planCounts[plan] = (planCounts[plan] ?? 0) + 1;

        if (data['expiryDate'] != null) {
          final expiry = (data['expiryDate'] as Timestamp).toDate();
          if (expiry.isBefore(now)) expiredCount++;
        }

        if (status == 'active') {
          total += price;
          if (data['startDate'] != null) {
            final start = (data['startDate'] as Timestamp).toDate();
            final key = '${start.year}-${start.month.toString().padLeft(2, '0')}';
            monthlyTotals[key] = (monthlyTotals[key] ?? 0) + price;
          }
        }
      }

      final revs = last6Months.map((k) => monthlyTotals[k] ?? 0.0).toList();
      final monthNames = last6Months.map((k) {
        final parts = k.split('-');
        return _monthShort(int.parse(parts[1]));
      }).toList();

      if (mounted) {
        setState(() {
          totalRevenue = total;
          expiredSubscriptions = expiredCount;
          subscriptionCounts = planCounts;
          monthlyRevenue = revs;
          monthLabels = monthNames;
          _isLoading = false;
        });
      }
    });

    // 4. Recent Activity
    _db
        .collection('app_subscriptions')
        .orderBy('startDate', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      final activities = snapshot.docs.map((doc) {
        final data = doc.data();
        final plan = data['planName'] ?? 'Unknown';
        final price = data['price'] ?? 0;
        final ts = (data['startDate'] as Timestamp?)?.toDate();
        return {
          'title': 'New Subscription: $plan',
          'subtitle': 'Amount: ₹$price',
          'time': _timeAgo(ts),
          'type': 'subscription',
        };
      }).toList();
      if (mounted) setState(() => recentActivity = activities);
    });
  }

  String _monthShort(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[(month - 1) % 12];
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Grid
              _buildStatsGrid(constraints.maxWidth),
              const SizedBox(height: 32),

              // Charts Section
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildRevenueChartCard()),
                    const SizedBox(width: 24),
                    Expanded(flex: 1, child: _buildSubscriptionPieCard()),
                  ],
                )
              else ...[
                _buildRevenueChartCard(),
                const SizedBox(height: 24),
                _buildSubscriptionPieCard(),
              ],

              const SizedBox(height: 32),

              // Recent Activity
              _buildRecentActivitySection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(double maxWidth) {
    // Calculate card width based on available space
    // On wide screens: 4 cards per row
    // On medium screens: 2 cards per row
    // On small screens: 1 card per row
    
    int crossAxisCount = 1;
    if (maxWidth > 1100) crossAxisCount = 4;
    else if (maxWidth > 600) crossAxisCount = 2;

    final cardWidth = (maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

    final stats = [
      {'title': 'Total Gyms', 'value': '$totalGyms', 'icon': Icons.fitness_center, 'color': Colors.blue},
      {'title': 'Active Members', 'value': '$totalMembers', 'icon': Icons.people, 'color': Colors.green},
      {'title': 'Pending Approvals', 'value': '$pendingApprovals', 'icon': Icons.verified_user, 'color': Colors.orange},
      {'title': 'Total Revenue', 'value': '₹${totalRevenue.toStringAsFixed(0)}', 'icon': Icons.attach_money, 'color': Colors.purple},
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: stats.map((stat) {
        return SizedBox(
          width: cardWidth,
          child: _buildStatCard(
            stat['title'] as String,
            stat['value'] as String,
            stat['icon'] as IconData,
            stat['color'] as Color,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2B3674),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChartCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue Trend',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2B3674),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_upward, color: Colors.green, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '+2.5%',
                      style: GoogleFonts.poppins(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 300,
            child: monthlyRevenue.isEmpty
                ? Center(child: Text('No data available', style: GoogleFonts.poppins(color: Colors.grey)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1000,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.1),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < monthLabels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    monthLabels[index],
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1000,
                            reservedSize: 42,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${(value / 1000).toStringAsFixed(0)}k',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: monthlyRevenue.length.toDouble() - 1,
                      minY: 0,
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(monthlyRevenue.length, (index) {
                            return FlSpot(index.toDouble(), monthlyRevenue[index]);
                          }),
                          isCurved: true,
                          color: const Color(0xFF4318FF),
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF4318FF).withOpacity(0.2),
                                const Color(0xFF4318FF).withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPieCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan Distribution',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2B3674),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 300,
            child: subscriptionCounts.isEmpty
                ? Center(child: Text('No data available', style: GoogleFonts.poppins(color: Colors.grey)))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 70,
                      sections: _getPieSections(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getPieSections() {
    final colors = [
      const Color(0xFF4318FF),
      const Color(0xFF6AD2FF),
      const Color(0xFFEFF4FB),
      Colors.orange,
      Colors.purple,
    ];
    
    return List.generate(subscriptionCounts.length, (i) {
      final entry = subscriptionCounts.entries.elementAt(i);
      final isTouched = false; // Can add interaction later
      final fontSize = isTouched ? 25.0 : 16.0;
      final radius = isTouched ? 60.0 : 50.0;

      return PieChartSectionData(
        color: colors[i % colors.length],
        value: entry.value.toDouble(),
        title: '${entry.value}',
        radius: radius,
        titleStyle: GoogleFonts.poppins(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: const Color(0xffffffff),
        ),
      );
    });
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2B3674),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentActivity.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
            itemBuilder: (context, index) {
              final activity = recentActivity[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.subscriptions_outlined, color: Colors.blue, size: 20),
                ),
                title: Text(
                  activity['title'],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2B3674),
                  ),
                ),
                subtitle: Text(
                  activity['subtitle'],
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
                ),
                trailing: Text(
                  activity['time'],
                  style: GoogleFonts.poppins(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
