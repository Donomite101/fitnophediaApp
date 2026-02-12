import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../routes/app_routes.dart';
import '../../../core/app_theme.dart';

class MemberSubscriptionScreen extends StatefulWidget {
  const MemberSubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<MemberSubscriptionScreen> createState() => _MemberSubscriptionScreenState();
}

class _MemberSubscriptionScreenState extends State<MemberSubscriptionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _selectedPlan;

  String? _gymId;
  String? _memberId;
  String? _memberName;
  String? _memberEmail;

  // Current subscription state (local)
  bool _hasActiveSubscription = false;
  Timestamp? _currentEndDate;
  String? _currentPlanName;
  int _renewalCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _redirectToLogin();
        return;
      }

      // Load user doc (primary user doc is source of truth for user-level data)
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User profile not found')));
        Navigator.pop(context);
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      _gymId = userData['gymId'] as String?;
      _memberId = user.uid;
      _memberName = userData['name'] as String? ?? user.displayName ?? 'Member';
      _memberEmail = user.email;

      if (_gymId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gym association not found')));
        Navigator.pop(context);
        return;
      }

      // Load active plans from gyms/{gymId}/plans
      final plansSnap = await _firestore
          .collection('gyms')
          .doc(_gymId)
          .collection('plans')
          .where('isActive', isEqualTo: true)
          .get();

      final plans = plansSnap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();

      // Determine current subscription using userDoc (and fallback to gyms/{gymId}/members)
      final now = Timestamp.now();
      Timestamp? subscriptionEndDate = userData['subscriptionEndDate'] as Timestamp?;
      final subscriptionStatus = (userData['subscriptionStatus'] ?? '').toString().toLowerCase();
      final hasOngoingSubscription = userData['hasOngoingSubscription'] as bool? ?? false;

      // If user doc doesn't have end date or status, try gyms/{gymId}/members/{memberId}
      if ((subscriptionEndDate == null || subscriptionStatus.isEmpty) && _gymId != null) {
        final memberSnap = await _firestore
            .collection('gyms')
            .doc(_gymId)
            .collection('members')
            .doc(_memberId)
            .get();

        if (memberSnap.exists) {
          final m = memberSnap.data() as Map<String, dynamic>;
          subscriptionEndDate = subscriptionEndDate ?? (m['subscriptionEndDate'] as Timestamp?);
        }
      }

      _hasActiveSubscription = subscriptionEndDate != null &&
          subscriptionEndDate.compareTo(now) > 0 &&
          (subscriptionStatus == 'active' || hasOngoingSubscription);

      _currentEndDate = subscriptionEndDate;
      _currentPlanName = userData['subscriptionPlan']?.toString();
      _renewalCount = (userData['renewalCount'] ?? 0) as int;

      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading subscription data: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load plans: $e')));
    }
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
    });
  }

  /// activateOrRenewSubscription now updates both:
  /// - users/{memberId}
  /// - gyms/{gymId}/members/{memberId}
  /// and creates payment records + payment_requests + notifications for Cash.
  Future<void> _activateOrRenewSubscription(String paymentMethod) async {
    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a plan first')));
      return;
    }
    if (_gymId == null || _memberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User or gym data missing')));
      return;
    }

    setState(() => _isLoading = true);

    final plan = Map<String, dynamic>.from(_selectedPlan!);

    // Defensive parsing for price
    double price;
    try {
      final rawPrice = plan['price'];
      if (rawPrice == null) {
        price = 0.0;
      } else if (rawPrice is num) {
        price = rawPrice.toDouble();
      } else {
        price = double.tryParse(rawPrice.toString()) ?? 0.0;
      }
    } catch (_) {
      price = 0.0;
    }

    // Defensive parsing for duration (days)
    int durationDays;
    try {
      final rawDur = plan['duration'];
      if (rawDur == null) {
        durationDays = 30;
      } else if (rawDur is int) {
        durationDays = rawDur;
      } else if (rawDur is num) {
        durationDays = rawDur.toInt();
      } else {
        durationDays = int.tryParse(rawDur.toString()) ?? 30;
      }
      if (durationDays <= 0) durationDays = 30;
    } catch (_) {
      durationDays = 30;
    }

    final now = DateTime.now();
    // compute base for extension
    DateTime base = now;
    if (_hasActiveSubscription && _currentEndDate != null) {
      try {
        base = _currentEndDate!.toDate();
      } catch (_) {
        base = now;
      }
    }

    final newEndDateRaw = base.add(Duration(days: durationDays));
    final newEndTimestamp = Timestamp.fromDate(newEndDateRaw);

    final bool isOnline = paymentMethod.toLowerCase() == 'online';
    final String resultingStatus = isOnline ? 'active' : 'pending_approval';
    final bool countedInRevenue = isOnline;

    final userRef = _firestore.collection('users').doc(_memberId);
    final memberRef = _firestore.collection('gyms').doc(_gymId).collection('members').doc(_memberId);
    final userPaymentsRef = userRef.collection('member_payments').doc();

    final Map<String, dynamic> subscriptionPayload = {
      'hasOngoingSubscription': true,
      'subscriptionStatus': resultingStatus,
      'subscriptionPlan': plan['name'] ?? plan['planName'] ?? 'Plan',
      'subscriptionPrice': price,
      'subscriptionStartDate': FieldValue.serverTimestamp(),
      'subscriptionEndDate': newEndTimestamp,
      'paymentType': isOnline ? 'Online' : 'Cash',
      'countedInRevenue': countedInRevenue,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastRenewedAt': FieldValue.serverTimestamp(),
      'renewalCount': FieldValue.increment(1),
    };

    final paymentDocData = <String, dynamic>{
      'amount': price,
      'planName': plan['name'] ?? plan['planName'],
      'paymentMethod': paymentMethod.toLowerCase(),
      'paymentDate': FieldValue.serverTimestamp(),
      'status': isOnline ? 'paid' : 'pending',
      'type': _hasActiveSubscription ? 'renewal' : 'new_subscription',
      'previousEndDate': _currentEndDate,
      'newEndDate': newEndTimestamp,
      'collectedBy': isOnline ? (_auth.currentUser?.displayName ?? 'Member') : 'Pending Approval',
      'receiptNumber': 'REC${DateTime.now().millisecondsSinceEpoch}',
      'createdAt': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    
    // Only activate subscription immediately for Online payments
    if (isOnline) {
      batch.set(userRef, subscriptionPayload, SetOptions(merge: true));
      batch.set(memberRef, subscriptionPayload, SetOptions(merge: true));
    }
    
    // Always record the transaction attempt
    batch.set(userPaymentsRef, paymentDocData);

    try {
      if (!isOnline) {
        final requestRef = _firestore.collection('gyms').doc(_gymId).collection('payment_requests').doc();
        batch.set(requestRef, {
          'memberId': _memberId,
          'memberName': _memberName,
          'memberEmail': _memberEmail,
          'planName': plan['name'] ?? plan['planName'],
          'amount': price,
          'durationDays': durationDays,
          'method': 'Cash',
          'status': 'Pending',
          'isRenewal': _hasActiveSubscription,
          'requestedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!isOnline) {
        await _firestore.collection('notifications').add({
          'type': 'cash_payment_request',
          'title': 'New Cash Payment Pending',
          'message': '$_memberName paid ₹${price.toStringAsFixed(0)} in cash\nPlan: ${plan['name'] ?? plan['planName']}\nTap to approve →',
          'gymId': _gymId,
          'memberId': _memberId,
          'memberName': _memberName,
          'amount': price,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'priority': 'high',
        });
      }

      // reload and navigate
      await _loadData();
      if (isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Subscription activated!'), backgroundColor: AppTheme.primaryGreen));
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.memberDashboard, (r) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Subscription request created — awaiting owner approval'), backgroundColor: Colors.orange));
        Navigator.pushReplacementNamed(context, AppRoutes.awaitingApproval, arguments: {'gymId': _gymId, 'memberId': _memberId});
      }
    } catch (e, st) {
      debugPrint('Subscription error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error processing subscription: $e'), backgroundColor: AppTheme.alertRed));
      setState(() => _isLoading = false);
    }
  }


  void _showPaymentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _hasActiveSubscription ? "Renew Subscription" : "Choose Payment Method",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Icon(Icons.credit_card, color: cs.primary),
                title: const Text("Pay Online"),
                subtitle: Text(_hasActiveSubscription ? "Instant renewal" : "Instant activation"),
                onTap: () {
                  Navigator.pop(context);
                  _activateOrRenewSubscription('Online');
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.money, color: Colors.orange),
                title: const Text("Pay Cash at Gym"),
                subtitle: const Text("Activation after owner approval"),
                onTap: () {
                  Navigator.pop(context);
                  _activateOrRenewSubscription('Cash');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(_hasActiveSubscription ? 'Renew Subscription' : 'Choose Your Plan'),
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: textColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.login, (route) => false),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Select the perfect plan for your fitness journey',
              style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          if (_hasActiveSubscription && _currentEndDate != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green)),
              child: Column(
                children: [
                  const Text('Active Until', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 8),
                  Text('${_currentEndDate!.toDate().day}/${_currentEndDate!.toDate().month}/${_currentEndDate!.toDate().year}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Plan: $_currentPlanName • Renewals: $_renewalCount'),
                ],
              ),
            ),

          Expanded(
            child: _plans.isEmpty
                ? Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.content_paste_off_rounded, size: 100, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('No plans available', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: textColor)),
                const SizedBox(height: 8),
                Text('Please contact your gym for available plans', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
              ]),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _plans.length,
              itemBuilder: (context, index) => _buildPlanCard(_plans[index], index, isDark, textColor),
            ),
          ),

          if (_selectedPlan != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0A0A) : Colors.grey.shade50,
                border: Border(top: BorderSide(color: isDark ? Colors.grey.shade900 : Colors.grey.shade300, width: 1)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(_hasActiveSubscription ? 'Renew with:' : 'Subscribe to:', style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(_selectedPlan!['name'] ?? '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                        Text('₹${_selectedPlan!['price']} • ${_selectedPlan!['duration'] ?? 30} days', style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _showPaymentOptions,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: Text(_hasActiveSubscription ? 'Renew Now' : 'Subscribe Now', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildPlanCard(Map<String, dynamic> plan, int index, bool isDark, Color textColor) {
    final isSelected = _selectedPlan?['id'] == plan['id'];
    final features = (plan['features'] as List?) ?? [];
    final duration = plan['duration'] ?? 30;
    final isYearly = duration > 90;
    final isBestValue = (plan['label']?.toString().toLowerCase() ?? '') == 'best value';

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.fitnessgreen], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: isSelected ? null : (isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : isBestValue ? AppTheme.fitnessgreen.withOpacity(0.5) : (isDark ? Colors.grey.shade800 : Colors.grey.shade400), width: isSelected ? 0 : 1.5),
          boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))] : [],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(plan['name'] ?? '', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : textColor)),
                    const SizedBox(height: 4),
                    Text(isYearly ? 'Annual Plan' : 'Monthly Plan', style: TextStyle(fontSize: 13, color: isSelected ? Colors.white.withOpacity(0.9) : (isDark ? Colors.grey.shade400 : Colors.grey.shade600))),
                  ])),
                  if (isSelected)
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.check, color: AppTheme.primaryGreen, size: 20)),
                ]),
                const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('₹', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : textColor)),
                  Text('${plan['price']}', style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : textColor, height: 1.1)),
                  const SizedBox(width: 6),
                  Padding(padding: const EdgeInsets.only(top: 14), child: Text(isYearly ? '/year' : '/month', style: TextStyle(fontSize: 14, color: isSelected ? Colors.white.withOpacity(0.8) : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)))),
                ]),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isSelected ? Colors.white.withOpacity(0.2) : (isDark ? Colors.grey.shade900 : Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Text('$duration days access', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700)))),
                const SizedBox(height: 20),
                Divider(color: isSelected ? Colors.white.withOpacity(0.2) : (isDark ? Colors.grey.shade800 : Colors.grey.shade400), thickness: 1),
                const SizedBox(height: 16),
                Text('Features Included:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? Colors.white.withOpacity(0.9) : (isDark ? Colors.grey.shade300 : Colors.grey.shade700))),
                const SizedBox(height: 12),
                ...features.map((feature) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(margin: const EdgeInsets.only(top: 2), padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: isSelected ? Colors.white.withOpacity(0.2) : AppTheme.primaryGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.check_circle, color: isSelected ? Colors.white : AppTheme.primaryGreen, size: 16)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(feature.toString(), style: TextStyle(fontSize: 14, color: isSelected ? Colors.white.withOpacity(0.95) : (isDark ? Colors.grey.shade300 : Colors.grey.shade700), height: 1.4))),
                ]))),
              ]),
            ),
            if (isBestValue)
              Positioned(top: 16, right: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.fitnessgreen]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))]), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.star, color: Colors.white, size: 14), const SizedBox(width: 4), Text('Best Value', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))]))),
          ],
        ),
      ),
    );
  }
}
