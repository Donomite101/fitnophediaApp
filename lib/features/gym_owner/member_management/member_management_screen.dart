import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/emails/email_service.dart';
import '../../../core/app_theme.dart';
import 'cash_approval_screen.dart';

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({Key? key}) : super(key: key);

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

class _MemberManagementScreenState extends State<MemberManagementScreen> with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? gymId;
  bool _loading = true;
  bool _canAddMember = false;

  // Tab controller
  late TabController _tabController;

  // UI state for Members tab
  String searchQuery = '';
  String selectedFilter = 'all'; // all, active, inactive, pending

  // Form visibility
  bool _showMemberForm = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange); // Add this line
    _loadGymDetails();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange); // Add this line
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        // This will trigger a rebuild when tab changes
      });
    }
  }
  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      return;
    }
    setState(() {
      // Force rebuild to update UI elements
    });
  }
  // Safe navigation methods
  void safePop() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadGymDetails() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final gyms = await _firestore
          .collection('gyms')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (gyms.docs.isNotEmpty) {
        final doc = gyms.docs.first;
        final data = doc.data();
        gymId = doc.id;

        bool isActive = false;
        final topStatus =
            (data['subscriptionStatus'] as String?)?.toLowerCase() ?? '';
        final topActive = data['subscriptionActive'] == true;
        if (topStatus == 'active' || topActive) isActive = true;

        setState(() {
          _canAddMember = isActive;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _canAddMember = false;
        });
      }
    } catch (e, s) {
      debugPrint('Error loading gym details: $e\n$s');
      setState(() {
        _loading = false;
        _canAddMember = false;
      });
    }
  }

  Future<void> _addMemberRecord({
    required String name,
    required String email,
    required bool hasOngoingSubscription,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (gymId == null) return;

    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "Adding $name and sending welcome email...",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryGreen,
            duration: const Duration(seconds: 10),
          ),
        );
      }

      // Fetch gym name
      final gymRef = _firestore.collection('gyms').doc(gymId);
      final gymDoc = await gymRef.get();
      final gymName = gymDoc.data()?['businessName'] ?? 'Your Gym';

      // Prepare member data
      final memberData = {
        'name': name,
        'email': email,
        'subscriptionStatus': 'pending',
        'authUid': '',
        'planId': null,
        'expiryDate': null,
        'joinDate': DateTime.now(),
        'createdAt': FieldValue.serverTimestamp(),
        'hasOngoingSubscription': hasOngoingSubscription,
        'subscriptionStartDate': hasOngoingSubscription ? startDate : null,
        'subscriptionEndDate': hasOngoingSubscription ? endDate : null,
        'subscriptionPlan': null,
        'subscriptionPrice': 0.0,
        'paymentType': null,
      };

      // Add member to Firestore
      final memberRef = await _firestore.collection('gyms/$gymId/members').add(memberData);

      // SEND WELCOME EMAIL
      try {
        await SmtpEmailService.sendMemberInviteEmail(
          memberName: name,
          memberEmail: email,
          gymName: gymName,
        );

        debugPrint('WELCOME EMAIL SENT SUCCESSFULLY to $email');
      } catch (emailError) {
        debugPrint('EMAIL FAILED for $email: $emailError');
        // Still show success, but mention email failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Member added, but email failed to send.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _addMemberRecord(
                  name: name,
                  email: email,
                  hasOngoingSubscription: hasOngoingSubscription,
                  startDate: startDate,
                  endDate: endDate,
                ),
              ),
            ),
          );
        }
      }

      // Final success
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name added successfully! Welcome email sent.'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }

      _hideMemberForm();
    } catch (e, s) {
      debugPrint('Add member failed: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add member: $e'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    }
  }

  // Delete member with confirmation
  Future<void> _deleteMember(String memberId, String memberName) async {
    if (gymId == null) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Delete Member', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Are you sure you want to delete $memberName? This action cannot be undone.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('gyms/$gymId/members').doc(memberId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Deleted: $memberName'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e, s) {
      debugPrint('Delete member error: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete member: $e'),
            backgroundColor: AppTheme.alertRed,
          ),
        );
      }
    }
  }

  // Create payment update notification in Firestore
  Future<void> _createPaymentUpdateNotification(String memberName, String memberEmail, String paymentType) async {
    try {
      final gymDoc = await _firestore.collection('gyms').doc(gymId).get();
      final gymName = gymDoc.data()?['businessName'] ?? 'Your Gym';

      // Create notification in Firestore
      await _firestore.collection('notifications').add({
        'type': 'payment_update',
        'memberName': memberName,
        'memberEmail': memberEmail,
        'gymName': gymName,
        'paymentType': paymentType,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'gymId': gymId,
      });

      debugPrint('📱 Payment update notification created for $memberEmail');
    } catch (e) {
      debugPrint('❌ Failed to create payment update notification: $e');
    }
  }

  // Slide-up member form
  void _showAddMemberForm() {
    if (!_canAddMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '⚠️ Your Fitnophedia subscription is inactive. Renew to add members.',
          ),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }
    setState(() {
      _showMemberForm = true;
    });
  }

  void _hideMemberForm() {
    setState(() {
      _showMemberForm = false;
    });
  }

  // BULK: pick CSV, parse and preview
  Future<void> _pickCsvAndPreview() async {
    if (!_canAddMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Your Fitnophedia subscription is inactive. Renew to add members.'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null) return;

      final path = result.files.single.path;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Invalid file selected'), backgroundColor: AppTheme.alertRed),
        );
        return;
      }

      final file = File(path);
      final content = await file.readAsString();
      final lines = const LineSplitter().convert(content);
      if (lines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('CSV is empty'), backgroundColor: AppTheme.alertRed),
        );
        return;
      }

      // Parse header and detect columns
      final headers = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();
      int startIndex = headers.contains('email') ? 1 : 0;

      final hasSubCol = headers.contains('hasongoingsubscription');
      final startCol = headers.contains('subscriptionstartdate');
      final endCol = headers.contains('subscriptionenddate');

      final List<Map<String, dynamic>> validRows = [];
      final List<Map<String, String>> invalidRows = [];
      final emailRegex = RegExp(r"^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$");

      for (int i = startIndex; i < lines.length; i++) {
        final cols = lines[i].split(',');
        if (cols.length < 2) continue;
        final name = cols[0].trim();
        final email = cols[1].trim();
        final hasSub = hasSubCol && cols.length > 2
            ? (cols[2].trim().toLowerCase() == 'true')
            : false;
        final start = startCol && cols.length > 3 && cols[3].trim().isNotEmpty
            ? DateTime.tryParse(cols[3].trim())
            : null;
        final end = endCol && cols.length > 4 && cols[4].trim().isNotEmpty
            ? DateTime.tryParse(cols[4].trim())
            : null;

        if (name.isNotEmpty && emailRegex.hasMatch(email)) {
          validRows.add({
            'name': name,
            'email': email,
            'hasOngoingSubscription': hasSub,
            'subscriptionStartDate': start,
            'subscriptionEndDate': end,
          });
        } else {
          invalidRows.add({
            'line': (i + 1).toString(),
            'name': name,
            'email': email,
          });
        }
      }

      await _showCsvPreviewDialog(validRows, invalidRows);
    } catch (e, s) {
      debugPrint('CSV pick/parse error: $e\n$s');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to read CSV: $e'), backgroundColor: AppTheme.alertRed),
      );
    }
  }

  // Preview dialog (valid + invalid rows)
  Future<void> _showCsvPreviewDialog(
      List<Map<String, dynamic>> valid,
      List<Map<String, String>> invalid,
      ) async {
    final theme = Theme.of(context);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return AlertDialog(
              backgroundColor: theme.cardColor,
              title: Text('CSV Preview', style: TextStyle(color: theme.colorScheme.onSurface)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Valid rows: ${valid.length}    Invalid rows: ${invalid.length}',
                      style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (valid.isNotEmpty) ...[
                            Text('✅ Valid (first 50):',
                                style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 6),
                            ...valid.take(50).map(
                                  (r) => ListTile(
                                leading: Icon(Icons.check_circle, color: AppTheme.primaryGreen),
                                title: Text(r['name'] ?? '', style: TextStyle(color: theme.colorScheme.onSurface)),
                                subtitle: Text(r['email'] ?? '', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                              ),
                            ),
                          ],
                          if (invalid.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text('❌ Invalid (first 50):',
                                style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                            ...invalid.take(50).map(
                                  (r) => ListTile(
                                leading: Icon(Icons.error, color: AppTheme.alertRed),
                                title: Text('Line ${r['line']}: ${r['name'] ?? 'No Name'}', style: TextStyle(color: theme.colorScheme.onSurface)),
                                subtitle: Text(r['email'] ?? '', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => safePop(),
                  child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                  onPressed: valid.isEmpty
                      ? null
                      : () async {
                    safePop();
                    await _importBatches(valid);
                  },
                  child: Text('Import ${valid.length}', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Import using batched writes + Email sending
  // Make this a reusable function that can be called from both tabs
  Future<void> _importBatches(List<Map<String, dynamic>> validRows) async {
    if (gymId == null) return;
    const int batchSize = 500;
    int total = validRows.length;
    int imported = 0;

    try {
      final gymDoc = await _firestore.collection('gyms').doc(gymId).get();
      final gymName = gymDoc.data()?['businessName'] ?? 'Your Gym';

      for (int start = 0; start < total; start += batchSize) {
        final end = (start + batchSize) > total ? total : (start + batchSize);
        final chunk = validRows.sublist(start, end);

        final WriteBatch batch = _firestore.batch();
        for (final row in chunk) {
          final ref = _firestore.collection('gyms/$gymId/members').doc();
          batch.set(ref, {
            'name': row['name'],
            'email': row['email'],
            'status': 'pending',
            'authUid': '',
            'planId': null,
            'expiryDate': null,
            'joinDate': DateTime.now(),
            'createdAt': FieldValue.serverTimestamp(),
            'hasOngoingSubscription': row['hasOngoingSubscription'] ?? false,
            'subscriptionStartDate': row['subscriptionStartDate'],
            'subscriptionEndDate': row['subscriptionEndDate'],
            'subscriptionPlan': null,
            'subscriptionPrice': 0.0,
            'paymentType': null,
          });
        }
        await batch.commit();
        imported += chunk.length;

        // Send emails asynchronously for each batch
        for (final row in chunk) {
          try {
            await SmtpEmailService.sendMemberInviteEmail(
              memberName: row['name'],
              memberEmail: row['email'],
              gymName: gymName,
            );
            await Future.delayed(const Duration(milliseconds: 300));
          } catch (e) {
            debugPrint('⚠️ Failed email for ${row['email']}: $e');
          }
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: Text('Import Complete', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            content: Text('Imported $imported members successfully.\n📧 Emails sent.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            actions: [
              TextButton(
                onPressed: () => safePop(),
                child: Text('OK', style: TextStyle(color: AppTheme.primaryGreen)),
              ),
            ],
          ),
        );
      }
    } catch (e, s) {
      debugPrint('Batch import error: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'), backgroundColor: AppTheme.alertRed),
        );
      }
    }
  }

  // EXPORT: fetch all members and open Save As dialog
  Future<void> _exportAndShareCsv() async {
    if (gymId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No gym found'), backgroundColor: AppTheme.fitnessOrange),
      );
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('gyms/$gymId/members')
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No members to export'), backgroundColor: AppTheme.fitnessOrange),
        );
        return;
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(width: 16),
              Text("Preparing ${snapshot.docs.length} members for sharing..."),
            ],
          ),
          backgroundColor: AppTheme.primaryGreen,
          duration: const Duration(seconds: 10),
        ),
      );

      // Build CSV content
      final buffer = StringBuffer();
      buffer.writeln('name,email,status,joinDate,subscriptionPlan,subscriptionPrice,paymentType');
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = _escapeCsvField(data['name']?.toString() ?? '');
        final email = _escapeCsvField(data['email']?.toString() ?? '');
        final status = _escapeCsvField(data['status']?.toString() ?? '');
        final plan = _escapeCsvField(data['subscriptionPlan']?.toString() ?? '');
        final price = _escapeCsvField(data['subscriptionPrice']?.toString() ?? '');
        final paymentType = _escapeCsvField(data['paymentType']?.toString() ?? '');

        String joinDate = '';
        final jd = data['joinDate'];
        if (jd is Timestamp) joinDate = jd.toDate().toIso8601String();
        else if (jd is String) joinDate = jd;
        buffer.writeln('$name,$email,$status,$joinDate,$plan,$price,$paymentType');
      }

      final csvBytes = utf8.encode(buffer.toString());
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'members_export_$timestamp.csv';

      if (kIsWeb) {
        // Web: Create download and suggest sharing
        final XFile file = XFile.fromData(
          csvBytes,
          name: fileName,
          mimeType: 'text/csv',
        );
        await file.saveTo(fileName);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ CSV downloaded - you can now share it via email or other apps'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      } else {
        // Mobile/Desktop: Use share dialog
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(csvBytes);

        // Hide loading indicator
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Use share functionality
        await Share.shareXFiles(
          [XFile(filePath, mimeType: 'text/csv')],
          text: 'Members Export - ${snapshot.docs.length} members',
          subject: 'Gym Members Export',
        );
      }
    } catch (e, s) {
      debugPrint('Export error: $e\n$s');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.alertRed),
      );
    }
  }

  String _escapeCsvField(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      final escaped = s.replaceAll('"', '""');
      return '"$escaped"';
    }
    return s;
  }

  // Helper for avatar: prefer photoUrl keys otherwise initials
  Widget _avatarFromData(Map<String, dynamic> data, double radius) {
    final theme = Theme.of(context);
    final photo = (data['photoUrl'] ?? data['avatarUrl'] ?? data['imageUrl'] ?? data['logoUrl']) as String?;
    final name = (data['name'] ?? '') as String;
    if (photo != null && photo.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(photo), backgroundColor: theme.colorScheme.surface);
    } else {
      String initials = '';
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      else if (parts.isNotEmpty && parts[0].isNotEmpty) initials = parts[0][0].toUpperCase();
      return CircleAvatar(
          radius: radius,
          backgroundColor: AppTheme.primaryGreen,
          child: Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
      );
    }
  }

  Widget _statusChip(String status) {
    status = status.toLowerCase();
    Color color;
    if (status == 'active') color = AppTheme.primaryGreen;
    else if (status == 'inactive') color = AppTheme.alertRed;
    else color = Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 10,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _paymentTypeChip(String paymentType) {
    paymentType = paymentType.toLowerCase();
    Color color;
    IconData icon;

    if (paymentType == 'online') {
      color = AppTheme.primaryGreen;
      icon = Icons.payment;
    } else if (paymentType == 'cash') {
      color = Colors.orange;
      icon = Icons.currency_rupee;
    } else {
      color = Colors.grey;
      icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              paymentType[0].toUpperCase() + paymentType.substring(1),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 9,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // Member list UI
  Widget _buildMemberList() {
    final theme = Theme.of(context);

    if (gymId == null) return _buildEmptyState('No gym found for this account.', Icons.fitness_center);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('gyms/$gymId/members').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        if (!snap.hasData || snap.data!.docs.isEmpty) return _buildEmptyState('No members yet.\nTap + to add your first member!', Icons.people);

        final docs = snap.data!.docs;
        final filtered = docs.where((d) {
          final data = d.data();
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          final status = (data['status'] ?? 'pending').toString().toLowerCase();
          if (selectedFilter != 'all' && status != selectedFilter) return false;
          if (searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            return name.contains(q) || email.contains(q);
          }
          return true;
        }).toList();

        if (filtered.isEmpty) return _buildEmptyState('No members match your search/filter.', Icons.search);

        return ListView.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final doc = filtered[idx];
            final data = doc.data();
            final name = data['name'] ?? '';
            final email = data['email'] ?? '';
            final status = (data['subscriptionStatus'] ?? 'pending').toString();
            final paymentType = (data['paymentType'] ?? 'Not set').toString();
            final joinTs = data['joinDate'];
            String joined = '';
            if (joinTs is Timestamp) joined = (joinTs.toDate()).toLocal().toString().split(' ')[0];
            else if (joinTs is String) joined = joinTs;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              color: theme.cardColor,
              child: ListTile(
                onTap: () {
                  _showMemberDetails(data, doc.id);
                },
                leading: _avatarFromData(data, 24),
                title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(email, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                    if (joined.isNotEmpty) Text('Joined: $joined', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: _paymentTypeChip(paymentType),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: _statusChip(status),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Show member details with enhanced subscription information
  void _showMemberDetails(Map<String, dynamic> data, String memberId) {
    final theme = Theme.of(context);
    final name = data['name'] ?? '';
    final email = data['email'] ?? '';
    final status = (data['subscriptionStatus'] ?? 'pending').toString();
    final joinTs = data['joinDate'];
    final hasSub = data['hasOngoingSubscription'] ?? false;
    final startDate = data['subscriptionStartDate'];
    final endDate = data['subscriptionEndDate'];
    final subscriptionPlan = data['subscriptionPlan'] ?? 'Not specified';
    final subscriptionPrice = data['subscriptionPrice'] ?? 0.0;
    final paymentType = data['paymentType'] ?? 'Not set';

    String joined = '';
    if (joinTs is Timestamp) {
      joined = (joinTs.toDate()).toLocal().toString().split(' ')[0];
    } else if (joinTs is String) joined = joinTs;

    String startDateStr = '';
    if (startDate is Timestamp) {
      startDateStr = (startDate.toDate()).toLocal().toString().split(' ')[0];
    } else if (startDate is String) startDateStr = startDate;

    String endDateStr = '';
    if (endDate is Timestamp) {
      endDateStr = (endDate.toDate()).toLocal().toString().split(' ')[0];
    } else if (endDate is String) endDateStr = endDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onBackground.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _avatarFromData(data, 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onBackground),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: AppTheme.alertRed),
                    onPressed: () {
                      safePop();
                      _deleteMember(memberId, name);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionHeader('Personal Information'),
              _buildDetailItem('Email', email, Icons.email, theme),
              _buildDetailItem('Status', status[0].toUpperCase() + status.substring(1), Icons.circle, theme),
              _buildDetailItem('Joined', joined, Icons.calendar_today, theme),

              const SizedBox(height: 16),

              // Subscription Information Section
              _buildSectionHeader('Subscription Details'),
              _buildDetailItem('Subscription Plan', subscriptionPlan, Icons.assignment, theme),
              _buildDetailItem('Subscription Price', '₹${subscriptionPrice.toStringAsFixed(2)}', Icons.currency_rupee, theme),
              _buildDetailItem('Payment Type', paymentType, Icons.payment, theme),

              if (hasSub) ...[
                _buildDetailItem('Subscription Status', 'Active', Icons.assignment_turned_in, theme),
                if (startDateStr.isNotEmpty) _buildDetailItem('Start Date', startDateStr, Icons.play_arrow, theme),
                if (endDateStr.isNotEmpty) _buildDetailItem('End Date', endDateStr, Icons.stop, theme),
              ] else ...[
                _buildDetailItem('Subscription Status', 'No Active Subscription', Icons.assignment_late, theme),
              ],
              const SizedBox(height: 20),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        safePop();
                        _showEditMemberForm(data, memberId);
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: AppTheme.primaryGreen),
                      ),
                      child: Text('Edit', style: TextStyle(color: AppTheme.primaryGreen)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => safePop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Close', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onBackground.withOpacity(0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.colorScheme.onBackground),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Edit member form
  void _showEditMemberForm(Map<String, dynamic> data, String memberId) {
    final theme = Theme.of(context);

    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final emailCtrl = TextEditingController(text: data['email'] ?? '');
    final planCtrl = TextEditingController(text: data['subscriptionPlan'] ?? '');
    final priceCtrl = TextEditingController(
      text: (data['subscriptionPrice'] ?? 0.0).toString(),
    );

    String selectedStatus = (data['subscriptionStatus'] ?? 'pending').toString().toLowerCase();
    String selectedPaymentType = (data['paymentType'] ?? 'Not set').toString();

    final previousPrice = (data['subscriptionPrice'] ?? 0.0).toDouble();
    final previousStatus = selectedStatus;
    final previousPaymentType = selectedPaymentType;

    // Save reference to ScaffoldMessenger BEFORE popping
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setStateForm) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 20),

                    Text('Edit Member', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color)),
                    const SizedBox(height: 24),

                    _buildFormField(controller: nameCtrl, label: 'Name', icon: Icons.person, hint: 'Full name', theme: theme),
                    const SizedBox(height: 16),
                    _buildFormField(controller: emailCtrl, label: 'Email', icon: Icons.email, hint: 'email@example.com', keyboardType: TextInputType.emailAddress, theme: theme),
                    const SizedBox(height: 16),
                    _buildFormField(controller: planCtrl, label: 'Plan', icon: Icons.fitness_center, hint: 'e.g. Premium', theme: theme),
                    const SizedBox(height: 16),
                    _buildFormField(controller: priceCtrl, label: 'Price', icon: Icons.currency_rupee, hint: '0.00', keyboardType: TextInputType.numberWithOptions(decimal: true), theme: theme),
                    const SizedBox(height: 16),

                    _buildDropdownField(
                      value: selectedStatus,
                      label: 'Status',
                      icon: Icons.circle,
                      items: ['pending', 'active', 'inactive'],
                      onChanged: (v) => setStateForm(() => selectedStatus = v!),
                      theme: theme,
                    ),
                    const SizedBox(height: 16),

                    _buildDropdownField(
                      value: selectedPaymentType,
                      label: 'Payment Type',
                      icon: Icons.payment,
                      items: ['Not set', 'Online', 'Cash'],
                      onChanged: (v) => setStateForm(() => selectedPaymentType = v!),
                      theme: theme,
                    ),

                    const SizedBox(height: 30),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                            onPressed: () async {
                              final name = nameCtrl.text.trim();
                              final email = emailCtrl.text.trim();
                              final plan = planCtrl.text.trim();
                              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;

                              if (name.isEmpty || email.isEmpty) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(content: Text('Name and email required'), backgroundColor: Colors.red),
                                );
                                return;
                              }

                              // Close bottom sheet first
                              Navigator.of(context).pop();

                              // Show loading
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Row(children: [
                                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                    SizedBox(width: 16),
                                    Text("Updating..."),
                                  ]),
                                  backgroundColor: AppTheme.primaryGreen,
                                  duration: Duration(seconds: 10),
                                ),
                              );

                              try {
                                // Update Firestore
                                await _firestore.collection('gyms/$gymId/members').doc(memberId).update({
                                  'name': name,
                                  'email': email,
                                  'subscriptionPlan': plan.isEmpty ? null : plan,
                                  'subscriptionPrice': price,
                                  'subscriptionStatus': selectedStatus,
                                  'paymentType': selectedPaymentType == 'Not set' ? null : selectedPaymentType,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });

                                // Smart revenue update
                                final wasPaid = (previousPaymentType == 'Cash' || previousPaymentType == 'Online') && previousStatus == 'active';
                                final isNowPaid = (selectedPaymentType == 'Cash' || selectedPaymentType == 'Online') && selectedStatus == 'active';

                                final gymRef = _firestore.collection('gyms').doc(gymId);

                                if (isNowPaid && !wasPaid) {
                                  await _firestore.runTransaction((t) async {
                                    final snap = await t.get(gymRef);
                                    final rev = (snap.data()?['totalRevenue'] ?? 0.0).toDouble();
                                    t.update(gymRef, {'totalRevenue': rev + price});
                                  });
                                } else if (!isNowPaid && wasPaid) {
                                  await _firestore.runTransaction((t) async {
                                    final snap = await t.get(gymRef);
                                    final rev = (snap.data()?['totalRevenue'] ?? 0.0).toDouble();
                                    t.update(gymRef, {'totalRevenue': (rev - previousPrice).clamp(0, double.infinity)});
                                  });
                                }

                                await _createPaymentUpdateNotification(name, email, selectedPaymentType);

                                // SUCCESS
                                scaffoldMessenger
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    const SnackBar(content: Text('Member updated successfully!'), backgroundColor: AppTheme.primaryGreen),
                                  );
                              } catch (e) {
                                scaffoldMessenger
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppTheme.alertRed));
                              }
                            },
                            child: const Text('Save', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Empty state widget
  Widget _buildEmptyState(String message, IconData icon) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return _buildLoadingScreen(theme);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: theme.appBarTheme.backgroundColor,
              elevation: 2,
              title: Text('Member Management', style: TextStyle(color: theme.appBarTheme.foregroundColor, fontWeight: FontWeight.bold)),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryGreen,
                labelColor: AppTheme.primaryGreen,
                unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                tabs: const [
                  Tab(icon: Icon(Icons.people), text: 'Members'),
                  Tab(icon: Icon(Icons.payment), text: 'Cash Approval'),
                ],
              ),
              actions: [
                if (_tabController.index == 0) ...[
                  IconButton(
                    icon: Icon(Icons.upload_file, color: AppTheme.primaryGreen),
                    tooltip: 'Bulk Upload (CSV)',
                    onPressed: _pickCsvAndPreview,
                  ),
                  IconButton(
                    icon: Icon(Icons.share, color: AppTheme.primaryGreen),
                    tooltip: 'Export & Share CSV',
                    onPressed: _exportAndShareCsv,
                  ),
                ],
                const SizedBox(width: 8),
              ],
              iconTheme: IconThemeData(color: theme.appBarTheme.foregroundColor),
            ),
            body: // In the TabBarView children array, replace the Cash Approval Tab placeholder:
            TabBarView(
              controller: _tabController,
              children: [
                // Members Tab (existing code)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      _buildSearchBar('Search members...', theme),
                      const SizedBox(height: 12),
                      _buildFilterChips(theme),
                      const SizedBox(height: 12),
                      Expanded(child: _buildMemberList()),
                    ],
                  ),
                ),
                // Cash Approval Tab - REPLACE THIS PART:
                CashApprovalScreen(), // Add this line instead of the placeholder
              ],
            ),
          ),

          // Slide-up Forms (only for Members tab)
          if (_showMemberForm && _tabController.index == 0) _buildMemberForm(theme),
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _tabController.index == 0
            ? FloatingActionButton(
          key: const ValueKey('members_fab'),
          onPressed: _showAddMemberForm,
          backgroundColor: AppTheme.primaryGreen,
          child: const Icon(Icons.add, color: Colors.white),
        )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildLoadingScreen(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 64, color: AppTheme.primaryGreen),
            const SizedBox(height: 20),
            Text('Fitnophedia', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
            const SizedBox(height: 20),
            CircularProgressIndicator(color: AppTheme.primaryGreen),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(String hintText, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (v) => setState(() => searchQuery = v),
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
          prefixIcon: Icon(Icons.search, color: AppTheme.primaryGreen),
          filled: true,
          fillColor: theme.cardColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterChip('all', 'All', Icons.people, theme),
          const SizedBox(width: 8),
          _filterChip('active', 'Active', Icons.check_circle, theme),
          const SizedBox(width: 8),
          _filterChip('inactive', 'Inactive', Icons.pause_circle_filled, theme),
          const SizedBox(width: 8),
          _filterChip('pending', 'Pending', Icons.hourglass_bottom, theme),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, IconData icon, ThemeData theme) {
    final active = selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryGreen : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppTheme.primaryGreen : theme.colorScheme.onBackground.withOpacity(0.3)),
          boxShadow: active ? [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))] : [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : AppTheme.primaryGreen),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? Colors.white : theme.colorScheme.onSurface, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // Member Form
  Widget _buildMemberForm(ThemeData theme) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    bool hasOngoingSubscription = false;
    DateTime? startDate;
    DateTime? endDate;

    return GestureDetector(
      onTap: _hideMemberForm,
      child: Container(
        color: Colors.black54,
        child: GestureDetector(
          onTap: () {}, // Prevent closing when tapping on form
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setStateForm) {
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 60,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Add New Member',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: scrollController,
                            child: Column(
                              children: [
                                _buildFormField(
                                  controller: nameCtrl,
                                  label: 'Full Name',
                                  icon: Icons.person,
                                  hint: 'Enter member name',
                                  theme: theme,
                                ),
                                const SizedBox(height: 16),
                                _buildFormField(
                                  controller: emailCtrl,
                                  label: 'Email Address',
                                  icon: Icons.email,
                                  hint: 'Enter email address',
                                  keyboardType: TextInputType.emailAddress,
                                  theme: theme,
                                ),
                                const SizedBox(height: 20),
                                _buildToggleRow(
                                  label: 'Has ongoing subscription?',
                                  value: hasOngoingSubscription,
                                  onChanged: (val) => setStateForm(() => hasOngoingSubscription = val),
                                  theme: theme,
                                ),
                                if (hasOngoingSubscription) ...[
                                  const SizedBox(height: 16),
                                  _buildDateField(
                                    label: 'Start Date',
                                    value: startDate,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setStateForm(() => startDate = picked);
                                      }
                                    },
                                    theme: theme,
                                  ),
                                  const SizedBox(height: 12),
                                  _buildDateField(
                                    label: 'End Date',
                                    value: endDate,
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now().add(const Duration(days: 30)),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setStateForm(() => endDate = picked);
                                      }
                                    },
                                    theme: theme,
                                  ),
                                ],
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _hideMemberForm,
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.3)),
                                ),
                                child: Text('Cancel', style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final name = nameCtrl.text.trim();
                                  final email = emailCtrl.text.trim();

                                  if (name.isEmpty || email.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Please enter both name and email.'),
                                        backgroundColor: AppTheme.fitnessOrange,
                                      ),
                                    );
                                    return;
                                  }

                                  if (hasOngoingSubscription && (startDate == null || endDate == null)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Please select subscription dates.'),
                                        backgroundColor: AppTheme.fitnessOrange,
                                      ),
                                    );
                                    return;
                                  }

                                  await _addMemberRecord(
                                    name: name,
                                    email: email,
                                    hasOngoingSubscription: hasOngoingSubscription,
                                    startDate: startDate,
                                    endDate: endDate,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGreen,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text('Add Member', style: TextStyle(fontSize: 16, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.colorScheme.onBackground)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.3)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
              prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.colorScheme.onBackground)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.onBackground.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String>(
              value: value,
              dropdownColor: theme.cardColor,
              style: TextStyle(color: theme.colorScheme.onBackground, fontSize: 16),
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
                border: InputBorder.none,
              ),
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(item[0].toUpperCase() + item.substring(1), style: TextStyle(color: theme.colorScheme.onBackground)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required Function(bool) onChanged,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.onBackground.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.colorScheme.onBackground),
          ),
          Switch(
            value: value,
            activeColor: AppTheme.primaryGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required Function() onTap,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.colorScheme.onBackground)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.onBackground.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: AppTheme.primaryGreen, size: 20),
                const SizedBox(width: 12),
                Text(
                  value != null
                      ? '${value.day}/${value.month}/${value.year}'
                      : 'Select date',
                  style: TextStyle(
                    color: value != null ? theme.colorScheme.onSurface : theme.colorScheme.onBackground.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}