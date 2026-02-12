// member_subscription_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/app_theme.dart';
import '../../../routes/app_routes.dart';

class MemberSubscriptionDetailsScreen extends StatefulWidget {
  final String gymId;
  final String memberId;

  const MemberSubscriptionDetailsScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  State<MemberSubscriptionDetailsScreen> createState() => _MemberSubscriptionDetailsScreenState();
}

class _MemberSubscriptionDetailsScreenState extends State<MemberSubscriptionDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  Map<String, dynamic>? _subscriptionData;
  Map<String, dynamic>? _memberData;
  List<Map<String, dynamic>> _paymentHistory = [];
  
  // Subscription details
  DateTime? _startDate;
  DateTime? _endDate;
  String? _planName;
  double? _price;
  String? _status;
  String? _paymentType;
  int _renewalCount = 0;
  bool _isAutoRenew = false;

  // Days remaining calculation
  int _daysRemaining = 0;
  bool _canRenew = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionDetails();
  }

  // ✅ FIXED: Added missing method implementation
  Future<void> _loadSubscriptionDetails() async {
    setState(() => _isLoading = true);

    try {
      // Get member document
      final memberDoc = await _firestore
          .collection('gyms')
          .doc(widget.gymId)
          .collection('members')
          .doc(widget.memberId)
          .get();

      // Get user document for additional subscription data
      final userDoc = await _firestore
          .collection('users')
          .doc(widget.memberId)
          .get();

      if (memberDoc.exists) {
        final memberData = memberDoc.data()!;
        final userData = userDoc.data() ?? {};

        debugPrint('🔍 SubDetails: Raw Member Data: $memberData');
        debugPrint('🔍 SubDetails: Raw User Data: ${userData.toString()}');

        _subscriptionData = {
          ...memberData,
          ...userData,
        };
        
        _memberData = memberData;

        // Parse subscription dates
        if (_subscriptionData!['subscriptionEndDate'] != null) {
          _endDate = (_subscriptionData!['subscriptionEndDate'] as Timestamp).toDate();
          debugPrint('🔍 SubDetails: Parsed End Date: $_endDate');
        } else {
          debugPrint('🔍 SubDetails: End Date is NULL');
        }
        
        if (_subscriptionData!['subscriptionStartDate'] != null) {
          _startDate = (_subscriptionData!['subscriptionStartDate'] as Timestamp).toDate();
        }

        // Get plan name - try multiple field names
        _planName = _subscriptionData!['subscriptionPlan'] ?? 
                    _subscriptionData!['planName'] ?? 
                    'No Active Plan';
        
        // Get price
        _price = (_subscriptionData!['subscriptionPrice'] ?? 
                  _subscriptionData!['price'] ?? 
                  0).toDouble();
        
        // Get status
        _status = _subscriptionData!['subscriptionStatus']?.toString().toLowerCase() ?? 
                  _subscriptionData!['status']?.toString().toLowerCase() ?? 
                  'inactive';
        debugPrint('🔍 SubDetails: Initial Parsed Status: $_status');
        
        // Check hasOngoingSubscription flag
        final hasOngoing = _subscriptionData!['hasOngoingSubscription'] as bool? ?? false;
        debugPrint('🔍 SubDetails: hasOngoingSubscription: $hasOngoing');
        
        if (hasOngoing && _status == 'inactive') {
          _status = 'active';
          debugPrint('🔍 SubDetails: Status forced to ACTIVE due to hasOngoingSubscription flag');
        }

        _paymentType = _subscriptionData!['paymentType'] ?? 
                       _subscriptionData!['paymentMethod'] ?? 
                       'Not specified';
        _renewalCount = _subscriptionData!['renewalCount'] ?? 0;
        _isAutoRenew = _subscriptionData!['autoRenew'] ?? false;

        // Calculate days remaining
        if (_endDate != null) {
          final now = DateTime.now();
          _daysRemaining = _endDate!.difference(now).inDays;
          _canRenew = _daysRemaining <= 5 && _daysRemaining >= 0;
          debugPrint('🔍 SubDetails: Days Remaining: $_daysRemaining');
        }
        
        debugPrint('🔍 SubDetails: Final Status: $_status');

        // Load payment history
        await _loadPaymentHistory();
      } else {
        debugPrint('❌ SubDetails: Member Document does not exist for ID: ${widget.memberId}');
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading subscription details: $e');
      setState(() => _isLoading = false);
    }
  }

  // ✅ FIXED: Removed the extra semicolon and fixed syntax
  Future<void> _loadPaymentHistory() async {
    try {
      final paymentsSnapshot = await _firestore
          .collection('users')
          .doc(widget.memberId)
          .collection('member_payments')
          .orderBy('paymentDate', descending: true)
          .limit(10)
          .get();

      _paymentHistory = paymentsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Map<String, dynamic>.from(data);
      }).toList();
    } catch (e) {
      debugPrint('Error loading payment history: $e');
    }
  }

  Future<void> _renewSubscription() async {
    // Navigate to subscription selection screen
    Navigator.pushNamed(
      context,
      AppRoutes.memberSubscription,
      arguments: {
        'gymId': widget.gymId,
        'memberId': widget.memberId,
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _getStatusColor() {
    if (_status?.toLowerCase() == 'active') {
      if (_endDate != null && _endDate!.isBefore(DateTime.now())) {
        return 'Expired';
      }
      return _daysRemaining <= 5 ? 'Expiring Soon' : 'Active';
    } else if (_status?.toLowerCase() == 'pending_approval') {
      return 'Pending Approval';
    } else if (_status?.toLowerCase() == 'expired' || (_endDate != null && _endDate!.isBefore(DateTime.now()))) {
      return 'Expired';
    }
    return 'Inactive';
  }

  Color _getStatusTextColor() {
    if (_status?.toLowerCase() == 'active') {
      if (_endDate != null && _endDate!.isBefore(DateTime.now())) {
        return Colors.red;
      }
      return _daysRemaining <= 5 ? Colors.orange : Colors.green;
    } else if (_status?.toLowerCase() == 'pending_approval') {
      return Colors.orange;
    } else if (_status?.toLowerCase() == 'expired' || (_endDate != null && _endDate!.isBefore(DateTime.now()))) {
      return Colors.red;
    }
    return Colors.grey;
  }

  IconData _getStatusIcon() {
    if (_status?.toLowerCase() == 'active') {
      if (_endDate != null && _endDate!.isBefore(DateTime.now())) {
        return Iconsax.close_circle;
      }
      return _daysRemaining <= 5 ? Iconsax.timer : Iconsax.tick_circle;
    } else if (_status?.toLowerCase() == 'pending_approval') {
      return Iconsax.clock;
    } else if (_status?.toLowerCase() == 'expired' || (_endDate != null && _endDate!.isBefore(DateTime.now()))) {
      return Iconsax.close_circle;
    }
    return Iconsax.info_circle;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text('Subscription Details', style: GoogleFonts.poppins()),
          backgroundColor: backgroundColor,
          elevation: 0,
          foregroundColor: textColor,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryGreen),
              const SizedBox(height: 16),
              Text('Loading subscription details...', 
                style: GoogleFonts.poppins(color: textColor.withOpacity(0.7))
              ),
            ],
          ),
        ),
      );
    }

    final hasActiveSubscription = _status?.toLowerCase() == 'active' && 
                                 _endDate != null && 
                                 _endDate!.isAfter(DateTime.now());

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('My Subscription', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: textColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Status Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasActiveSubscription 
                      ? [AppTheme.primaryGreen, AppTheme.fitnessgreen]
                      : [Colors.grey.shade800, Colors.grey.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (hasActiveSubscription ? AppTheme.primaryGreen : Colors.grey).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _getStatusIcon(),
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStatusColor(),
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _planName ?? 'No Active Plan',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (hasActiveSubscription) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Valid Until',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(_endDate),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _daysRemaining <= 5 
                                ? Colors.orange 
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            _daysRemaining <= 0 
                                ? 'Expired'
                                : '$_daysRemaining days left',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Renew Button - Only active when 5 days or less remaining
            if (hasActiveSubscription && _canRenew) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _renewSubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Iconsax.refresh),
                        const SizedBox(width: 12),
                        Text(
                          'Renew Subscription',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // No active subscription or expired
            if (!hasActiveSubscription) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Iconsax.note_remove,
                      size: 48,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Active Subscription',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You don\'t have an active subscription. Subscribe now to access gym facilities.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _renewSubscription,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Subscribe Now',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Subscription Details Card
            _buildDetailsCard(isDark, textColor),

            // Payment History Card
            if (_paymentHistory.isNotEmpty)
              _buildPaymentHistoryCard(isDark, textColor),

            // Auto-renewal toggle (if applicable)
            if (hasActiveSubscription)
              _buildAutoRenewalCard(isDark, textColor),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(bool isDark, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Iconsax.document_text,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Subscription Details',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildDetailRow(
            'Plan Name',
            _planName ?? 'N/A',
            isDark,
            textColor,
          ),
          _buildDetailRow(
            'Price',
            _price != null && _price! > 0 ? '₹${_price!.toStringAsFixed(0)}' : 'N/A',
            isDark,
            textColor,
          ),
          _buildDetailRow(
            'Start Date',
            _formatDate(_startDate),
            isDark,
            textColor,
          ),
          _buildDetailRow(
            'End Date',
            _formatDate(_endDate),
            isDark,
            textColor,
          ),
          _buildDetailRow(
            'Payment Method',
            _paymentType ?? 'N/A',
            isDark,
            textColor,
          ),
          _buildDetailRow(
            'Renewal Count',
            '$_renewalCount ${_renewalCount == 1 ? 'time' : 'times'}',
            isDark,
            textColor,
          ),
          _buildDetailRow(
            'Status',
            _status?.toUpperCase() ?? 'N/A',
            isDark,
            textColor,
            valueColor: _getStatusTextColor(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, Color textColor, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryCard(bool isDark, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Iconsax.receipt,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Payment History',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._paymentHistory.map((payment) {
            final paymentDate = payment['paymentDate'] != null
                ? (payment['paymentDate'] as Timestamp).toDate()
                : null;
            final amount = (payment['amount'] ?? 0).toDouble();
            final status = payment['status'] ?? 'pending';
            
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: status == 'paid' 
                          ? Colors.green.withOpacity(0.12)
                          : Colors.orange.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status == 'paid' ? Iconsax.tick_circle : Iconsax.clock,
                      size: 16,
                      color: status == 'paid' ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment['planName'] ?? 'Subscription Payment',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          paymentDate != null 
                              ? DateFormat('dd MMM yyyy, hh:mm a').format(paymentDate)
                              : 'Date not available',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: status == 'paid'
                              ? Colors.green.withOpacity(0.12)
                              : Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: status == 'paid' ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAutoRenewalCard(bool isDark, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.refresh,
              color: AppTheme.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto-renewal',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Automatically renew subscription before expiry',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAutoRenew,
            onChanged: (value) async {
              try {
                await _firestore
                    .collection('gyms')
                    .doc(widget.gymId)
                    .collection('members')
                    .doc(widget.memberId)
                    .update({'autoRenew': value});
                
                await _firestore
                    .collection('users')
                    .doc(widget.memberId)
                    .update({'autoRenew': value});
                
                setState(() => _isAutoRenew = value);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      value 
                          ? 'Auto-renewal enabled'
                          : 'Auto-renewal disabled',
                    ),
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update: $e')),
                );
              }
            },
            activeColor: AppTheme.primaryGreen,
          ),
        ],
      ),
    );
  }
}