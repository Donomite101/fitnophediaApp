import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../onboarding/subscription_plans_screen.dart';
import '../gym_owner_dashboard.dart';

class GymOwnerSubscriptionScreen extends StatefulWidget {
  const GymOwnerSubscriptionScreen({Key? key}) : super(key: key);

  @override
  State<GymOwnerSubscriptionScreen> createState() =>
      _GymOwnerSubscriptionScreenState();
}

class _GymOwnerSubscriptionScreenState
    extends State<GymOwnerSubscriptionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _currentSubscription;
  List<Map<String, dynamic>> _availablePlans = [];
  bool _isLoading = true;
  bool _showSuccess = false;
  String? _successPlanName;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    try {
      final subscriptionDoc = await _firestore
          .collection('app_subscriptions')
          .doc(_currentUser?.uid)
          .get();

      if (!mounted) return;

      if (subscriptionDoc.exists) {
        setState(() {
          _currentSubscription = subscriptionDoc.data() as Map<String, dynamic>?;
        });
      }

      final plansSnapshot = await _firestore
          .collection('subscription_plans')
          .where('type', isEqualTo: 'gym_owner')
          .get();

      if (!mounted) return;

      setState(() {
        _availablePlans = plansSnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading subscription data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // SIMPLE PAYMENT FLOW
  Future<void> _subscribeToPlan(Map<String, dynamic> plan) async {
    try {
      final ownerId = _currentUser?.uid;
      if (ownerId == null) return;

      final duration = plan['duration'] ?? 30;
      final startDate = Timestamp.now();
      final endDate = Timestamp.fromDate(DateTime.now().add(Duration(days: duration)));

      // Add subscription record
      await _firestore.collection('app_subscriptions').doc(ownerId).set({
        'planName': plan['name'],
        'price': plan['price'],
        'status': 'active',
        'startDate': startDate,
        'expiryDate': endDate,
        'ownerId': ownerId,
        'createdAt': Timestamp.now(),
      });

      // Add payment record
      await _firestore.collection('payments').add({
        'gymOwnerId': ownerId,
        'amount': plan['price'],
        'paymentDate': Timestamp.now(),
        'paymentMethod': 'Card',
        'type': 'app_subscription',
        'status': 'completed',
        'planName': plan['name'],
      });

      // Show success screen
      if (mounted) {
        setState(() {
          _showSuccess = true;
          _successPlanName = plan['name'];
        });
      }

    } catch (e) {
      debugPrint('Subscription error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subscription failed: $e')),
        );
      }
    }
  }

  // SUCCESS SCREEN
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/success.json',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              Text(
                'Subscription Successful!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _successPlanName ?? 'Plan',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Redirecting to dashboard...',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Auto redirect after success
    if (_showSuccess) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const GymOwnerDashboard()),
          );
        }
      });
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'My Subscription',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade700, Colors.green.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.green.shade700))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentSubscriptionCard(),
            const SizedBox(height: 32),
            _buildAvailablePlans(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSubscriptionCard() {
    if (_currentSubscription == null) {
      return _buildNoSubscriptionCard();
    }

    final planName = _currentSubscription!['planName'] ?? 'No Plan';
    final status = _currentSubscription!['status'] ?? 'inactive';
    final expiryDate = _currentSubscription!['expiryDate'] != null
        ? (_currentSubscription!['expiryDate'] as Timestamp).toDate()
        : null;
    final price = _currentSubscription!['price']?.toDouble() ?? 0.0;
    final daysLeft = expiryDate != null ? expiryDate.difference(DateTime.now()).inDays : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Plan',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    planName,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      status == 'active' ? Icons.check_circle : Icons.error_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$price',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  '/ month',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (expiryDate != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      daysLeft > 0 ? '$daysLeft days remaining' : 'Plan Expired',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${expiryDate.day}/${expiryDate.month}/${expiryDate.year}',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // DIRECT REDIRECT TO SUBSCRIPTION PLANS SCREEN
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionPlansScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade900,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                "Renew Subscription",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSubscriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.workspace_premium_outlined,
              size: 48,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No Active Subscription",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Unlock premium features by subscribing to a plan.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // DIRECT REDIRECT TO SUBSCRIPTION PLANS SCREEN
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionPlansScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                "View Plans",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailablePlans() {
    if (_availablePlans.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Plans',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        ..._availablePlans.map((plan) => _buildPlanCard(plan)).toList(),
      ],
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan['name'] ?? 'Plan',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${plan['duration']} Days",
                    style: GoogleFonts.poppins(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "₹${plan['price']}",
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              plan['description'] ?? 'No description available.',
              style: GoogleFonts.poppins(
                color: Colors.black54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _subscribeToPlan(plan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Subscribe Now",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}