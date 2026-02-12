import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/app_theme.dart';


class PaymentManagementScreen extends StatefulWidget {
  const PaymentManagementScreen({Key? key}) : super(key: key);

  @override
  State<PaymentManagementScreen> createState() =>
      _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  int _selectedTab = 0; // 0: Staff, 1: Trainers, 2: Plans
  String? _gymId;

  double _totalPayout = 0;
  double _totalRevenue = 0;
  int _pendingPayments = 0;
  int _completedPayments = 0;

  List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _initializeGymData();
    _scheduleDailyRenewalCheck();
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _initializeGymAndListeners() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final gymSnap = await _firestore
        .collection('gyms')
        .where('ownerId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (gymSnap.docs.isEmpty || !mounted) return;

    final gymDoc = gymSnap.docs.first;
    setState(() => _gymId = gymDoc.id);

    // ── Real-time listeners (auto-update UI) ─────────────────────
    final staffListener = _firestore
        .collection('staff_payments')
        .where('gymId', isEqualTo: _gymId)
        .snapshots()
        .listen((_) => _updateStats());

    final trainerListener = _firestore
        .collection('trainer_payments')
        .where('gymId', isEqualTo: _gymId)
        .snapshots()
        .listen((_) => _updateStats());

    final membersListener = _firestore
        .collection('gyms')
        .doc(_gymId)
        .collection('members')
        .snapshots()
        .listen((_) => _updateStats());

    final plansListener = _firestore
        .collection('gyms')
        .doc(_gymId)
        .collection('plans')
        .snapshots()
        .listen((_) => _updateStats());

    _subscriptions.addAll([staffListener, trainerListener, membersListener, plansListener]);

    // Initial stats
    _updateStats();
  }

