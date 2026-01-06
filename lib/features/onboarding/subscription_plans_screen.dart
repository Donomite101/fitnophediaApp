import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../routes/app_routes.dart';
import '../../core/app_theme.dart';
import '../../core/services/emails/email_service.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({Key? key}) : super(key: key);

  @override
  State<SubscriptionPlansScreen> createState() =>
      _GymOwnerSubscriptionScreenState();
}

class _GymOwnerSubscriptionScreenState
    extends State<SubscriptionPlansScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  String? _gymId;
  String? _gymName;
  String? _ownerName;
  Map<String, dynamic>? _selectedPlan;
  List<Map<String, dynamic>> _allPlans = [];

  @override
  void initState() {
    super.initState();
    _loadGymIdAndPlans();
  }

  /// 🔹 Load Gym and Subscription Plans from Firestore
  Future<void> _loadGymIdAndPlans() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get gym id for current owner
      final gymSnap = await _firestore
          .collection('gyms')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (gymSnap.docs.isNotEmpty) {
        final gymData = gymSnap.docs.first.data();
        _gymId = gymSnap.docs.first.id;
        _gymName = gymData['name'] ?? 'Your Gym';
        _ownerName = gymData['ownerName'] ?? user.displayName ?? 'Gym Owner';
      }

      // Fetch active plans
      final plansSnap = await _firestore
          .collection('subscription_plans')
          .where('isActive', isEqualTo: true)
          .get();

      final plans = plansSnap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      if (!mounted) return;
      setState(() {
        _allPlans = plans;
        _loading = false;
      });
    } catch (e) {
      debugPrint('⚠️ Error loading plans: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// 🔹 Simulate payment and activate subscription
  /// PROFESSIONAL & SAFE SUBSCRIPTION ACTIVATION
  Future<void> _subscribe() async {
    if (_selectedPlan == null || _gymId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a plan first'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    final plan = _selectedPlan!;
    final user = _auth.currentUser!;
    final now = Timestamp.now();
    final durationDays = plan['duration'] ?? 30;
    final endDate = Timestamp.fromDate(DateTime.now().add(Duration(days: durationDays)));
    final fakePaymentId = "PAY_${DateTime.now().millisecondsSinceEpoch}_${user.uid.substring(0, 6)}";

    // Loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoadingIndicator(),
            const SizedBox(height: 16),
            Text(
              'Activating your subscription...',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );

    try {
      // Use a batch for atomicity
      final batch = _firestore.batch();

      final gymRef = _firestore.collection('gyms').doc(_gymId);

      // 1. Update gym document (lightweight)
      batch.update(gymRef, {
        'subscriptionPlan': plan['name'],
        'subscriptionActive': true,
        'subscriptionStartDate': now,
        'subscriptionEndDate': endDate,
        'subscriptionPrice': plan['price'],
        'subscriptionDuration': durationDays,
        'subscriptionPaymentId': fakePaymentId,
        'lastSubscriptionUpdate': now,
      });

      // 2. Create full subscription record in subcollection (recommended)
      final subRef = gymRef.collection('gym_subscriptions').doc(); // auto-id
      final subscriptionData = {
        'planId': plan['id'],
        'planName': plan['name'],
        'price': plan['price'],
        'currency': 'INR',
        'durationDays': durationDays,
        'startDate': now,
        'expiryDate': endDate,
        'status': 'active',
        'paymentId': fakePaymentId,
        'paymentMethod': 'card', // or razorpay, stripe later
        'isTrial': false,
        'createdAt': now,
        'createdBy': user.uid,
        'renewalCount': 0,
      };
      batch.set(subRef, subscriptionData);

      // 3. Global subscription record (for admin dashboard)
      final globalSubRef = _firestore.collection('app_subscriptions').doc(user.uid);
      batch.set(globalSubRef, {
        ...subscriptionData,
        'gymId': _gymId,
        'gymName': _gymName,
        'ownerId': user.uid,
        'ownerEmail': user.email,
        'ownerName': _ownerName,
      }, SetOptions(merge: true));

      // 4. Add to subscription history (audit trail)
      final historyRef = gymRef.collection('subscription_history').doc();
      batch.set(historyRef, {
        ...subscriptionData,
        'type': 'new_subscription',
        'expiryDate': endDate,
        'renewedFrom': null,
      });

      // COMMIT ALL AT ONCE
      await batch.commit();

      // Send email
      await _sendSubscriptionEmail(subscriptionData, plan);

      if (!mounted) return;
      Navigator.pop(context); // close loading

      await _showFullScreenSuccess(subscriptionData);

    } catch (e, st) {
      debugPrint('Subscription error: $e\n$st');
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to activate subscription. Please try again.'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
    }
  }
  /// 🔹 Send subscription confirmation email
  Future<void> _sendSubscriptionEmail(
      Map<String, dynamic> subscriptionData, Map<String, dynamic> plan) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userEmail = user.email;
      if (userEmail == null) return;

      final startDate = (subscriptionData['startDate'] as Timestamp).toDate();
      final expiryDate = (subscriptionData['expiryDate'] as Timestamp).toDate();
      final ownerName = subscriptionData['ownerName'] ?? 'Gym Owner';
      final gymName = subscriptionData['gymName'] ?? 'Your Gym';

      await SmtpEmailService.sendPaymentSuccessEmail(
        ownerName: ownerName,
        ownerEmail: userEmail,
        gymName: gymName,
        planName: plan['name'],
        price: (plan['price'] as num).toDouble(),
        startDate: startDate,
        endDate: expiryDate,
        paymentId: subscriptionData['paymentId'],
        receiptUrl: null, // You can add receipt URL if available
      );
    } catch (e) {
      debugPrint('⚠️ Error sending email: $e');
      // Don't show error to user - email failure shouldn't block subscription
    }
  }

  /// 🔹 Show full-screen success page
  Future<void> _showFullScreenSuccess(Map<String, dynamic> subscriptionData) async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentSuccessScreen(
          subscriptionData: subscriptionData,
          onContinue: () {
            Navigator.pushReplacementNamed(context, AppRoutes.gymOwnerDashboard);
          },
        ),
      ),
    );
  }

  /// Show a fake Razorpay-like modal
  void _showFakeRazorpayUI(BuildContext ctx, Map<String, dynamic> plan) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return PaymentModal(
          plan: plan,
          onPaid: () async {
            await _subscribe();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    if (_loading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: LoadingIndicator(), // Removed color parameter
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.login, (route) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          title: Text(
            'Choose Your Plan',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
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
                'Select the perfect plan for your gym',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _allPlans.length,
                itemBuilder: (context, index) =>
                    _buildPlanCard(_allPlans[index], index, isDark, textColor),
              ),
            ),
            _buildBottomBar(isDark, textColor),
          ],
        ),
      ),
    );
  }

  /// 🔹 Enhanced Plan Card with detailed features
  Widget _buildPlanCard(Map<String, dynamic> plan, int index, bool isDark, Color textColor) {
    final isSelected = _selectedPlan?['id'] == plan['id'];
    final features = (plan['features'] as List?) ?? [];
    final duration = plan['duration'] ?? 30;
    final isYearly = duration > 90;
    final isBestValue = plan['label'] == 'Best Value';

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [
              AppTheme.primaryGreen,
              AppTheme.fitnessgreen,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isSelected ? null : (isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : isBestValue
                ? AppTheme.fitnessgreen.withOpacity(0.5)
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade400),
            width: isSelected ? 0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ]
              : [],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with plan name and badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan['name'] ?? '',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isYearly ? 'Annual Plan' : 'Monthly Plan',
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? Colors.white.withOpacity(0.9)
                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            color: AppTheme.primaryGreen,
                            size: 20,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Price section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : textColor,
                        ),
                      ),
                      Text(
                        '${plan['price']}',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : textColor,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          isYearly ? '/year' : '/month',
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected
                                ? Colors.white.withOpacity(0.8)
                                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Duration info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.2)
                          : (isDark ? Colors.grey.shade900 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$duration days access',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Divider
                  Divider(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade400),
                    thickness: 1,
                  ),

                  const SizedBox(height: 16),

                  // Features section
                  Text(
                    'Features Included:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Feature list
                  ...features.map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.2)
                                : AppTheme.primaryGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.primaryGreen,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected
                                  ? Colors.white.withOpacity(0.95)
                                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),

            // Best Value Badge
            if (isBestValue)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryGreen, AppTheme.fitnessgreen],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Best Value',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Bottom Purchase Bar
  Widget _buildBottomBar(bool isDark, Color textColor) {
    final plan = _selectedPlan;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: isDark ? Colors.grey.shade900 : Colors.grey.shade300, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: plan != null
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selected Plan',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan['name'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    '₹${plan['price']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              )
                  : Text(
                'Select a plan to continue',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomButton(
                text: 'Continue to Payment',
                onPressed: plan != null ? () {
                  _showFakeRazorpayUI(context, plan);
                } : null,
                backgroundColor:
                plan != null ? AppTheme.primaryGreen : (isDark ? Colors.grey.shade800 : Colors.grey.shade400),
                textColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateful modal widget to handle mock payment UI
class PaymentModal extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Future<void> Function() onPaid;

  const PaymentModal({
    Key? key,
    required this.plan,
    required this.onPaid,
  }) : super(key: key);

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal>
    with TickerProviderStateMixin {
  bool _processing = false;
  bool _simulateFailure = false;

  // Card fields
  final _cardNumberController =
  TextEditingController(text: '4242 4242 4242 4242');
  final _expiryController = TextEditingController(text: '12/30');
  final _cvvController = TextEditingController(text: '123');
  final _nameController = TextEditingController(text: 'John Doe');

  // Fixed order ID
  final String _orderId = "ORD${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _compact(String s) => s.replaceAll(' ', '');

  bool _validateCardInputs() {
    final number = _compact(_cardNumberController.text);
    final expiry = _expiryController.text.trim();
    final cvv = _cvvController.text.trim();
    final name = _nameController.text.trim();

    if (number.length < 12) return false;
    if (!expiry.contains('/')) return false;
    final parts = expiry.split('/');
    if (parts.length != 2) return false;
    if (cvv.length < 3) return false;
    if (name.isEmpty) return false;
    return true;
  }

  Future<void> _onPayPressed() async {
    if (!_validateCardInputs()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid card details'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _processing = true);

    await Future.delayed(const Duration(milliseconds: 1200));

    if (_simulateFailure) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment failed (simulated). Try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Close payment modal and proceed to subscription
    if (mounted) Navigator.pop(context);
    await widget.onPaid();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final price = widget.plan['price'] ?? 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, size: 14, color: Colors.green.shade400),
                            const SizedBox(width: 4),
                            Text(
                              'Secure',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Welcome text
                  Text(
                    'Secure Your\nSubscription',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Choose Card section
                  Text(
                    'Choose Card',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment methods
                  Row(
                    children: [
                      _buildPaymentMethod('Visa', Icons.credit_card, isDark, textColor),
                      const SizedBox(width: 12),
                      _buildPaymentMethod('Master card', Icons.credit_card, isDark, textColor),
                      const SizedBox(width: 12),
                      _buildPaymentMethod('Paypal', Icons.payment, isDark, textColor),
                      const SizedBox(width: 12),
                      _buildPaymentMethod('G pay', Icons.payment, isDark, textColor),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Card details section
                  Text(
                    'Card details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Card number field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.credit_card, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _cardNumberController,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '1234 5678 9012 3456',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Expiry and CVV row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MM/YY',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                ),
                              ),
                              child: TextField(
                                controller: _expiryController,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'MM/YY',
                                  hintStyle: TextStyle(
                                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CVV',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                ),
                              ),
                              child: TextField(
                                controller: _cvvController,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '123',
                                  hintStyle: TextStyle(
                                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                obscureText: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Cardholder name
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Cardholder Name',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                              ),
                            ),
                            keyboardType: TextInputType.name,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Save card checkbox
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 16,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Save credit card information for next time',
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Order summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order ID',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              _orderId,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Plan',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              widget.plan['name'] ?? '',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              '₹$price',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Test mode toggle
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.science_outlined, color: Colors.orange.shade400, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Test Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade400)),
                              Text('Simulate payment failure', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _simulateFailure,
                          onChanged: (v) => setState(() => _simulateFailure = v),
                          activeColor: Colors.orange,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Processing indicator
                  if (_processing)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LoadingIndicator(), // Removed color parameter
                          const SizedBox(height: 12),
                          Text('Processing payment...', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 14)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'Cancel',
                          onPressed: _processing ? null : () => Navigator.pop(context),
                          backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade300,
                          textColor: textColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: CustomButton(
                          text: _processing ? 'Processing...' : 'Payment\n₹$price',
                          onPressed: _processing ? null : _onPayPressed,
                          backgroundColor: AppTheme.primaryGreen,
                          textColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Security footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, size: 14, color: isDark ? Colors.grey.shade600 : Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        'Your payment information is secure and encrypted',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade600 : Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethod(String name, IconData icon, bool isDark, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen success page with Lottie animation
/// Full-screen success page with Lottie animation
class PaymentSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> subscriptionData;
  final VoidCallback onContinue;

  const PaymentSuccessScreen({
    Key? key,
    required this.subscriptionData,
    required this.onContinue,
  }) : super(key: key);

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthName(date.month)} ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Timestamp? _safeTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    // Safely extract timestamps
    final Timestamp? startTs = _safeTimestamp(subscriptionData['startDate']);
    final Timestamp? expiryTs = _safeTimestamp(subscriptionData['expiryDate']);

    if (startTs == null || expiryTs == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Subscription data error', style: TextStyle(fontSize: 18, color: textColor)),
              Text('Please contact support', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final DateTime startDate = startTs.toDate();
    final DateTime expiryDate = expiryTs.toDate();

    final planName = subscriptionData['planName'] ?? 'Premium Plan';
    final price = subscriptionData['price'] ?? 0;
    final paymentId = subscriptionData['paymentId'] ?? 'PAY_XXXXXX';
    final gymName = subscriptionData['gymName'] ?? 'Your Gym';

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 23),
            Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome to $planName Plan',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 30),

            Lottie.asset(
              'assets/animations/Payment_Success.json',
              width: 300,
              height: 300,
              fit: BoxFit.contain,
              repeat: false,
              animate: true,        // starts automatically
              frameRate: FrameRate.max,  // smooth animation
            ),

            const SizedBox(height: 20),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildDetailRow('Gym', gymName, isDark, textColor),
                  const SizedBox(height: 10),
                  _buildDetailRow('Plan', planName, isDark, textColor),
                  const SizedBox(height: 10),
                  _buildDetailRow('Amount Paid', '₹$price', isDark, textColor),
                  const SizedBox(height: 10),
                  _buildDetailRow('Start Date', _formatDate(startDate), isDark, textColor),
                  const SizedBox(height: 10),
                  _buildDetailRow('Expiry Date', _formatDate(expiryDate), isDark, textColor),
                  const SizedBox(height: 10),
                  _buildDetailRow('Payment ID', paymentId, isDark, textColor),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                height: 56,
                child: CustomButton(
                  text: 'Continue to Dashboard',
                  onPressed: onContinue,
                  backgroundColor: AppTheme.primaryGreen,
                  textColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'A confirmation email has been sent to your registered email',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
  Widget _buildDetailRow(String label, String value, bool isDark, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 13, // Slightly smaller font
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 13, // Slightly smaller font
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
