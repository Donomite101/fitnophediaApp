import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../../core/services/emails/email_service.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/app_theme.dart';

class PendingApprovalsTab extends StatefulWidget {
  const PendingApprovalsTab({Key? key}) : super(key: key);

  @override
  State<PendingApprovalsTab> createState() => _PendingApprovalsTabState();
}

class _PendingApprovalsTabState extends State<PendingApprovalsTab> {
  // FCM Server Key (move to secure config in production!)
  static const String fcmServerKey = "YOUR_FCM_SERVER_KEY_HERE";

  /// Send Push Notification via FCM
  Future<void> sendPushNotification({
    required String fcmToken,
    required String title,
    required String body,
  }) async {
    final url = Uri.parse('https://fcm.googleapis.com/fcm/send');
    final payload = {
      "to": fcmToken,
      "notification": {
        "title": title,
        "body": body,
        "sound": "default",
      },
      "data": {
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "type": "admin_approval",
      },
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "key=$fcmServerKey",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        print("Push notification sent successfully!");
      } else {
        print("Push failed: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Push notification error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? Colors.grey.shade900 : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gyms')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: AppTheme.primaryGreen),
                const SizedBox(height: 16),
                Text(
                  'No pending approvals',
                  style: TextStyle(fontSize: 18, color: subTextColor),
                ),
              ],
            ),
          );
        }

        final pendingGyms = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingGyms.length,
          itemBuilder: (context, index) {
            final gym = pendingGyms[index];
            final gymData = gym.data() as Map<String, dynamic>;
            return _buildGymCard(
                gym.id, gymData, context, cardColor, textColor, subTextColor);
          },
        );
      },
    );
  }

  Widget _buildGymCard(
      String gymId,
      Map<String, dynamic> gymData,
      BuildContext context,
      Color cardColor,
      Color textColor,
      Color subTextColor,
      ) {
    final addressMap = gymData['address'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ExpansionTile(
          collapsedIconColor: AppTheme.primaryGreen,
          iconColor: AppTheme.primaryGreen,
          tilePadding: EdgeInsets.zero,
          title: Row(
            children: [
              Icon(Icons.fitness_center,
                  color: AppTheme.primaryGreen, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gymData['businessName'] ?? 'Unknown Gym',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor),
                    ),
                    Text(
                      gymData['businessType'] ?? 'N/A',
                      style: TextStyle(color: subTextColor, fontSize: 14),
                    ),
                  ],
                ),
              ),
              _statusChip('Pending', Colors.orange),
            ],
          ),
          children: [
            const SizedBox(height: 8),
            _infoRow('Owner', gymData['contact']?['ownerName'], textColor,
                subTextColor),
            _infoRow('Email', gymData['contact']?['email'], textColor,
                subTextColor),
            _infoRow('Phone', gymData['contact']?['phone'], textColor,
                subTextColor),
            _infoRow(
              'Address',
              addressMap != null
                  ? [
                addressMap['street'],
                addressMap['city'],
                addressMap['state'],
                addressMap['postalCode'],
              ].where((e) => e != null).join(', ')
                  : 'N/A',
              textColor,
              subTextColor,
            ),
            _infoRow('Country',
                addressMap?['country']?.toString() ?? 'N/A', textColor, subTextColor),
            _infoRow('Created At', gymData['createdAt']?.toString(), textColor,
                subTextColor),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Approve',
                    onPressed: () => _approveGym(gymId, gymData, context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Reject',
                    isOutlined: true,
                    onPressed: () => _rejectGym(gymId, gymData, context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: TextStyle(
          color: color, fontWeight: FontWeight.bold, fontSize: 12),
    ),
  );

  Widget _infoRow(String label, String? value, Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: TextStyle(color: subTextColor),
            ),
          ),
        ],
      ),
    );
  }

  void _approveGym(String gymId, Map<String, dynamic> gymData, BuildContext context) {
    _confirmAction(
      context,
      title: 'Approve Gym',
      message: 'Are you sure you want to approve this gym?',
      confirmText: 'Approve',
      color: AppTheme.primaryGreen,
      onConfirm: () async {
        Navigator.pop(context);

        final ownerId = gymData['ownerId'];
        final ownerName = gymData['contact']?['ownerName'] ?? 'Gym Owner';
        final ownerEmail = gymData['contact']?['email'] ?? '';
        final gymName = gymData['businessName'] ?? 'Your Gym';

        try {
          // Update gym status
          await FirebaseFirestore.instance
              .collection('gyms')
              .doc(gymId)
              .update({
            'status': 'approved',
            'reviewedAt': FieldValue.serverTimestamp(),
          });

          // Send in-app notification
          if (ownerId != null) {
            await FirebaseFirestore.instance.collection('notifications').add({
              'ownerId': ownerId,
              'title': 'Gym Approved!',
              'message': 'Your gym "$gymName" has been approved and is now live!',
              'type': 'approval',
              'read': false,
              'timestamp': FieldValue.serverTimestamp(),
            });

            // Send push notification
            final userSnap = await FirebaseFirestore.instance
                .collection('users')
                .doc(ownerId)
                .get();
            final fcmToken = userSnap.data()?['fcmToken'] as String?;

            if (fcmToken != null && fcmToken.isNotEmpty) {
              await sendPushNotification(
                fcmToken: fcmToken,
                title: 'Gym Approved!',
                body: 'Your gym "$gymName" is now live on Fitnophedia!',
              );
            }

            // Send beautiful onboarding email via shared service
            if (ownerEmail.isNotEmpty) {
              await SmtpEmailService.sendOnboardingSuccessEmail(
                ownerName: ownerName,
                ownerEmail: ownerEmail,
                gymName: gymName,
                dashboardUrl: 'https://fitnophedia.app/login',
              );
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Gym approved successfully! Email & notification sent.'),
                backgroundColor: AppTheme.primaryGreen,
              ),
            );
          }
        } catch (e) {
          print("Approval error: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      },
    );
  }

  void _rejectGym(String gymId, Map<String, dynamic> gymData, BuildContext context) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Gym'),
        content: TextField(
          controller: reasonController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection (required)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a rejection reason')),
                );
                return;
              }

              Navigator.pop(context);

              await FirebaseFirestore.instance
                  .collection('gyms')
                  .doc(gymId)
                  .update({
                'status': 'rejected',
                'rejectionReason': reasonController.text.trim(),
                'reviewedAt': FieldValue.serverTimestamp(),
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gym rejected'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmAction(
      BuildContext context, {
        required String title,
        required String message,
        required String confirmText,
        required Color color,
        required VoidCallback onConfirm,
      }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(confirmText, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}