  // ──────────────────────────────────────────────────────────────
  // 2. REAL-TIME STATS (Revenue + Payouts)
  // ──────────────────────────────────────────────────────────────
  Future<void> _updateStats() async {
    if (_gymId == null || !mounted) return;

    double payoutTotal = 0;
    int pending = 0;
    int completed = 0;
    double revenueTotal = 0;

    try {
      // ── Payouts (Staff + Trainer) ─────────────────────────────
      final staffSnap = await _firestore
          .collection('staff_payments')
          .where('gymId', isEqualTo: _gymId)
          .get();

      final trainerSnap = await _firestore
          .collection('trainer_payments')
          .where('gymId', isEqualTo: _gymId)
          .get();

      for (var doc in [...staffSnap.docs, ...trainerSnap.docs]) {
        final data = doc.data();
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        final amount = (data['amount'] ?? 0).toDouble();

        if (status == 'paid' || status == 'completed') {
          payoutTotal += amount;
          completed++;
        } else {
          pending++;
        }
      }

      // ── Revenue – use subscriptionPrice stored on member (RELIABLE) ──
      final membersSnap = await _firestore
          .collection('gyms')
          .doc(_gymId)
          .collection('members')
          .get();

      for (var doc in membersSnap.docs) {
        final data = doc.data();
        final status = (data['subscriptionStatus'] ?? data['status'] ?? '')
            .toString()
            .toLowerCase();

        if (status == 'active' || status == 'paid') {
          final price = (data['subscriptionPrice'] ?? 0).toDouble();
          final counted = data['countedInRevenue'] ?? true;
          if (counted == true) revenueTotal += price;
        }
      }

      if (!mounted) return;

      setState(() {
        _totalPayout = payoutTotal;
        _totalRevenue = revenueTotal;
        _pendingPayments = pending;
        _completedPayments = completed;
      });
    } catch (e) {
      debugPrint('Stats error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // 3. AUTOMATIC SUBSCRIPTION RENEWAL (runs daily)
  // ──────────────────────────────────────────────────────────────
  void _scheduleDailyRenewalCheck() {
    // Run immediately + every day at ~00:05
    _checkAndRenewExpiringSubscriptions();
    Timer.periodic(const Duration(days: 1), (_) => _checkAndRenewExpiringSubscriptions());
  }

  Future<void> _checkAndRenewExpiringSubscriptions() async {
    if (_gymId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    try {
      final expiringSnap = await _firestore
          .collection('gyms')
          .doc(_gymId)
          .collection('members')
          .where('subscriptionEndDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('subscriptionEndDate', isLessThan: Timestamp.fromDate(tomorrow))
          .where('subscriptionStatus', isEqualTo: 'active')
          .get();

      for (var doc in expiringSnap.docs) {
        final data = doc.data();
        final memberId = doc.id;
        final price = (data['subscriptionPrice'] ?? 0).toDouble();
        final planName = data['subscriptionPlan'] ?? 'Unknown';

        // Auto-renew logic (you can replace with real payment later)
        final newEndDate = Timestamp.fromDate(
            (data['subscriptionEndDate'] as Timestamp).toDate().add(const Duration(days: 30)));

        await _firestore
            .collection('gyms')
            .doc(_gymId)
            .collection('members')
            .doc(memberId)
            .update({
          'subscriptionEndDate': newEndDate,
          'subscriptionStatus': 'active',
          'renewedAt': Timestamp.now(),
          'lastRenewalPrice': price,
        });

        // Optional: Add renewal transaction record
        await _firestore
            .collection('gyms')
            .doc(_gymId)
            .collection('renewal_history')
            .add({
          'memberId': memberId,
          'memberName': data['name'] ?? data['firstName'],
          'amount': price,
          'plan': planName,
          'renewedAt': Timestamp.now(),
        });

        debugPrint('Auto-renewed member $memberId – ₹$price');
      }
    } catch (e) {
      debugPrint('Renewal check error: $e');
    }
  }
  Future<void> _initializeGymData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final gyms = await _firestore
        .collection('gyms')
        .where('ownerId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (gyms.docs.isNotEmpty) {
      setState(() => _gymId = gyms.docs.first.id);
      await _recomputeStats();
      // also listen for realtime changes so UI updates automatically
      final _ = _firestore
          .collection('staff_payments')
          .where('gymId', isEqualTo: _gymId)
          .snapshots()
          .listen((_) => _recomputeStats());

      final _ = _firestore
          .collection('trainer_payments')
          .where('gymId', isEqualTo: _gymId)
          .snapshots()
          .listen((_) => _recomputeStats());

      final _ = _firestore
          .collection('gyms')
          .doc(_gymId)
          .collection('members')
          .snapshots()
          .listen((_) => _recomputeStats());
      _firestore
          .collection('trainer_payments')
          .where('gymId', isEqualTo: _gymId)
          .snapshots()
          .listen((_) => _recomputeStats());
      _firestore
          .collection('gyms')
          .doc(_gymId)
          .collection('members')
          .snapshots()
          .listen((_) => _recomputeStats());
    }
  }

  /// 🔥 Compute Stats
  Future<void> _recomputeStats() async {
    if (_gymId == null || !mounted) return;

    double payoutTotal = 0;
    int pending = 0;
    int completed = 0;
    double totalRevenue = 0;

    try {
      // === Staff & Trainer Payouts (unchanged) ===
      final staffSnap = await _firestore
          .collection('staff_payments')
          .where('gymId', isEqualTo: _gymId)
          .get();

      final trainerSnap = await _firestore
          .collection('trainer_payments')
          .where('gymId', isEqualTo: _gymId)
          .get();

      for (var d in staffSnap.docs) {
        final data = d.data();
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        final amount = (data['amount'] ?? 0).toDouble();
        if (status == 'paid' || status == 'completed') {
          payoutTotal += amount;
          completed++;
        } else {
          pending++;
        }
      }

      for (var d in trainerSnap.docs) {
        final data = d.data();
        final status = (data['status'] ?? 'pending').toString().toLowerCase();
        final amount = (data['amount'] ?? 0).toDouble();
        if (status == 'paid' || status == 'completed') {
          payoutTotal += amount;
          completed++;
        } else {
          pending++;
        }
      }

      // === TOTAL REVENUE: Use subscriptionPrice from member doc (RELIABLE) ===
      final membersSnap = await _firestore
          .collection('gyms')
          .doc(_gymId)
          .collection('members')
          .get();

      for (var doc in membersSnap.docs) {
        final data = doc.data();
        final status = (data['subscriptionStatus'] ?? data['status'] ?? '')
            .toString()
            .toLowerCase();

        // Accept multiple variations
        if (status == 'active' || status == 'paid') {
          final price = (data['subscriptionPrice'] ?? 0).toDouble();
          final counted = data['countedInRevenue'] ?? true;

          if (counted == true) {
            totalRevenue += price;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _totalPayout = payoutTotal;
        _totalRevenue = totalRevenue;
        _pendingPayments = pending;
        _completedPayments = completed;
      });
    } catch (e) {
      debugPrint('Error recomputing stats: $e');
    }
  }

  /// 💰 Dashboard Stats
  List<Map<String, dynamic>> get _statsData => [
    {
      'title': 'Total Revenue',
      'value': '₹${_totalRevenue.toStringAsFixed(0)}',
      'icon': Icons.trending_up,
      'color': AppTheme.primaryGreen
    },
    {
      'title': 'Total Payout',
      'value': '₹${_totalPayout.toStringAsFixed(0)}',
      'icon': Icons.account_balance_wallet,
      'color': AppTheme.fitnessgreen
    },
    {
      'title': 'Pending',
      'value': _pendingPayments.toString(),
      'icon': Icons.pending_actions,
      'color': AppTheme.fitnessOrange
    },
    {
      'title': 'Completed',
      'value': _completedPayments.toString(),
      'icon': Icons.check_circle,
      'color': AppTheme.accentGreen
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            _buildStatsSection(theme),
            _buildTabs(theme),
            Expanded(
              child: _selectedTab == 2
                  ? _buildPlansList(theme)
                  : _buildPaymentsList(theme),
            ),
          ],
        ),
      ),
      floatingActionButton: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'payment') _showAddPaymentDialog();
          if (value == 'plan') _showAddSubscriptionPlanDialog();
        },
        color: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'payment',
            child: Row(
              children: [
                Icon(Icons.payments, color: theme.colorScheme.onSurface),
                const SizedBox(width: 8),
                Text('Add Payment',
                    style: TextStyle(color: theme.colorScheme.onSurface))
              ],
            ),
          ),
          PopupMenuItem(
            value: 'plan',
            child: Row(
              children: [
                Icon(Icons.workspace_premium,
                    color: theme.colorScheme.onSurface),
                const SizedBox(width: 8),
                Text('Add Plan',
                    style: TextStyle(color: theme.colorScheme.onSurface))
              ],
            ),
          ),
        ],
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryGreen, AppTheme.accentGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) => Container(
    padding: const EdgeInsets.all(20),
    color: theme.appBarTheme.backgroundColor,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Payments & Plans Management',
          style: TextStyle(
              color: theme.appBarTheme.foregroundColor,
              fontSize: 20,
              fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  Widget _buildStatsSection(ThemeData theme) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(12),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.4),
    itemCount: _statsData.length,
    itemBuilder: (context, i) {
      final s = _statsData[i];
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: s['color'].withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(s['icon'], color: s['color'], size: 20),
                ),
                const Spacer(),
                if (s['title'] == 'Pending' || s['title'] == 'Completed')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: s['color'].withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      s['value'],
                      style: TextStyle(
                        color: s['color'],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(s['value'],
                style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(s['title'],
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12))
          ],
        ),
      );
    },
  );

  Widget _buildTabs(ThemeData theme) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.all(12),
    child: Row(
      children: [
        _buildTab('Staff', 0, theme),
        _buildTab('Trainers', 1, theme),
        _buildTab('Plans', 2, theme),
      ],
    ),
  );

  Widget _buildTab(String title, int index, ThemeData theme) => Expanded(
    child: InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _selectedTab == index
              ? AppTheme.primaryGreen
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(title,
              style: TextStyle(
                  color: _selectedTab == index
                      ? Colors.white
                      : theme.colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w600)),
        ),
      ),
    ),
  );

  /// 🔹 PLANS LIST
  Widget _buildPlansList(ThemeData theme) {
    if (_gymId == null) return Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('gyms')
          .doc(_gymId)
          .collection('plans')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          // CHECK LEGACY: If sub-collection is empty, check if gym doc has pricingPlans array
          return FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('gyms').doc(_gymId).get(),
            builder: (context, gymSnap) {
              if (gymSnap.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
              }
              
              if (gymSnap.hasData && gymSnap.data!.exists) {
                final gymData = gymSnap.data!.data() as Map<String, dynamic>?;
                final List? pricingPlans = gymData?['pricingPlans'];
                
                if (pricingPlans != null && pricingPlans.isNotEmpty) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: pricingPlans.length,
                    itemBuilder: (context, i) {
                      final plan = pricingPlans[i] as Map<String, dynamic>;
                      return _buildLegacyPlanCard(plan, theme);
                    },
                  );
                }
              }

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          size: 64),
                      const SizedBox(height: 16),
                      Text('No Subscription Plans Found',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Add your first plan to get started',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                              fontSize: 14)),
                    ],
                  ),
                ),
              );
            },
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final plan = docs[i].data() as Map<String, dynamic>;
            final isActive = plan['isActive'] ?? true;

            return Card(
              color: theme.cardColor,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.workspace_premium,
                      color: isActive ? AppTheme.primaryGreen : theme.colorScheme.onSurface.withOpacity(0.5)),
                ),
                title: Text('${plan['planName']}',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('₹${plan['price']} • ${plan['durationMonths']} months',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                    if (plan['features'] != null)
                      Text(
                        'Features: ${(plan['features'] as List).join(', ')}',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryGreen.withOpacity(0.2) : theme.colorScheme.onBackground.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: isActive ? AppTheme.primaryGreen : theme.colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegacyPlanCard(Map<String, dynamic> plan, ThemeData theme) {
    String typeLabel = (plan['type'] ?? 'Monthly').toString();
    if (typeLabel == 'month') typeLabel = 'Monthly';
    else if (typeLabel == '3 months') typeLabel = '3 Months';
    else if (typeLabel == '6 months') typeLabel = '6 Months';
    else if (typeLabel == 'year') typeLabel = 'Yearly';

    final featuresList = plan['features'];
    String featuresText = '';
    if (featuresList is List) {
      featuresText = featuresList.join(', ');
    } else if (featuresList is String) {
      featuresText = featuresList;
    }

    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.star_outline, color: AppTheme.primaryGreen),
        ),
        title: Text('${plan['name'] ?? 'Unnamed'}',
            style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('₹${plan['price']} • $typeLabel',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 13)),
            if (featuresText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Features: $featuresText',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.fitnessOrange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Onboarding',
            style: TextStyle(
              color: AppTheme.fitnessOrange,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// 🔹 PAYMENTS LIST + BUTTONS - FIXED OVERFLOW
  Widget _buildPaymentsList(ThemeData theme) {
    if (_gymId == null) return Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));

    final collection =
    _selectedTab == 0 ? 'staff_payments' : 'trainer_payments';

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(collection)
          .where('gymId', isEqualTo: _gymId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payments,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      size: 64),
                  const SizedBox(height: 16),
                  Text(
                      'No ${_selectedTab == 0 ? 'Staff' : 'Trainer'} Payments Found',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Add your first payment to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 14)),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final displayName = data['name'] ?? 'Unnamed';
            final amount = (data['amount'] ?? 0).toString();
            final status = (data['status'] ?? 'pending').toString().toLowerCase();
            final paymentDate = (data['paymentDate'] as Timestamp?)?.toDate();

            Color statusColor = AppTheme.fitnessOrange;
            IconData statusIcon = Icons.pending;

            if (status == 'paid' || status == 'completed') {
              statusColor = AppTheme.primaryGreen;
              statusIcon = Icons.check_circle;
            } else if (status == 'overdue') {
              statusColor = AppTheme.alertRed;
              statusIcon = Icons.warning;
            }

            return Card(
              color: theme.cardColor,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Leading Icon
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(statusIcon, color: statusColor),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$displayName',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('₹$amount',
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (paymentDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Date: ${DateFormat('dd MMM yyyy').format(paymentDate)}',
                                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12)),
                            ),
                          if ((data['notes'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Notes: ${data['notes']}',
                                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                      ),
                    ),

                    // Actions - FIXED OVERFLOW
                    Container(
                      width: 90, // Further reduced to ensure no overflow
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Mark as Paid Button
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.check, color: AppTheme.primaryGreen, size: 14),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                await _updateStatus(collection, id, 'paid');
                              },
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Mark as Overdue Button
                          Container(
                            width: 26,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppTheme.fitnessOrange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.warning, color: AppTheme.fitnessOrange, size: 14),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                await _updateStatus(collection, id, 'overdue');
                              },
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Generate PDF Button
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.picture_as_pdf, color: theme.colorScheme.onSurface, size: 14),
                              padding: EdgeInsets.zero,
                              onPressed: () => _generateAndShareInvoice({
                                'name': displayName,
                                'amount': data['amount'] ?? 0,
                                'status': status,
                                'notes': data['notes'] ?? '',
                                'paymentDate': data['paymentDate'],
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateStatus(String col, String id, String newStatus) async {
    await _firestore.collection(col).doc(id).update({
      'status': newStatus,
      'updatedAt': DateTime.now(),
    });
    await _recomputeStats();
  }

  /// ===================== PDF GENERATOR =====================
  Future<void> _generateAndShareInvoice(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    String gymName = 'Fitnophedia Gym';
    String? logoUrl;
    String gymAddress = '';
    String gstNumber = '';

    try {
      final gymDoc = await _firestore.collection('gyms').doc(_gymId).get();
      if (gymDoc.exists) {
        final gdata = gymDoc.data()!;
        gymName = gdata['gymName'] ?? gdata['businessName'] ?? 'Fitnophedia Gym';
        logoUrl = gdata['logoUrl'];
        gymAddress = gdata['address'] ?? '';
        gstNumber = gdata['gstNumber'] ?? '';
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching gym details: $e');
    }

    pw.MemoryImage? logoImage;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(logoUrl));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('⚠️ Failed to load logo: $e');
      }
    }

    final name = data['name'] ?? 'Unnamed';
    final amount = data['amount'] ?? 0;
    final status = (data['status'] ?? 'Pending').toString();
    final notes = data['notes'] ?? '—';
    final date = data['paymentDate'] != null
        ? DateFormat('dd MMM yyyy').format((data['paymentDate'] as Timestamp).toDate())
        : DateFormat('dd MMM yyyy').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null) pw.Center(child: pw.Image(logoImage, height: 70)),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  gymName,
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (gymAddress.isNotEmpty) pw.Center(child: pw.Text(gymAddress)),
              if (gstNumber.isNotEmpty) pw.Center(child: pw.Text('GST: $gstNumber')),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Text('Invoice for: $name', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('Invoice Date: $date'),
              pw.Text('Status: ${status.toUpperCase()}'),
              pw.SizedBox(height: 12),
              pw.Text('Amount Payable: ₹$amount', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('Notes: $notes'),
              pw.Divider(),
              pw.Spacer(),
              pw.Text('Thank you for being part of $gymName 💪'),
              pw.SizedBox(height: 20),
              pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Authorized Signature')),
            ],
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/Invoice_${name.replaceAll(" ", "_")}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Invoice for $name (₹$amount)');
    await OpenFilex.open(file.path);
  }

  /// DIALOGS
  void _showAddPaymentDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddPaymentDialog(
        gymId: _gymId,
        isTrainer: _selectedTab == 1,
      ),
    ).then((_) => _recomputeStats());
  }

  void _showAddSubscriptionPlanDialog() {
    showDialog(
      context: context,
      builder: (_) => _AddSubscriptionPlanDialog(gymId: _gymId),
    );
  }
}

