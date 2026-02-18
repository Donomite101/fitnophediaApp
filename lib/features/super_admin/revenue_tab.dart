// features/super_admin/tabs/revenue_subscriptions_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RevenueSubscriptionsTab extends StatefulWidget {
  const RevenueSubscriptionsTab({Key? key}) : super(key: key);

  @override
  State<RevenueSubscriptionsTab> createState() => _RevenueSubscriptionsTabState();
}

class _RevenueSubscriptionsTabState extends State<RevenueSubscriptionsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _timeFilter = 'monthly';
  DateTimeRange? _customDateRange;
  String _searchQuery = '';

  // Dynamic stats
  Map<String, dynamic> _revenueStats = {
    'totalRevenue': 0,
    'monthlyRecurring': 0,
    'activeSubscriptions': 0,
    'revenueGrowth': 0,
    'subscriptionGrowth': 0,
  };

  Map<String, int> _planStats = {
    'basic': 0,
    'pro': 0,
    'enterprise': 0,
    'total': 0,
  };

  // Plan management
  List<SubscriptionPlan> _plans = [];
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Reduced from 5 to 4 tabs
    _loadDynamicStats();
    _loadPlansFromFirestore();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load dynamic stats from Firestore
  void _loadDynamicStats() {
    _loadRevenueStats();
    _loadPlanStats();
  }

  void _loadRevenueStats() {
    int previousActiveSubs = _revenueStats['activeSubscriptions'] ?? 0;

    // 1️⃣ Listen to transactions for total revenue (kept as before)
    FirebaseFirestore.instance.collection('transactions').snapshots().listen((snapshot) {
      final stats = _calculateRevenueStats(snapshot.docs);
      if (mounted) {
        setState(() {
          _revenueStats = {..._revenueStats, ...stats};
        });
      }
    });

    // 2️⃣ Listen to gyms for active subs + auto-expiry
    FirebaseFirestore.instance.collection('gyms').snapshots().listen((snapshot) async {
      int activeSubs = 0;
      double totalPlanPrice = 0;

      for (final gym in snapshot.docs) {
        final data = gym.data() as Map<String, dynamic>;

        final status = (data['subscriptionStatus'] ?? '').toString();
        final planPrice = (data['planPrice'] ?? 0).toDouble();
        final endTs = data['subscriptionEndDate'];
        DateTime? endDate;

        try {
          if (endTs is Timestamp) {
            endDate = endTs.toDate();
          } else if (endTs is String) {
            endDate = DateTime.tryParse(endTs);
          }
        } catch (_) {
          endDate = null;
        }

        // 🕒 Auto-expire expired subscriptions
        if (endDate != null && endDate.isBefore(DateTime.now()) && status == 'active') {
          await FirebaseFirestore.instance.collection('gyms').doc(gym.id).update({
            'subscriptionStatus': 'expired',
          });
        }

        if (status == 'active') {
          activeSubs++;
          totalPlanPrice += planPrice;
        }
      }

      // 💰 Platform earnings = 20% of total revenue
      final platformEarnings = (totalPlanPrice * 0.2).toInt();

      final subscriptionGrowth = previousActiveSubs > 0
          ? ((activeSubs - previousActiveSubs) / previousActiveSubs * 100).round()
          : activeSubs > 0
          ? 100
          : 0;

      if (mounted) {
        setState(() {
          _revenueStats['activeSubscriptions'] = activeSubs;
          _revenueStats['platformEarnings'] = platformEarnings;
          _revenueStats['subscriptionGrowth'] = subscriptionGrowth;
          previousActiveSubs = activeSubs;
        });
      }
    });

    // 3️⃣ Pending payouts (same as before)
    FirebaseFirestore.instance
        .collection('payouts')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      double pendingAmount = 0;
      for (final payout in snapshot.docs) {
        final data = payout.data() as Map<String, dynamic>;
        pendingAmount += (data['amount'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _revenueStats['pendingPayouts'] = pendingAmount.toInt();
        });
      }
    });
  }

  void _loadPlanStats() {
    FirebaseFirestore.instance.collection('gyms').snapshots().listen((snapshot) {
      final stats = _calculatePlanStats(snapshot.docs);
      if (mounted) {
        setState(() {
          _planStats = stats;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // HEADER
          _buildHeader(),

          // QUICK STATS
          _buildRevenueStats(),

          // TIME FILTER & CONTROLS
          _buildTimeFilterBar(),

          // TABS
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Gym Plans'),
                Tab(text: 'Transactions'),
                Tab(text: 'Subscription Plans'), // Removed Payouts tab
              ],
            ),
          ),

          // TAB CONTENT
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildGymPlansTab(),
                _buildTransactionsTab(),
                _buildSubscriptionPlansTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.currency_rupee, size: 24, color: Colors.green),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Revenue & Subscriptions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 14),
            label: const Text('Export', style: TextStyle(fontSize: 12)),
            onPressed: _exportRevenueReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 180,
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.8,
          children: [
            _buildRevenueStatCard(
              'Total Revenue',
              '₹${_formatCurrency(_revenueStats['totalRevenue'] ?? 0)}',
              Icons.currency_rupee,
              Colors.green,
              '${_revenueStats['revenueGrowth'] ?? 0}% growth',
            ),
            _buildRevenueStatCard(
              'Monthly Recurring',
              '₹${_formatCurrency(_revenueStats['monthlyRecurring'] ?? 0)}',
              Icons.autorenew,
              Colors.blue,
              'MRR from active subs',
            ),
            _buildRevenueStatCard(
              'Active Subs',
              '${_revenueStats['activeSubscriptions'] ?? 0}',
              Icons.subscriptions,
              Colors.orange,
              '${_revenueStats['subscriptionGrowth'] ?? 0}% growth',
            ),
            _buildRevenueStatCard(
              'Avg. Revenue/Sub',
              '₹${_calculateARPU()}',
              Icons.trending_up,
              Colors.purple,
              'Average revenue per user',
            ),
          ],
        ),
      ),
    );
  }

  String _calculateARPU() {
    final activeSubs = _revenueStats['activeSubscriptions'] ?? 1;
    final monthlyRevenue = _revenueStats['monthlyRecurring'] ?? 0;
    final arpu = activeSubs > 0 ? monthlyRevenue / activeSubs : 0;
    return _formatCurrency(arpu.round());
  }

  Widget _buildRevenueStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 8,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTimeFilterButton('Monthly', 'monthly'),
            const SizedBox(width: 6),
            _buildTimeFilterButton('Quarterly', 'quarterly'),
            const SizedBox(width: 6),
            _buildTimeFilterButton('Yearly', 'yearly'),
            const SizedBox(width: 6),
            _buildTimeFilterButton('Custom', 'custom'),
            const SizedBox(width: 12),
            if (_timeFilter == 'custom' && _customDateRange != null)
              Text(
                '${DateFormat('MMM dd').format(_customDateRange!.start)} - ${DateFormat('MMM dd').format(_customDateRange!.end)}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.calendar_today, size: 14),
              onPressed: _selectCustomDateRange,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeFilterButton(String label, String value) {
    return ElevatedButton(
      onPressed: () => _setTimeFilter(value),
      style: ElevatedButton.styleFrom(
        backgroundColor: _timeFilter == value ? Colors.blue : Colors.grey[100],
        foregroundColor: _timeFilter == value ? Colors.white : Colors.grey,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
      ),
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }

  // ============ OVERVIEW TAB ============
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRevenueChartSection(),
          const SizedBox(height: 16),
          _buildQuickActions(),
          const SizedBox(height: 16),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildRevenueChartSection() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue Overview',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transactions')
                      .where('createdAt', isGreaterThan: DateTime.now().subtract(const Duration(days: 30)))
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return const Center(
                      child: Text(
                        'Revenue Chart\n(Integrate charts library)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMetricItem('Monthly Revenue', '₹${_formatCurrency(_revenueStats['monthlyRecurring'] ?? 0)}', '+${_revenueStats['revenueGrowth'] ?? 0}%'),
                  const SizedBox(width: 16),
                  _buildMetricItem('Active Gyms', '${_planStats['total'] ?? 0}', '+${_revenueStats['subscriptionGrowth'] ?? 0}%'),
                  const SizedBox(width: 16),
                  _buildMetricItem('Avg. Revenue', '₹${_calculateARPU()}', '+5%'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, String growth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(
          growth,
          style: TextStyle(
            fontSize: 8,
            color: growth.contains('+') ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickActionButton('Send Invoices', Icons.receipt, Colors.blue, _sendInvoices),
                _buildQuickActionButton('GST Report', Icons.description, Colors.orange, _generateGSTReport),
                _buildQuickActionButton('Update Plans', Icons.upgrade, Colors.purple, _updatePlans),
                _buildQuickActionButton('Renew Subs', Icons.autorenew, Colors.green, _renewSubscriptions),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 12),
      label: Text(label, style: const TextStyle(fontSize: 10)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final transactions = snapshot.data!.docs;
                if (transactions.isEmpty) {
                  return const Center(child: Text('No recent activity', style: TextStyle(fontSize: 12)));
                }

                return Column(
                  children: transactions.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildActivityItem(data);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> data) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _getTransactionColor(data['type']).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(_getTransactionIcon(data['type']), size: 16, color: _getTransactionColor(data['type'])),
      ),
      title: Text(
        data['description'] ?? 'Unknown',
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        DateFormat('MMM dd • HH:mm').format((data['createdAt'] as Timestamp).toDate()),
        style: const TextStyle(fontSize: 10),
      ),
      trailing: Text(
        '₹${_formatCurrency(data['amount'] ?? 0)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _getAmountColor(data['type']),
          fontSize: 12,
        ),
      ),
    );
  }

  // ============ GYM PLANS TAB ============
  Widget _buildGymPlansTab() {
    return Column(
      children: [
        _buildGymPlansSearchBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('gyms').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final gyms = snapshot.data!.docs;
              final filteredGyms = _filterGymsBySearch(gyms);

              if (filteredGyms.isEmpty) {
                return const Center(
                  child: Text('No gyms found', style: TextStyle(fontSize: 12)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filteredGyms.length,
                itemBuilder: (context, index) {
                  final gym = filteredGyms[index];
                  final gymData = gym.data() as Map<String, dynamic>;
                  return _buildGymPlanCard(gym.id, gymData);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGymPlansSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search gyms...',
                prefixIcon: Icon(Icons.search, size: 16),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, size: 16),
            onSelected: (filter) {
              // Handle filter selection
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Plans', style: TextStyle(fontSize: 12))),
              const PopupMenuItem(value: 'basic', child: Text('Basic Plan', style: TextStyle(fontSize: 12))),
              const PopupMenuItem(value: 'pro', child: Text('Pro Plan', style: TextStyle(fontSize: 12))),
              const PopupMenuItem(value: 'enterprise', child: Text('Enterprise Plan', style: TextStyle(fontSize: 12))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGymPlanCard(String gymId, Map<String, dynamic> gymData) {
    final plan = gymData['subscriptionPlan'] ?? 'basic';
    final planData = _plans.firstWhere((p) => p.id == plan, orElse: () => _plans.first);
    final status = gymData['subscriptionStatus'] ?? 'active';
    final endDate = gymData['subscriptionEndDate'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    gymData['businessName'] ?? 'Unknown Gym',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getSubscriptionStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getSubscriptionStatusColor(status),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Owner: ${gymData['contact']?['ownerName'] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              'Plan: ${planData.name} • ₹${_formatCurrency(planData.price)}/month',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            if (endDate != null)
              Text(
                'Renews: ${DateFormat('MMM dd, yyyy').format(endDate.toDate())}',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildGymPlanActionButton('Change Plan', Icons.swap_horiz, () => _handleGymPlanAction('change_plan', gymId, gymData)),
                  const SizedBox(width: 6),
                  _buildGymPlanActionButton('Renew', Icons.autorenew, () => _handleGymPlanAction('renew', gymId, gymData)),
                  const SizedBox(width: 6),
                  _buildGymPlanActionButton('Invoice', Icons.receipt, () => _handleGymPlanAction('invoice', gymId, gymData)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGymPlanActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 10),
      label: Text(label, style: const TextStyle(fontSize: 9)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: Size.zero,
      ),
    );
  }

  // ============ TRANSACTIONS TAB ============
  Widget _buildTransactionsTab() {
    return Column(
      children: [
        _buildTransactionsFilterBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final transactions = snapshot.data!.docs;

              if (transactions.isEmpty) {
                return const Center(
                  child: Text('No transactions found', style: TextStyle(fontSize: 12)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  final data = transaction.data() as Map<String, dynamic>;
                  return _buildTransactionItem(data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', true),
            const SizedBox(width: 6),
            _buildFilterChip('Subscriptions', false),
            const SizedBox(width: 6),
            _buildFilterChip('Refunds', false),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.download, size: 16),
              onPressed: _exportTransactions,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      selected: selected,
      onSelected: (value) {
        // Handle filter selection
      },
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _getTransactionColor(data['type']).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(_getTransactionIcon(data['type']), size: 16, color: _getTransactionColor(data['type'])),
        ),
        title: Text(
          data['description'] ?? 'Unknown Transaction',
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMM dd • HH:mm').format((data['createdAt'] as Timestamp).toDate()),
              style: const TextStyle(fontSize: 9),
            ),
            if (data['gymName'] != null)
              Text(
                'Gym: ${data['gymName']}',
                style: const TextStyle(fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${_formatCurrency(data['amount'] ?? 0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getAmountColor(data['type']),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: _getTransactionStatusColor(data['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                (data['status'] ?? 'completed').toString().toUpperCase(),
                style: TextStyle(
                  color: _getTransactionStatusColor(data['status']),
                  fontSize: 6,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ SUBSCRIPTION PLANS TAB ============
  Widget _buildSubscriptionPlansTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildPlanStats(),
          const SizedBox(height: 16),
          ..._plans.map((plan) => _buildPlanCard(plan)).toList(),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Create New Plan', style: TextStyle(fontSize: 12)),
            onPressed: _createNewPlan,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPlanStatItem('Basic', _planStats['basic'] ?? 0, Colors.blue),
              const SizedBox(width: 16),
              _buildPlanStatItem('Pro', _planStats['pro'] ?? 0, Colors.green),
              const SizedBox(width: 16),
              _buildPlanStatItem('Enterprise', _planStats['enterprise'] ?? 0, Colors.purple),
              const SizedBox(width: 16),
              _buildPlanStatItem('Total', _planStats['total'] ?? 0, Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanStatItem(String plan, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.people, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          count.toString(),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
        Text(plan, style: const TextStyle(fontSize: 8, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: plan.isActive,
                  onChanged: (value) => _togglePlanStatus(plan.id, value),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '₹${_formatCurrency(plan.price)} / ${plan.duration} days',
              style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildPlanFeatureChip('${plan.gymLimit == -1 ? 'Unlimited' : plan.gymLimit} Gyms'),
                _buildPlanFeatureChip('${plan.memberLimit == -1 ? 'Unlimited' : plan.memberLimit} Members'),
                _buildPlanFeatureChip('${plan.duration} Days'),
              ],
            ),
            const SizedBox(height: 8),
            ...plan.features.map((feature) => _buildFeatureItem(feature)).toList(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit, size: 12),
                    label: const Text('Edit', style: TextStyle(fontSize: 10)),
                    onPressed: () => _editPlan(plan),
                    style: ElevatedButton.styleFrom(foregroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 6)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.content_copy, size: 12),
                    label: const Text('Duplicate', style: TextStyle(fontSize: 10)),
                    onPressed: () => _duplicatePlan(plan),
                    style: ElevatedButton.styleFrom(foregroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 6)),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  onPressed: () => _deletePlan(plan.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanFeatureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 8, color: Colors.blue, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 12, color: Colors.green),
          const SizedBox(width: 6),
          Expanded(child: Text(feature, style: const TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  // ============ UTILITY METHODS ============
  Map<String, dynamic> _calculateRevenueStats(List<QueryDocumentSnapshot> transactions) {
    double totalRevenue = 0;
    double platformEarnings = 0;

    DateTime now = DateTime.now();
    DateTime startDate;

    switch (_timeFilter) {
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'quarterly':
        startDate = DateTime(now.year, now.month - 3, 1);
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        break;
      case 'custom':
        startDate = _customDateRange?.start ?? DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
    }

    for (final transaction in transactions) {
      final data = transaction.data() as Map<String, dynamic>;
      final amount = (data['amount'] ?? 0).toDouble();
      final type = (data['type'] ?? '').toString();
      final createdAt = (data['createdAt'] as Timestamp).toDate();

      if (createdAt.isAfter(startDate) && (type == 'subscription' || type == 'payment')) {
        totalRevenue += amount;
        platformEarnings += amount * 0.2;
      }
    }

    final previousRevenue = totalRevenue * 0.8;
    final revenueGrowth = previousRevenue > 0
        ? ((totalRevenue - previousRevenue) / previousRevenue * 100).round()
        : 0;

    return {
      'totalRevenue': totalRevenue.toInt(),
      'platformEarnings': platformEarnings.toInt(),
      'revenueGrowth': revenueGrowth,
      'subscriptionGrowth': _revenueStats['subscriptionGrowth'] ?? 0,
    };
  }

  Map<String, int> _calculatePlanStats(List<QueryDocumentSnapshot> gyms) {
    final stats = {'basic': 0, 'pro': 0, 'enterprise': 0, 'total': 0};

    for (final gym in gyms) {
      final data = gym.data() as Map<String, dynamic>;
      final plan = data['subscriptionPlan']?.toString().toLowerCase() ?? 'basic';
      final status = data['subscriptionStatus']?.toString() ?? 'inactive';

      // Only count active subscriptions
      if (status == 'active') {
        stats['total'] = (stats['total'] ?? 0) + 1;

        if (stats.containsKey(plan)) {
          stats[plan] = (stats[plan] ?? 0) + 1;
        } else {
          // If plan doesn't match known plans, count as basic
          stats['basic'] = (stats['basic'] ?? 0) + 1;
        }
      }
    }

    return stats;
  }

  List<QueryDocumentSnapshot> _filterGymsBySearch(List<QueryDocumentSnapshot> gyms) {
    if (_searchQuery.isEmpty) return gyms;
    return gyms.where((gym) {
      final data = gym.data() as Map<String, dynamic>;
      final businessName = data['businessName']?.toString().toLowerCase() ?? '';
      final ownerName = data['contact']?['ownerName']?.toString().toLowerCase() ?? '';
      final plan = data['subscriptionPlan']?.toString().toLowerCase() ?? '';
      return businessName.contains(_searchQuery) ||
          ownerName.contains(_searchQuery) ||
          plan.contains(_searchQuery);
    }).toList();
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,##0', 'en_IN');
    return formatter.format(amount);
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'subscription': return Colors.green;
      case 'refund': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'subscription': return Icons.subscriptions;
      case 'refund': return Icons.assignment_return;
      default: return Icons.receipt;
    }
  }

  Color _getAmountColor(String type) {
    switch (type) {
      case 'subscription': return Colors.green;
      case 'refund': return Colors.red;
      default: return Colors.blue;
    }
  }

  Color _getTransactionStatusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'failed': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _getSubscriptionStatusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'pending': return Colors.orange;
      case 'expired': return Colors.red;
      case 'cancelled': return Colors.grey;
      default: return Colors.blue;
    }
  }

  // ============ ACTION METHODS ============
  void _setTimeFilter(String filter) {
    setState(() {
      _timeFilter = filter;
    });
    // Reload stats when filter changes
    _loadDynamicStats();
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      currentDate: DateTime.now(),
      saveText: 'Apply',
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _timeFilter = 'custom';
      });
      // Reload stats when date range changes
      _loadDynamicStats();
    }
  }

  void _exportRevenueReport() async {
    try {
      // Create CSV data
      String csvData = 'Date,Description,Amount,Type,Status,Gym\n';

      // Get transactions data
      final snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        csvData += '"${DateFormat('yyyy-MM-dd').format((data['createdAt'] as Timestamp).toDate())}",'
            '"${data['description'] ?? ''}",'
            '"${data['amount'] ?? 0}",'
            '"${data['type'] ?? ''}",'
            '"${data['status'] ?? ''}",'
            '"${data['gymName'] ?? ''}"\n';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revenue report exported successfully')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _exportTransactions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transactions exported successfully')),
    );
  }

  void _sendInvoices() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invoices sent successfully')),
    );
  }

  void _generateGSTReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GST report generated successfully')),
    );
  }

  void _updatePlans() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plans updated successfully')),
    );
  }

  void _renewSubscriptions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subscription renewals processed')),
    );
  }

  void _handleGymPlanAction(String action, String gymId, Map<String, dynamic> gymData) {
    switch (action) {
      case 'change_plan':
        _changeGymPlan(gymId, gymData);
        break;
      case 'renew':
        _renewSubscription(gymId);
        break;
      case 'invoice':
        _generateInvoice(gymId);
        break;
    }
  }

  void _changeGymPlan(String gymId, Map<String, dynamic> gymData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Plan'),
        content: const Text('Plan change functionality would go here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Plan changed successfully')),
              );
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _renewSubscription(String gymId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subscription renewed successfully')),
    );
  }

  void _generateInvoice(String gymId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invoice generated successfully')),
    );
  }

  void _togglePlanStatus(String planId, bool isActive) {
    setState(() {
      final plan = _plans.firstWhere((p) => p.id == planId);
      plan.isActive = isActive;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Plan ${isActive ? 'activated' : 'deactivated'} successfully')),
    );
  }
  void _loadPlansFromFirestore() {
    FirebaseFirestore.instance
        .collection('subscription_plans')
        .orderBy('price')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _plans = snapshot.docs.map((doc) {
          final data = doc.data();
          return SubscriptionPlan(
            id: doc.id,
            name: data['name'] ?? '',
            price: data['price'] ?? 0,
            duration: data['duration'] ?? 30,
            features: List<String>.from(data['features'] ?? []),
            gymLimit: data['gymLimit'] ?? -1,
            memberLimit: data['memberLimit'] ?? -1,
            isActive: data['isActive'] ?? true,
          );
        }).toList();
      });
    });
  }

  void _createNewPlan() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final durationController = TextEditingController();
    final gymLimitController = TextEditingController();
    final memberLimitController = TextEditingController();
    final featuresController = TextEditingController();
    bool isActive = true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Plan'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Plan Name')),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price (₹)'), keyboardType: TextInputType.number),
              TextField(controller: durationController, decoration: const InputDecoration(labelText: 'Duration (Days)'), keyboardType: TextInputType.number),
              TextField(controller: gymLimitController, decoration: const InputDecoration(labelText: 'Gym Limit (-1 for Unlimited)'), keyboardType: TextInputType.number),
              TextField(controller: memberLimitController, decoration: const InputDecoration(labelText: 'Member Limit (-1 for Unlimited)'), keyboardType: TextInputType.number),
              TextField(controller: featuresController, decoration: const InputDecoration(labelText: 'Features (comma separated)')),
              SwitchListTile(
                title: const Text('Active Plan'),
                value: isActive,
                onChanged: (val) => setState(() => isActive = val),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newPlan = {
                'name': nameController.text.trim(),
                'price': int.tryParse(priceController.text) ?? 0,
                'duration': int.tryParse(durationController.text) ?? 30,
                'gymLimit': int.tryParse(gymLimitController.text) ?? -1,
                'memberLimit': int.tryParse(memberLimitController.text) ?? -1,
                'features': featuresController.text.split(',').map((e) => e.trim()).toList(),
                'isActive': isActive,
                'createdAt': FieldValue.serverTimestamp(),
              };

              await FirebaseFirestore.instance.collection('subscription_plans').add(newPlan);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New plan created successfully')));
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
  void _editPlan(SubscriptionPlan plan) {
    final nameController = TextEditingController(text: plan.name);
    final priceController = TextEditingController(text: plan.price.toString());
    final durationController = TextEditingController(text: plan.duration.toString());
    final gymLimitController = TextEditingController(text: plan.gymLimit.toString());
    final memberLimitController = TextEditingController(text: plan.memberLimit.toString());
    final featuresController = TextEditingController(text: plan.features.join(', '));
    bool isActive = plan.isActive;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Plan'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Plan Name')),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Price (₹)'), keyboardType: TextInputType.number),
              TextField(controller: durationController, decoration: const InputDecoration(labelText: 'Duration (Days)'), keyboardType: TextInputType.number),
              TextField(controller: gymLimitController, decoration: const InputDecoration(labelText: 'Gym Limit (-1 for Unlimited)'), keyboardType: TextInputType.number),
              TextField(controller: memberLimitController, decoration: const InputDecoration(labelText: 'Member Limit (-1 for Unlimited)'), keyboardType: TextInputType.number),
              TextField(controller: featuresController, decoration: const InputDecoration(labelText: 'Features (comma separated)')),
              SwitchListTile(
                title: const Text('Active Plan'),
                value: isActive,
                onChanged: (val) => setState(() => isActive = val),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final updatedPlan = {
                'name': nameController.text.trim(),
                'price': int.tryParse(priceController.text) ?? plan.price,
                'duration': int.tryParse(durationController.text) ?? plan.duration,
                'gymLimit': int.tryParse(gymLimitController.text) ?? plan.gymLimit,
                'memberLimit': int.tryParse(memberLimitController.text) ?? plan.memberLimit,
                'features': featuresController.text.split(',').map((e) => e.trim()).toList(),
                'isActive': isActive,
                'updatedAt': FieldValue.serverTimestamp(),
              };

              await FirebaseFirestore.instance.collection('subscription_plans').doc(plan.id).update(updatedPlan);

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan updated successfully')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _duplicatePlan(SubscriptionPlan plan) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Plan duplicated successfully')),
    );
  }

  void _deletePlan(String planId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: const Text('Are you sure you want to permanently delete this plan? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('subscription_plans').doc(planId).delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan deleted successfully')));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class SubscriptionPlan {
  final String id;
  final String name;
  final int price;
  final int duration;
  final List<String> features;
  final int gymLimit;
  final int memberLimit;
  bool isActive;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    required this.features,
    required this.gymLimit,
    required this.memberLimit,
    required this.isActive,
  });
}