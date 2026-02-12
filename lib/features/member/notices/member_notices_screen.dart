import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

class MemberNoticesScreen extends StatefulWidget {
  final String gymId;
  final String memberId;

  const MemberNoticesScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  State<MemberNoticesScreen> createState() => _MemberNoticesScreenState();
}

class _MemberNoticesScreenState extends State<MemberNoticesScreen> {
  final _firestore = FirebaseFirestore.instance;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _noticesStream;
  String _currentFilter = 'all';
  final List<String> _filters = ['all', 'high', 'medium', 'low', 'unread'];
  final Set<String> _readNotices = {};

  @override
  void initState() {
    super.initState();
    _initializeNoticesStream();
    _loadReadNotices();
  }

  void _initializeNoticesStream() {
    _noticesStream = _firestore
        .collection('gyms')
        .doc(widget.gymId)
        .collection('notices')
        .where('isActive', isEqualTo: true)
        .where('isArchived', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _loadReadNotices() async {
    try {
      final readNoticesDoc = await _firestore
          .collection('gyms')
          .doc(widget.gymId)
          .collection('members')
          .doc(widget.memberId)
          .collection('read_notices')
          .get();

      setState(() {
        _readNotices.addAll(readNoticesDoc.docs.map((doc) => doc.id));
      });
    } catch (e) {
      debugPrint('Error loading read notices: $e');
    }
  }

  Future<void> _markAsRead(String noticeId) async {
    if (_readNotices.contains(noticeId)) return;

    try {
      await _firestore
          .collection('gyms')
          .doc(widget.gymId)
          .collection('members')
          .doc(widget.memberId)
          .collection('read_notices')
          .doc(noticeId)
          .set({
        'readAt': Timestamp.now(),
      });

      // Also update the notice's acknowledgedBy array
      await _firestore
          .collection('gyms')
          .doc(widget.gymId)
          .collection('notices')
          .doc(noticeId)
          .update({
        'acknowledgedBy': FieldValue.arrayUnion([widget.memberId]),
        'views': FieldValue.increment(1),
      });

      setState(() {
        _readNotices.add(noticeId);
      });
    } catch (e) {
      debugPrint('Error marking notice as read: $e');
    }
  }

  List<Map<String, dynamic>> _applyFilter(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var notices = docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'title': data['title'] ?? '',
        'message': data['message'] ?? '',
        'priority': data['priority'] ?? 'medium',
        'category': data['category'] ?? 'general',
        'targetAudience': data['targetAudience'] ?? ['all'],
        'startDate': data['startDate'],
        'endDate': data['endDate'],
        'createdBy': data['createdBy'] ?? 'Admin',
        'createdAt': data['createdAt'],
        'isRecurring': data['isRecurring'] ?? false,
        'recurringPattern': data['recurringPattern'],
      };
    }).toList();

    // Apply filters
    switch (_currentFilter) {
      case 'high':
        notices = notices.where((n) => n['priority'] == 'high').toList();
        break;
      case 'medium':
        notices = notices.where((n) => n['priority'] == 'medium').toList();
        break;
      case 'low':
        notices = notices.where((n) => n['priority'] == 'low').toList();
        break;
      case 'unread':
        notices = notices.where((n) => !_readNotices.contains(n['id'])).toList();
        break;
    }

    return notices;
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'class':
        return Iconsax.calendar;
      case 'maintenance':
        return Iconsax.setting_2;
      case 'promotion':
        return Iconsax.tag;
      case 'emergency':
        return Iconsax.danger;
      case 'holiday':
        return Iconsax.sun_1;
      default:
        return Iconsax.notification;
    }
  }

  void _showNoticeDetails(Map<String, dynamic> notice) {
    _markAsRead(notice['id']);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Category icon and title
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _getPriorityColor(notice['priority']).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCategoryIcon(notice['category']),
                      color: _getPriorityColor(notice['priority']),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notice['title'],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (notice['createdAt'] is Timestamp)
                          Text(
                            'Posted on ${DateFormat('MMM dd, yyyy').format((notice['createdAt'] as Timestamp).toDate())}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildBadge(
                    notice['priority'].toString().toUpperCase(),
                    _getPriorityColor(notice['priority']),
                  ),
                  _buildBadge(
                    notice['category'].toString().toUpperCase(),
                    Colors.blue,
                  ),
                  if (notice['isRecurring'])
                    _buildBadge('RECURRING', Colors.purple),
                ],
              ),
              const SizedBox(height: 20),

              // Date range if available
              if (notice['startDate'] != null && notice['endDate'] != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.calendar, size: 16, color: theme.textTheme.bodyMedium?.color),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('MMM dd').format((notice['startDate'] as Timestamp).toDate())} - ${DateFormat('MMM dd').format((notice['endDate'] as Timestamp).toDate())}',
                        style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Message
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    notice['message'],
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice, bool isDark) {
    final isRead = _readNotices.contains(notice['id']);
    final priorityColor = _getPriorityColor(notice['priority']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead
              ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1))
              : priorityColor.withOpacity(0.3),
          width: isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showNoticeDetails(notice),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getCategoryIcon(notice['category']),
                    color: priorityColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notice['title'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: priorityColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notice['message'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildBadge(
                            notice['priority'].toString().toUpperCase(),
                            priorityColor,
                          ),
                          const SizedBox(width: 8),
                          if (notice['createdAt'] is Timestamp)
                            Text(
                              DateFormat('MMM dd, yyyy').format(
                                (notice['createdAt'] as Timestamp).toDate(),
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notices & Updates',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Iconsax.filter, color: isDark ? Colors.white : Colors.black),
            onSelected: (value) {
              setState(() => _currentFilter = value);
            },
            itemBuilder: (context) => _filters.map((filter) {
              return PopupMenuItem(
                value: filter,
                child: Row(
                  children: [
                    if (_currentFilter == filter)
                      const Icon(Icons.check, size: 18, color: Color(0xFF00C853)),
                    if (_currentFilter == filter)
                      const SizedBox(width: 8),
                    Text(filter.toUpperCase()),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _noticesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading notices: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.notification,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notices yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for updates',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          final filteredNotices = _applyFilter(snapshot.data!.docs);

          if (filteredNotices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.filter_search,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notices match this filter',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredNotices.length,
            itemBuilder: (context, index) {
              return _buildNoticeCard(filteredNotices[index], isDark);
            },
          );
        },
      ),
    );
  }
}