/// ===================== ADD PAYMENT DIALOG =====================
class _AddPaymentDialog extends StatefulWidget {
  final String? gymId;
  final bool isTrainer;
  const _AddPaymentDialog({required this.gymId, this.isTrainer = false});

  @override
  State<_AddPaymentDialog> createState() => __AddPaymentDialogState();
}

class __AddPaymentDialogState extends State<_AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final amount = TextEditingController();
  final notes = TextEditingController();
  DateTime? paymentDate;
  String? _selectedPerson;
  List<String> _names = [];
  Map<String, String> _idByDisplay = {};

  @override
  void initState() {
    super.initState();
    _fetchNames();
    paymentDate = DateTime.now(); // Set default to today
  }

  Future<void> _fetchNames() async {
    if (widget.gymId == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(widget.gymId)
          .collection('staff')
          .where('status', isEqualTo: 'active')
          .get();

      // Filter by role
      final filtered = snap.docs.where((d) {
        final role = (d['role'] ?? '').toString().toLowerCase();
        final isTrainer = role == 'trainer';
        return widget.isTrainer ? isTrainer : !isTrainer;
      }).toList();

      setState(() {
        _names = filtered
            .map((d) =>
        '${d['name'] ?? 'Unnamed'} — ${(d['role'] ?? '').toString().capitalize()}')
            .toList();

        // Create mapping for display names to document IDs
        _idByDisplay = {
          for (var doc in filtered)
            '${doc['name'] ?? 'Unnamed'} — ${(doc['role'] ?? '').toString().capitalize()}': doc.id
        };
      });
    } catch (e) {
      debugPrint('Error fetching staff names: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    widget.isTrainer ? 'Add Trainer Payment' : 'Add Staff Payment',
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Name Dropdown
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPerson,
                      isExpanded: true,
                      hint: Text('Select Name', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                      dropdownColor: theme.cardColor,
                      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
                      items: _names.map((name) {
                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text(name, style: TextStyle(color: theme.colorScheme.onSurface)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedPerson = newValue;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _buildField(amount, 'Amount (₹)', num: true, theme: theme),
                _buildField(notes, 'Notes (Optional)', theme: theme),
                const SizedBox(height: 12),

                // Date Picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: paymentDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => paymentDate = picked);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: theme.colorScheme.onSurface.withOpacity(0.7), size: 20),
                        const SizedBox(width: 12),
                        Text(
                          paymentDate == null
                              ? 'Select Payment Date'
                              : DateFormat('dd MMM yyyy').format(paymentDate!),
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _savePayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save Payment',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.onSurface.withOpacity(0.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Cancel',
                            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String l, {bool num = false, required ThemeData theme}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: num ? TextInputType.number : TextInputType.text,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: l,
            labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: num
              ? (v) => v == null || v.isEmpty || double.tryParse(v) == null
              ? 'Enter valid amount'
              : null
              : null,
        ),
      );

  Future<void> _savePayment() async {
    if (_selectedPerson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a name'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    if (amount.text.isEmpty || double.tryParse(amount.text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid amount'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    if (paymentDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a payment date'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    final collection = widget.isTrainer ? 'trainer_payments' : 'staff_payments';
    final chosenDisplay = _selectedPerson!;
    final chosenDocId = _idByDisplay[chosenDisplay];

    try {
      await FirebaseFirestore.instance.collection(collection).add({
        'gymId': widget.gymId,
        'name': chosenDisplay.split(' — ').first, // Extract just the name
        'personId': chosenDocId,
        'amount': double.parse(amount.text),
        'notes': notes.text,
        'status': 'pending',
        'paymentDate': paymentDate,
        'createdAt': DateTime.now(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.isTrainer ? "Trainer" : "Staff"} payment added successfully!'),
          backgroundColor: AppTheme.primaryGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error adding payment: $e'),
          backgroundColor: AppTheme.alertRed,
        ));
      }
    }
  }
}

/// ===================== ADD SUBSCRIPTION PLAN DIALOG =====================
class _AddSubscriptionPlanDialog extends StatefulWidget {
  final String? gymId;
  const _AddSubscriptionPlanDialog({required this.gymId});

  @override
  State<_AddSubscriptionPlanDialog> createState() => __AddSubscriptionPlanDialogState();
}

class __AddSubscriptionPlanDialogState extends State<_AddSubscriptionPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final price = TextEditingController();
  final duration = TextEditingController();
  final features = TextEditingController();
  bool active = true;

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate() || widget.gymId == null) return;

    final f = features.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    try {
      await FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('plans').add({
        'planName': name.text,
        'price': double.parse(price.text),
        'durationMonths': int.parse(duration.text),
        'features': f,
        'isActive': active,
        'createdAt': DateTime.now(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plan added successfully!'),
          backgroundColor: AppTheme.primaryGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error adding plan: $e'),
          backgroundColor: AppTheme.alertRed,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Add Subscription Plan',
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildInput(name, 'Plan Name', theme),
                _buildInput(price, 'Price (₹)', theme, num: true),
                _buildInput(duration, 'Duration (Months)', theme, num: true),
                _buildInput(features, 'Features (comma separated)', theme),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: Text('Active Plan', style: TextStyle(color: theme.colorScheme.onSurface)),
                    value: active,
                    onChanged: (v) => setState(() => active = v),
                    activeColor: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _savePlan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Plan',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController c, String l, ThemeData theme, {bool num = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: num ? TextInputType.number : TextInputType.text,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: l,
            labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) => v == null || v.isEmpty ? 'This field is required' : null,
        ),
      );
}

extension StringCasing on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}