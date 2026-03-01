import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/app_theme.dart';

class PaymentAnalysisScreen extends StatefulWidget {
  final String? gymId;
  const PaymentAnalysisScreen({Key? key, this.gymId}) : super(key: key);

  @override
  State<PaymentAnalysisScreen> createState() => _PaymentAnalysisScreenState();
}

class _PaymentAnalysisScreenState extends State<PaymentAnalysisScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;

  double _totalRevenue = 0;
  double _totalPayouts = 0;
  int _touchedIndex = -1;

  Map<String, double> _revenueByPlan = {};
  Map<String, double> _payoutsByPerson = {};
  double _renewalRate = 0;
  double _churnRate = 0;
  int _activeMembers = 0;
  int _totalMembers = 0;

  static const List<Color> _palette = [
    Color(0xFF00C853),
    Color(0xFF00E676),
    Color(0xFF1B5E20),
    Color(0xFF69F0AE),
    Color(0xFFFFB347),
    Color(0xFF26C6DA),
    Color(0xFFFF6B6B),
  ];

  @override
  void initState() {
    super.initState();
    _fetchAnalysisData();
  }

  Future<void> _fetchAnalysisData() async {
    if (widget.gymId == null) return;
    try {
      // ── Member payments ──────────────────────────────────────
      final paymentsSnap = await _firestore
          .collection('gyms')
          .doc(widget.gymId)
          .collection('payments')
          .get();

      double totalRev = 0;
      for (var doc in paymentsSnap.docs) {
        totalRev += ((doc.data()['amount'] ?? 0) as num).toDouble();
      }

      // ── Members & plan revenue ───────────────────────────────
      final membersSnap = await _firestore
          .collection('gyms')
          .doc(widget.gymId)
          .collection('members')
          .get();

      Map<String, double> planRevenue = {};
      int activeCount = 0;
      int expiredCount = 0;
      int renewedCount = 0;

      for (var doc in membersSnap.docs) {
        final data = doc.data();
        final planName = (data['subscriptionPlan'] ?? 'General') as String;
        final price = ((data['subscriptionPrice'] ?? 0) as num).toDouble();
        final status = (data['subscriptionStatus'] ?? data['status'] ?? '')
            .toString()
            .toLowerCase();

        if (status == 'active' || status == 'paid') {
          planRevenue[planName] = (planRevenue[planName] ?? 0) + price;
          activeCount++;
          if (data['isRenewed'] == true) renewedCount++;
        } else if (status == 'expired' || status == 'inactive') {
          expiredCount++;
        }
      }

      // ── Staff + Trainer Payouts ──────────────────────────────
      final trainerSnap = await _firestore
          .collection('trainer_payments')
          .where('gymId', isEqualTo: widget.gymId)
          .get();
      final staffSnap = await _firestore
          .collection('staff_payments')
          .where('gymId', isEqualTo: widget.gymId)
          .get();

      Map<String, double> payoutsMap = {};
      double totalPay = 0;

      for (var doc in [...trainerSnap.docs, ...staffSnap.docs]) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        if (status == 'cancelled') continue;
        final name = (data['name'] ?? 'Unknown') as String;
        final amount = ((data['amount'] ?? 0) as num).toDouble();
        final isTrainer = trainerSnap.docs.any((d) => d.id == doc.id);
        final label = isTrainer ? '$name\n(Trainer)' : '$name\n(Staff)';
        payoutsMap[label] = (payoutsMap[label] ?? 0) + amount;
        totalPay += amount;
      }

      final totalBase = activeCount + expiredCount;

      if (mounted) {
        setState(() {
          _totalRevenue = totalRev > 0
              ? totalRev
              : planRevenue.values.fold(0, (a, b) => a + b);
          _totalPayouts = totalPay;
          _revenueByPlan = planRevenue;
          _payoutsByPerson = payoutsMap;
          _renewalRate =
              totalBase > 0 ? (renewedCount / totalBase) * 100 : 0;
          _churnRate =
              totalBase > 0 ? (expiredCount / totalBase) * 100 : 0;
          _activeMembers = activeCount;
          _totalMembers = membersSnap.docs.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching analysis: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Gradient Header SliverAppBar ────────────────
                SliverAppBar(
                  expandedHeight: 240,
                  pinned: true,
                  backgroundColor: AppTheme.primaryGreen,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryGreen, Color(0xFF1B5E20)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Finance Analytics',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70, fontSize: 12, letterSpacing: 1)),
                              const SizedBox(height: 2),
                              Text('₹${_totalRevenue.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -1)),
                              Text('Total Revenue collected',
                                  style: TextStyle(color: Colors.white60, fontSize: 11)),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _headerStat('Net Profit',
                                      '₹${(_totalRevenue - _totalPayouts).toStringAsFixed(0)}',
                                      AppTheme.primaryGreen),
                                  const SizedBox(width: 20),
                                  _headerStat('Payouts',
                                      '₹${_totalPayouts.toStringAsFixed(0)}',
                                      Colors.orangeAccent),
                                  const SizedBox(width: 20),
                                  _headerStat('Members',
                                      '$_activeMembers/$_totalMembers',
                                      Colors.lightBlueAccent),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Renewal & Churn rate cards ───────────
                        Row(
                          children: [
                            Expanded(child: _buildRateCard(
                              'Renewal Rate',
                              _renewalRate,
                              AppTheme.primaryGreen,
                              Icons.autorenew_rounded,
                              theme,
                            )),
                            const SizedBox(width: 14),
                            Expanded(child: _buildRateCard(
                              'Churn Rate',
                              _churnRate,
                              Colors.redAccent,
                              Icons.person_remove_outlined,
                              theme,
                            )),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // ── Revenue Breakdown donut ──────────────
                        _sectionHeader('Revenue by Plan', Iconsax.chart),
                        const SizedBox(height: 16),
                        _buildDonutChart(theme),
                        const SizedBox(height: 32),

                        // ── Plan progress bars ───────────────────
                        _sectionHeader('Plan Breakdown', Iconsax.receipt_item),
                        const SizedBox(height: 14),
                        _buildPlanBars(theme),
                        const SizedBox(height: 32),

                        // ── Staff / Trainer Payouts ──────────────
                        _sectionHeader('Staff & Trainer Payouts', Iconsax.wallet_money),
                        const SizedBox(height: 14),
                        _buildPayoutCards(theme),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Widget _headerStat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: Colors.white54, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value,
          style: GoogleFonts.poppins(
              color: color, fontSize: 14, fontWeight: FontWeight.bold)),
    ],
  );

  Widget _sectionHeader(String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 18, color: AppTheme.primaryGreen),
      const SizedBox(width: 8),
      Text(title,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
    ],
  );

  Widget _buildRateCard(
      String label, double value, Color color, IconData icon, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  value: value / 100,
                  backgroundColor: color.withOpacity(0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeWidth: 4.5,
                ),
              ),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 15),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart(ThemeData theme) {
    if (_revenueByPlan.isEmpty) {
      return _emptyState(theme, 'No plan revenue data yet');
    }

    final entries = _revenueByPlan.entries.toList();
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: List.generate(entries.length, (i) {
                      final touched = i == _touchedIndex;
                      final pct = total > 0 ? entries[i].value / total * 100 : 0;
                      return PieChartSectionData(
                        color: _palette[i % _palette.length],
                        value: entries[i].value,
                        title: touched ? '${pct.toStringAsFixed(1)}%' : '',
                        radius: touched ? 68 : 56,
                        titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      );
                    }),
                    centerSpaceRadius: 52,
                    sectionsSpace: 4,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response?.touchedSection == null) {
                            _touchedIndex = -1;
                          } else {
                            _touchedIndex =
                                response!.touchedSection!.touchedSectionIndex;
                          }
                        });
                      },
                    ),
                  ),
                ),
                // Center label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withOpacity(0.4))),
                    Text('₹${total.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: List.generate(entries.length, (i) {
              final pct = total > 0 ? entries[i].value / total * 100 : 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: _palette[i % _palette.length],
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${entries[i].key} (${pct.toStringAsFixed(0)}%)',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.75)),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanBars(ThemeData theme) {
    if (_revenueByPlan.isEmpty) return _emptyState(theme, 'No plans to show');

    final entries = _revenueByPlan.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
      ),
      child: Column(
        children: List.generate(entries.length, (i) {
          final fraction = maxVal > 0 ? entries[i].value / maxVal : 0.0;
          final color = _palette[i % _palette.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(entries[i].key,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: theme.colorScheme.onSurface)),
                      ],
                    ),
                    Text('₹${entries[i].value.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: color)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction.toDouble(),
                    minHeight: 8,
                    backgroundColor: color.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPayoutCards(ThemeData theme) {
    if (_payoutsByPerson.isEmpty) {
      return _emptyState(theme, 'No payouts recorded yet');
    }

    final entries = _payoutsByPerson.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = entries.first.value;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(child: Text('Name & Role',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.4)))),
                Text('Amount',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.4))),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(entries.length, (i) {
            final nameParts = entries[i].key.split('\n');
            final name = nameParts[0];
            final role = nameParts.length > 1 ? nameParts[1] : '';
            final fraction = maxVal > 0 ? entries[i].value / maxVal : 0.0;
            final isTrainer = role.contains('Trainer');
            final color = isTrainer ? const Color(0xFF2575FC) : Colors.orange;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: color.withOpacity(0.12),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                role.replaceAll('(', '').replaceAll(')', ''),
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: color),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text('₹${entries[i].value.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction.toDouble(),
                      minHeight: 4,
                      backgroundColor: color.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  if (i < entries.length - 1)
                    Divider(height: 24, color: theme.dividerColor.withOpacity(0.08)),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme, String msg) => Container(
    height: 100,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Iconsax.chart_fail, color: theme.colorScheme.onSurface.withOpacity(0.25), size: 28),
        const SizedBox(height: 8),
        Text(msg,
            style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 13)),
      ],
    ),
  );
}
