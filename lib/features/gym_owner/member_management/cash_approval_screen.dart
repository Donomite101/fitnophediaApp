import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../../../core/app_theme.dart';

class CashApprovalScreen extends StatefulWidget {
  const CashApprovalScreen({Key? key}) : super(key: key);

  @override
  State<CashApprovalScreen> createState() => _CashApprovalScreenState();
}

class _CashApprovalScreenState extends State<CashApprovalScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? gymId;
  bool _isLoading = true;

  // Track locally processing items for immediate UI update
  final Set<String> _processingRequestIds = {};

  @override
  void initState() {
    super.initState();
    _loadGymId();
  }

  Future<void> _loadGymId() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final snap = await _firestore
          .collection('gyms')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gym not found')),
          );
          Navigator.pop(context);
        }
        return;
      }

      if (mounted) {
        setState(() {
          gymId = snap.docs.first.id;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('loadGymId error: $e\n$st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Try to resolve memberId: prefer memberId, fallback to email lookup.
  // Try to resolve memberId: prefer memberId, fallback to email lookup.
  Future<String?> _resolveMemberId(Map<String, dynamic> data) async {
    final rawMemberId = (data['memberId'] as String?)?.trim();
    
    // 1. Try direct ID lookup
    if (rawMemberId != null && rawMemberId.isNotEmpty) {
      final doc = await _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(rawMemberId)
          .get();
      if (doc.exists) {
        debugPrint('✅ Resolved Member ID direct: $rawMemberId');
        return rawMemberId;
      }
    }

    // 2. Try lookup by Auth UID (if the raw ID was actually an Auth ID)
    if (rawMemberId != null && rawMemberId.isNotEmpty) {
       final authQuery = await _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .where('authUid', isEqualTo: rawMemberId)
          .limit(1)
          .get();
      if (authQuery.docs.isNotEmpty) {
        final resolvedId = authQuery.docs.first.id;
        debugPrint('✅ Resolved Member ID via Auth UID: $resolvedId');
        return resolvedId;
      }
    }

    // 3. Try lookup by Email
    final email = (data['memberEmail'] as String?)?.trim();
    if (email != null && email.isNotEmpty) {
      final q = await _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final resolvedId = q.docs.first.id;
        debugPrint('✅ Resolved Member ID via Email: $resolvedId');
        return resolvedId;
      }
    }

    return null;
  }

  Future<void> _approvePayment(String requestId, DocumentReference requestRef) async {
    if (_processingRequestIds.contains(requestId)) return;
    setState(() => _processingRequestIds.add(requestId));

    try {
      final snap = await requestRef.get();
      if (!snap.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request no longer exists')),
          );
        }
        return;
      }

      final data = snap.data() as Map<String, dynamic>? ?? {};
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final method = (data['method'] as String?) ?? (data['paymentType'] as String?) ?? 'Cash';
      final isRenewal = (data['isRenewal'] ?? false) == true;
      final planName = data['planName'] as String? ?? 'Membership Plan';
      final memberName = data['memberName'] as String? ?? 'Member';
      final memberEmail = data['memberEmail'] as String? ?? '';

      // Resolve memberId (prefer explicit, else by email)
      String? memberId = await _resolveMemberId(data);

      if (memberId == null) {
        // Mark request as failed and return
        await requestRef.update({
          'status': 'Failed',
          'failureReason': 'Member not found (memberId/memberEmail missing or not matched)',
          'processedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Member not found — request marked Failed'),
              backgroundColor: AppTheme.alertRed,
            ),
          );
        }
        return;
      }

      final memberRef = _firestore.collection('gyms').doc(gymId).collection('members').doc(memberId);
      final gymRef = _firestore.collection('gyms').doc(gymId);
      final now = DateTime.now();
      final expiryDate = now.add(Duration(days: 30)); // Default 30 days membership

      await _firestore.runTransaction((tx) async {
        final memberSnap = await tx.get(memberRef);
        final gymSnap = await tx.get(gymRef);

        if (!memberSnap.exists) {
          // Shouldn't happen because we resolved earlier, but guard
          tx.update(requestRef, {
            'status': 'Failed',
            'failureReason': 'Member not found during transaction',
            'processedAt': FieldValue.serverTimestamp(),
          });
          throw Exception('Member not found during transaction');
        }

        final memberData = memberSnap.data() as Map<String, dynamic>? ?? {};
        final alreadyCounted = (memberData['countedInRevenue'] ?? false) == true;
        final currentRevenue = (gymSnap.data()?['totalRevenue'] as num?)?.toDouble() ?? 0.0;
        final currentActive = (gymSnap.data()?['activeMembersCount'] as num?)?.toInt() ?? 0;

        // Only set activatedAt if not present (don't overwrite on renewals)
        final shouldSetActivatedAt = (memberData['activatedAt'] == null);

        final Map<String, dynamic> memberUpdate = {
          'subscriptionStatus': 'active',
          'status': 'active',
          'hasOngoingSubscription': true,
          'paymentType': method,
          'subscriptionPrice': amount,
          'subscriptionPlan': planName,
          'updatedAt': FieldValue.serverTimestamp(),
          'countedInRevenue': true,
          'lastPaymentDate': Timestamp.fromDate(now),
          'lastPaymentAmount': amount,
        };

        if (shouldSetActivatedAt) {
          memberUpdate['activatedAt'] = Timestamp.fromDate(now);
          memberUpdate['subscriptionStartDate'] = Timestamp.fromDate(now);
          memberUpdate['subscriptionEndDate'] = Timestamp.fromDate(expiryDate);
        } else if (isRenewal) {
          // For renewals, extend the end date
          final currentEndDate = memberData['subscriptionEndDate'];
          if (currentEndDate is Timestamp) {
            final newEndDate = currentEndDate.toDate().add(Duration(days: 30));
            memberUpdate['subscriptionEndDate'] = Timestamp.fromDate(newEndDate);
          } else {
            memberUpdate['subscriptionEndDate'] = Timestamp.fromDate(expiryDate);
          }
        }

        tx.update(memberRef, memberUpdate);

        // Update request doc
        tx.update(requestRef, {
          'status': 'Approved',
          'approvedBy': _auth.currentUser?.displayName ?? _auth.currentUser?.uid ?? 'Owner',
          'approvedAt': FieldValue.serverTimestamp(),
          'processedMemberId': memberId,
          'processedAt': FieldValue.serverTimestamp(),
        });

        // Update gym aggregates if needed
        if (!alreadyCounted && amount > 0) {
          tx.update(gymRef, {
            'totalRevenue': currentRevenue + amount,
            'activeMembersCount': currentActive + (isRenewal ? 0 : 1),
            'lastPaymentProcessed': FieldValue.serverTimestamp(),
          });
        }

        // Create payment record for history
        final paymentRef = _firestore.collection('gyms').doc(gymId).collection('payments').doc();
        tx.set(paymentRef, {
          'memberId': memberId,
          'memberName': memberName,
          'memberEmail': memberEmail,
          'amount': amount,
          'planName': planName,
          'paymentType': method,
          'isRenewal': isRenewal,
          'status': 'completed',
          'processedBy': _auth.currentUser?.uid,
          'processedAt': FieldValue.serverTimestamp(),
          'requestId': requestId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Create notification for member
        final notificationRef = _firestore.collection('notifications').doc();
        tx.set(notificationRef, {
          'userId': memberId,
          'gymId': gymId,
          'title': 'Payment Approved! 🎉',
          'message': 'Your $planName payment of ₹${amount.toStringAsFixed(0)} has been approved. Your membership is now active!',
          'type': 'payment_approved',
          'data': {
            'amount': amount,
            'planName': planName,
            'approvedAt': now.toString(),
            'expiryDate': expiryDate.toString(),
            'requestId': requestId,
            'isRenewal': isRenewal,
          },
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(now.add(Duration(days: 30))),
        });
      });

      // Log audit action
      await _logAuditAction(
        action: 'PAYMENT_APPROVED',
        requestId: requestId,
        data: data,
        memberId: memberId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Payment Approved'),
                Text(
                  '₹${amount.toStringAsFixed(0)} - $memberName',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  'Notification sent to member',
                  style: TextStyle(fontSize: 10, color: Colors.white60),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }

      // Refresh the list by triggering a rebuild
      if (mounted) setState(() {});

    } catch (e, st) {
      debugPrint('Approve error: $e\n$st');

      // Attempt to mark request as failed for easier admin debugging
      try {
        await requestRef.update({
          'status': 'Failed',
          'failureReason': e.toString(),
          'processedAt': FieldValue.serverTimestamp(),
        });
      } catch (updateError) {
        debugPrint('Failed to update request status: $updateError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approval failed: ${e.toString()}'),
            backgroundColor: AppTheme.alertRed,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingRequestIds.remove(requestId));
      } else {
        _processingRequestIds.remove(requestId);
      }
    }
  }

  // Helper method for audit logging
  Future<void> _logAuditAction({
    required String action,
    required String requestId,
    required Map<String, dynamic> data,
    required String memberId,
  }) async {
    try {
      await _firestore.collection('gyms').doc(gymId).collection('audit_logs').add({
        'action': action,
        'requestId': requestId,
        'memberId': memberId,
        'memberName': data['memberName'],
        'amount': data['amount'],
        'planName': data['planName'],
        'performedBy': _auth.currentUser?.uid,
        'performedByEmail': _auth.currentUser?.email,
        'performedAt': FieldValue.serverTimestamp(),
        'userAgent': 'Mobile App',
        'ipAddress': 'N/A', // Could be implemented with a package
      });
    } catch (e) {
      debugPrint('Audit log error: $e');
    }
  }

  Future<void> _rejectPayment(String requestId, DocumentReference requestRef) async {
    if (_processingRequestIds.contains(requestId)) return;
    setState(() => _processingRequestIds.add(requestId));

    try {
      final snap = await requestRef.get();
      if (!snap.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request no longer exists')),
          );
        }
        return;
      }

      final data = snap.data() as Map<String, dynamic>? ?? {};
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final planName = data['planName'] as String? ?? 'Membership Plan';
      final memberName = data['memberName'] as String? ?? 'Member';
      final memberEmail = data['memberEmail'] as String? ?? '';
      final reason = data['rejectionReason'] as String? ?? 'Payment rejected by admin';

      // Resolve memberId (prefer explicit, else by email)
      String? memberId = await _resolveMemberId(data);

      await _firestore.runTransaction((tx) async {
        // Update request doc first
        tx.update(requestRef, {
          'status': 'Rejected',
          'rejectedBy': _auth.currentUser?.displayName ?? _auth.currentUser?.uid ?? 'Owner',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectionReason': reason,
          'processedAt': FieldValue.serverTimestamp(),
        });

        // If we have a memberId, roll back member subscription info and create notification
        if (memberId != null && memberId.isNotEmpty) {
          final memberRef = _firestore.collection('gyms').doc(gymId).collection('members').doc(memberId);

          // Only update member if they exist
          final memberSnap = await tx.get(memberRef);
          if (memberSnap.exists) {
            tx.update(memberRef, {
              'subscriptionStatus': 'pending',
              'hasOngoingSubscription': false,
              'paymentType': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
              'lastRejectionDate': FieldValue.serverTimestamp(),
              'lastRejectionReason': reason,
            });
          }

          // Create rejection notification for member
          final notificationRef = _firestore.collection('notifications').doc();
          tx.set(notificationRef, {
            'userId': memberId,
            'gymId': gymId,
            'title': 'Payment Rejected',
            'message': 'Your $planName payment of ₹${amount.toStringAsFixed(0)} was rejected. Reason: $reason',
            'type': 'payment_rejected',
            'data': {
              'amount': amount,
              'planName': planName,
              'rejectedAt': DateTime.now().toString(),
              'reason': reason,
              'requestId': requestId,
              'contactPerson': _auth.currentUser?.displayName ?? 'Gym Staff',
            },
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(days: 30))),
          });
        }

        // Create audit log for rejection
        final auditRef = _firestore.collection('gyms').doc(gymId).collection('audit_logs').doc();
        tx.set(auditRef, {
          'action': 'PAYMENT_REJECTED',
          'requestId': requestId,
          'memberId': memberId,
          'memberName': memberName,
          'amount': amount,
          'planName': planName,
          'rejectionReason': reason,
          'performedBy': _auth.currentUser?.uid,
          'performedByEmail': _auth.currentUser?.email,
          'performedAt': FieldValue.serverTimestamp(),
          'userAgent': 'Mobile App',
        });
      });

      // If memberId wasn't resolved in transaction, try to resolve it for notification
      if (memberId == null) {
        memberId = await _resolveMemberId(data);
      }

      // Additional: If this was a renewal rejection, we might want to handle it differently
      final isRenewal = (data['isRenewal'] ?? false) == true;
      if (isRenewal && memberId != null) {
        await _handleRenewalRejection(memberId, reason);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('❌ Payment Rejected'),
                Text(
                  '₹${amount.toStringAsFixed(0)} - $memberName',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                if (memberId != null)
                  Text(
                    'Notification sent to member',
                    style: TextStyle(fontSize: 10, color: Colors.white60),
                  ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }

      // Refresh the list by triggering a rebuild
      if (mounted) setState(() {});

    } catch (e, st) {
      debugPrint('Reject error: $e\n$st');

      // Attempt to mark request as failed for easier admin debugging
      try {
        await requestRef.update({
          'status': 'Failed',
          'failureReason': 'Rejection failed: ${e.toString()}',
          'processedAt': FieldValue.serverTimestamp(),
        });
      } catch (updateError) {
        debugPrint('Failed to update request status: $updateError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejection failed: ${e.toString()}'),
            backgroundColor: AppTheme.alertRed,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingRequestIds.remove(requestId));
      } else {
        _processingRequestIds.remove(requestId);
      }
    }
  }

  // Helper method for handling renewal rejections specifically
  Future<void> _handleRenewalRejection(String memberId, String reason) async {
    try {
      final memberRef = _firestore.collection('gyms').doc(gymId).collection('members').doc(memberId);

      // You might want to add specific logic for renewal rejections
      // For example, set a grace period or send a special notification
      await memberRef.update({
        'renewalRejected': true,
        'renewalRejectionReason': reason,
        'renewalRejectedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Renewal rejection handled for member: $memberId');
    } catch (e) {
      debugPrint('Error handling renewal rejection: $e');
    }
  }

  // Optional: Method to show rejection reason dialog
  Future<void> _showRejectionDialog(String requestId, DocumentReference requestRef) async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please provide a reason for rejection:'),
            SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'e.g., Incorrect amount, Payment verification failed...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please provide a rejection reason')),
                );
              }
            },
            child: Text('Reject with Reason'),
          ),
        ],
      ),
    );

    if (result == true && reasonController.text.trim().isNotEmpty) {
      // Store the reason in the request data temporarily
      final snap = await requestRef.get();
      final data = snap.data() as Map<String, dynamic>? ?? {};
      data['rejectionReason'] = reasonController.text.trim();

      // Call reject payment with the reason
      await _rejectPayment(requestId, requestRef);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || gymId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Cash Payment Requests'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('gyms')
            .doc(gymId)
            .collection('payment_requests')
            .where('status', isEqualTo: 'Pending')
            .orderBy('requestedAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Firestore Error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  const Text('Error loading requests'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter out requests that are currently being processed
          final pendingDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            final isPending = data?['status'] == 'Pending';
            final notProcessing = !_processingRequestIds.contains(doc.id);
            return isPending && notProcessing;
          }).toList();

          if (pendingDocs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Lottie.asset(
                      'assets/animations/pending_approval.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'All caught up!',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Show processing indicator if any requests are being processed
              if (_processingRequestIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.blue.withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text(
                        'Processing ${_processingRequestIds.length} request(s)...',
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: pendingDocs.length,
                  itemBuilder: (context, index) {
                    final doc = pendingDocs[index];
                    final data = doc.data() as Map<String, dynamic>? ?? {};

                    final memberName = (data['memberName'] as String?) ?? 'Member';
                    final memberEmail = (data['memberEmail'] as String?) ?? '';
                    final planName = (data['planName'] as String?) ?? 'Plan';
                    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
                    final isRenewal = (data['isRenewal'] ?? false) == true;
                    final requestedAtTs = data['requestedAt'] as Timestamp?;
                    final requestedAt = requestedAtTs?.toDate() ?? DateTime.now();

                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.2),
                                  child: Text(
                                    memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      if (memberEmail.isNotEmpty)
                                        Text(memberEmail, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isRenewal ? Colors.blue.shade50 : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isRenewal ? 'Renewal' : 'New',
                                    style: TextStyle(
                                      color: isRenewal ? Colors.blue : Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(planName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text('₹${amount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Requested: ${_formatTime(requestedAt)}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _approvePayment(doc.id, doc.reference),
                                    icon: const Icon(Icons.check, size: 20),
                                    label: const Text('Approve'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _rejectPayment(doc.id, doc.reference),
                                    icon: const Icon(Icons.close, size: 20),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.alertRed,
                                      side: const BorderSide(color: AppTheme.alertRed, width: 2),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
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
        },
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }
}