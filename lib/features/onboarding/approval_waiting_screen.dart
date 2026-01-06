import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/widgets/custom_button.dart';
import '../../routes/app_routes.dart';
import '../../core/app_theme.dart'; // ✅ Use global theme

class ApprovalWaitingScreen extends StatelessWidget {
  const ApprovalWaitingScreen({Key? key}) : super(key: key);

  /// ✅ Detects status from either root-level or inside staff[0].status
  String _extractStatus(Map<String, dynamic> gymData) {
    String status = 'pending';

    if (gymData['status'] != null) {
      status = gymData['status'].toString();
    } else if (gymData['staff'] is List && gymData['staff'].isNotEmpty) {
      final firstStaff = gymData['staff'][0];
      if (firstStaff is Map && firstStaff['status'] != null) {
        status = firstStaff['status'].toString();
      }
    }

    return status.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Future.microtask(() =>
          Navigator.pushReplacementNamed(context, AppRoutes.login));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final gymStream = FirebaseFirestore.instance
        .collection('gyms')
        .where('ownerId', isEqualTo: user.uid)
        .limit(1)
        .snapshots();

    final subStream = FirebaseFirestore.instance
        .collection('app_subscriptions')
        .doc(user.uid)
        .snapshots();

    return StreamBuilder(
      stream: gymStream,
      builder: (context, gymSnap) {
        if (gymSnap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }

        if (gymSnap.hasError ||
            !gymSnap.hasData ||
            gymSnap.data!.docs.isEmpty) {
          return const _NoGymFound();
        }

        final gymDoc = gymSnap.data!.docs.first;
        final gymData = gymDoc.data() as Map<String, dynamic>;
        final status = _extractStatus(gymData);

        // Listen to app_subscriptions in parallel
        return StreamBuilder<DocumentSnapshot>(
          stream: subStream,
          builder: (context, subSnap) {
            final hasActiveSub = subSnap.hasData &&
                subSnap.data!.exists &&
                (subSnap.data!.data() as Map<String, dynamic>?)?['status'] ==
                    'active';

            // === REDIRECT LOGIC ===
            if (status == 'approved' && hasActiveSub) {
              Future.microtask(() {
                Navigator.pushReplacementNamed(
                    context, AppRoutes.gymOwnerDashboard);
              });
            }

            if (status == 'pending') {
              return _buildPendingUI(context);
            }

            if (status == 'rejected') {
              final reason =
                  gymData['rejectionReason'] ?? 'No reason provided';
              return _buildRejectedUI(context, reason);
            }

            if (status == 'approved' && !hasActiveSub) {
              Future.microtask(() {
                Navigator.pushReplacementNamed(
                    context, AppRoutes.subscriptionPlans);
              });
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            return _buildUnknownStatusUI(context, status);
          },
        );
      },
    );
  }

  // =========================== UI ===========================

  Widget _buildPendingUI(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.fitnessOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_empty,
                  color: AppTheme.fitnessOrange, size: 60),
            ),
            const SizedBox(height: 32),
            Text(
              'Onboarding Submitted!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your gym details have been submitted for approval. Our team will review your application and notify you once approved.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This process usually takes 24–48 hours.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.fitnessOrange,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Card(
              color: theme.cardColor,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                          color: AppTheme.fitnessOrange,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status: Pending Approval',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Waiting for super admin approval',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Logout',
              onPressed: () => Navigator.pushReplacementNamed(
                  context, AppRoutes.login),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedUI(BuildContext context, String reason) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                  color: AppTheme.alertRed.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.cancel_outlined,
                  color: AppTheme.alertRed, size: 60),
            ),
            const SizedBox(height: 32),
            Text(
              'Application Rejected',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Unfortunately, your gym onboarding request was rejected.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.alertRed.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.alertRed),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: AppTheme.alertRed, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(reason,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.alertRed))),
                ],
              ),
            ),
            const SizedBox(height: 40),
            CustomButton(
              text: 'Reapply',
              onPressed: () => Navigator.pushReplacementNamed(
                  context, AppRoutes.onboarding),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Logout',
              onPressed: () => Navigator.pushReplacementNamed(
                  context, AppRoutes.login),
              isOutlined: true, // ✅ visually secondary button
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnknownStatusUI(BuildContext context, String status) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: AppTheme.alertRed, size: 64),
            const SizedBox(height: 16),
            Text(
              'Unknown status: "$status"',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Please contact support or reapply your gym details.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Logout',
              onPressed: () => Navigator.pushReplacementNamed(
                  context, AppRoutes.login),
              isOutlined: true,
            ),
          ],
        ),
      ),
    );
  }
}

// Helper Widgets
class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _NoGymFound extends StatelessWidget {
  const _NoGymFound();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 60, color: AppTheme.alertRed),
              const SizedBox(height: 16),
              Text('No gym found for your account',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Logout',
                onPressed: () => Navigator.pushReplacementNamed(
                    context, AppRoutes.login),
                isOutlined: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
