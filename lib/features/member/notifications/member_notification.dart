// screens/member/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemberNotificationsScreen extends StatefulWidget {
  const MemberNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<MemberNotificationsScreen> createState() => _MemberNotificationsScreenState();
}

class _MemberNotificationsScreenState extends State<MemberNotificationsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _gymId;
  String? _memberId;
  bool _isLoading = true;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _loadGymAndMemberId();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadGymAndMemberId() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Search through all gyms to find the member (same logic as dashboard)
      final gymsSnapshot = await _firestore.collection('gyms').get();

      for (final gymDoc in gymsSnapshot.docs) {
        final memberDoc = await _firestore
            .collection('gyms')
            .doc(gymDoc.id)
            .collection('members')
            .doc(user.uid)
            .get();

      if (memberDoc.exists) {
          final gymId = gymDoc.id;
          final memberId = user.uid;
          
          setState(() {
            _gymId = gymId;
            _memberId = memberId;
          });
          
          // Cache for offline use
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_gymId', gymId);
          await prefs.setString('cached_memberId', memberId);
          
          break;
        }
      }
      
      // If still null, try loading from cache
      if (_gymId == null) {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _gymId = prefs.getString('cached_gymId');
          _memberId = prefs.getString('cached_memberId');
        });
      }
    } catch (e) {
      debugPrint('Error loading gym and member ID: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('gyms')
          .doc(_gymId)
          .collection('members')
          .doc(_memberId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      if (_gymId == null || _memberId == null) return;

      final snapshot = await _firestore
          .collection('gyms')
          .doc(_gymId!)
          .collection('members')
          .doc(_memberId!)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking notifications as read'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data, String notificationId) {
    _markAsRead(notificationId);

    final type = data['type'] as String?;
    if (type == 'payment_approved') {
      _showPaymentApprovedDialog(data);
    } else if (type == 'payment_rejected') {
      _showPaymentRejectedDialog(data);
    } else if (type == 'workout_assigned') {
      _showWorkoutAssignedDialog(data);
    } else if (type == 'diet_assigned') {
      _showDietAssignedDialog(data);
    }
    // Add more notification types as needed
  }

  void _showPaymentApprovedDialog(Map<String, dynamic> data) {
    final notificationData = data['data'] as Map<String, dynamic>? ?? {};
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Payment Approved! 🎉',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your payment has been approved successfully.',
              style: TextStyle(
                fontFamily: 'SF Pro',
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Amount', '₹${notificationData['amount'] ?? 'N/A'}'),
            _buildInfoRow('Plan', notificationData['planName'] ?? 'N/A'),
            _buildInfoRow('Valid until', _formatDate(notificationData['expiryDate'])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'OK',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentRejectedDialog(Map<String, dynamic> data) {
    final notificationData = data['data'] as Map<String, dynamic>? ?? {};
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Payment Rejected',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your payment was rejected. Please try again or contact support.',
              style: TextStyle(
                fontFamily: 'SF Pro',
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Amount', '₹${notificationData['amount'] ?? 'N/A'}'),
            _buildInfoRow('Plan', notificationData['planName'] ?? 'N/A'),
            _buildInfoRow('Reason', notificationData['reason'] ?? 'Payment failed'),
            const SizedBox(height: 8),
            Text(
              'Please contact gym staff for assistance.',
              style: TextStyle(
                fontFamily: 'SF Pro',
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'OK',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWorkoutAssignedDialog(Map<String, dynamic> data) {
    final notificationData = data['data'] as Map<String, dynamic>? ?? {};
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'New Workout Assigned! 💪',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your trainer has assigned a new workout plan for you.',
              style: TextStyle(
                fontFamily: 'SF Pro',
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Workout', notificationData['workoutName'] ?? 'N/A'),
            _buildInfoRow('Duration', notificationData['duration'] ?? 'N/A'),
            _buildInfoRow('Trainer', notificationData['trainerName'] ?? 'N/A'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'View Workout',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDietAssignedDialog(Map<String, dynamic> data) {
    final notificationData = data['data'] as Map<String, dynamic>? ?? {};
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'New Diet Plan! 🥗',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your nutritionist has assigned a new diet plan for you.',
              style: TextStyle(
                fontFamily: 'SF Pro',
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Diet Plan', notificationData['dietName'] ?? 'N/A'),
            _buildInfoRow('Duration', notificationData['duration'] ?? 'N/A'),
            _buildInfoRow('Nutritionist', notificationData['nutritionistName'] ?? 'N/A'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'View Diet',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'SF Pro',
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    final user = _auth.currentUser;
    if (user == null || _gymId == null || _memberId == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Unable to load notifications',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  color: theme.textTheme.titleLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadGymAndMemberId,
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                ),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.textTheme.titleLarge?.color,
        centerTitle: true,
        leading: const BackButton(),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerColor.withOpacity(0.12)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('gyms')
            .doc(_gymId)
            .collection('members')
            .doc(_memberId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
          }

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return _buildEmptyState(theme);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: notifications.length,
            cacheExtent: 1000,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final isRead = data['read'] as bool? ?? false;
              final createdAt = data['createdAt'] as Timestamp?;
              final timestamp = createdAt?.toDate() ?? DateTime.now();
              final type = data['type'] as String? ?? 'general';

              // Fast staggered animation
              final delay = index * 0.04;
              final start = delay.clamp(0.0, 0.8);
              final end = (start + 0.4).clamp(0.0, 1.0);

              final animation = CurvedAnimation(
                parent: _controller,
                curve: Interval(start, end, curve: Curves.fastOutSlowIn),
              );

              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Opacity(
                    opacity: animation.value,
                    child: Transform.translate(
                      offset: Offset(0, 60 * (1 - animation.value)),
                      child: Transform.scale(
                        scale: 0.94 + (animation.value * 0.06),
                        child: child,
                      ),
                    ),
                  );
                },
                child: Dismissible(
                  key: Key('notification_${doc.id}'),
                  direction: DismissDirection.horizontal,
                  background: _swipeBackground(true),
                  secondaryBackground: _swipeBackground(false),
                  onDismissed: (_) => _markAsRead(doc.id),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _handleNotificationTap(data, doc.id),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isRead
                              ? Colors.grey.withOpacity(0.08)
                              : AppTheme.primaryGreen.withOpacity(0.11),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isRead
                                ? Colors.transparent
                                : AppTheme.primaryGreen.withOpacity(0.45),
                            width: isRead ? 0 : 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                  theme.brightness == Brightness.dark ? 0.4 : 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _getNotificationIcon(type, isRead),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] as String? ?? 'Notification',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w900,
                                      fontSize: 15.5,
                                      letterSpacing: -0.2,
                                      color: isRead ? Colors.grey[600] : AppTheme.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    data['message'] as String? ?? '',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontSize: 14,
                                      height: 1.35,
                                      color: theme.textTheme.bodyMedium?.color?.withOpacity(isRead ? 0.7 : 0.95),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(timestamp),
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 11.5,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, value, __) {
              return Transform.scale(
                scale: value,
                child: Image.asset(
                  'assets/notification_logo.png',
                  width: 220,
                  height: 220,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_off_rounded,
                        size: 80,
                        color: AppTheme.primaryGreen,
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 30),
          Text(
            'Everything looks good',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing New Here',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 15,
                color: Colors.grey[500],
                height: 1.5
            ),
          ),
        ],
      ),
    );
  }

  Widget _swipeBackground(bool left) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryGreen, Color.lerp(AppTheme.primaryGreen, Colors.black, 0.3)!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (left) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
          if (left) const SizedBox(width: 10),
          const Text(
              'Mark as Read',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                fontFamily: 'SF Pro',
              )
          ),
          if (!left) const SizedBox(width: 10),
          if (!left) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
        ],
      ),
    );
  }

  Widget _getNotificationIcon(String type, bool isRead) {
    Color color;
    IconData icon;

    switch (type) {
      case 'payment_approved':
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      case 'payment_rejected':
        color = Colors.orange;
        icon = Icons.cancel_rounded;
        break;
      case 'workout_assigned':
        color = Colors.blue;
        icon = Icons.fitness_center_rounded;
        break;
      case 'diet_assigned':
        color = Colors.purple;
        icon = Icons.restaurant_rounded;
        break;
      default:
        color = AppTheme.primaryGreen;
        icon = Icons.notifications_rounded;
    }

    final iconColor = isRead ? Colors.grey : color;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: isRead
            ? null
            : LinearGradient(
          colors: [
            color,
            Color.lerp(color, Colors.black, 0.3)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        color: isRead ? Colors.grey.withOpacity(0.2) : null,
        shape: BoxShape.circle,
        boxShadow: isRead
            ? null
            : [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: isRead ? Colors.grey : Colors.white, size: 28),
    );
  }

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}