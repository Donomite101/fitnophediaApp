import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/app_theme.dart';
import '../member_management/cash_approval_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String? gymId;

  @override
  void initState() {
    super.initState();
    _loadGymId();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  Future<void> _loadGymId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('gyms')
        .where('ownerId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty && mounted) {
      setState(() => gymId = snap.docs.first.id);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _markAsReadAndNavigate(DocumentSnapshot doc) async {
    await doc.reference.update({'isRead': true});
    if (mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => const CashApprovalScreen(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
        ),
      );
    }
  }

  Future<void> _markAsRead(DocumentSnapshot doc) async {
    await doc.reference.update({'isRead': true});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (gymId == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: theme.scaffoldBackgroundColor, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
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
        title: const Text('Notifications',
            style: TextStyle(fontFamily: 'SF Pro', fontWeight: FontWeight.w800, fontSize: 20)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: theme.dividerColor.withOpacity(0.12)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('gymId', isEqualTo: gymId)
            .where('type', isEqualTo: 'cash_payment_request')
            .where('isRead', isEqualTo: false) // Only show unread notifications
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(theme);
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: docs.length,
            cacheExtent: 1000,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

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
                  key: Key('cash_notif_${doc.id}'),
                  direction: DismissDirection.horizontal,
                  background: _swipeBackground(true),
                  secondaryBackground: _swipeBackground(false),
                  onDismissed: (_) => _markAsRead(doc),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _markAsReadAndNavigate(doc),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.11),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryGreen.withOpacity(0.45),
                            width: 1.4,
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
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryGreen,
                                    Color.lerp(AppTheme.primaryGreen, Colors.black, 0.3)!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryGreen.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.payments_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] ?? 'Cash Payment Received',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15.5,
                                      letterSpacing: -0.2,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    data['message'] ?? 'Tap to approve this payment',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontSize: 14,
                                      height: 1.35,
                                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.95),
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
                child: Image.asset('assets/notification_logo.png', width: 220, height: 220),
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
            style: TextStyle(fontFamily: 'SF Pro', fontSize: 15, color: Colors.grey[500], height: 1.5),
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
          const Text('Mark as Read', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          if (!left) const SizedBox(width: 10),
          if (!left) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
        ],
      ),
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