import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import '../../../core/app_theme.dart';

class AllGymsTab extends StatefulWidget {
  const AllGymsTab({Key? key}) : super(key: key);
  @override
  State<AllGymsTab> createState() => _AllGymsTabState();
}

class _AllGymsTabState extends State<AllGymsTab> {
  // ---------- UI state ----------
  String _searchQuery = '';
  String _statusFilter = 'all';
  bool _gridView = true;
  final List<String> _selectedGyms = [];
  bool _isLoading = false;

  final List<String> _statusOptions = [
    'all',
    'pending',
    'approved',
    'active',
    'suspended',
    'rejected',
    'inactive'
  ];

  // ---------- Theme ----------
  late final ColorScheme colors;
  late final TextTheme textTheme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    colors = Theme.of(context).colorScheme;
    textTheme = Theme.of(context).textTheme;
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surface,
      child: Column(
        children: [
          _buildHeader(),
          _buildStatsGrid(),
          _buildToolbar(),
          if (_selectedGyms.isNotEmpty) _buildBulkActions(),
          Expanded(child: _buildGymContent()),
        ],
      ),
    );
  }

  // ==================== UI WIDGETS ====================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center, size: 28, color: colors.primary),
              const SizedBox(width: 12),
              Text('Gym Management',
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildViewToggleButton(Icons.grid_view, true),
                    _buildViewToggleButton(Icons.list, false),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.outline.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Icons.search,
                    color: colors.onSurface.withOpacity(0.6), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search gyms...',
                      border: InputBorder.none,
                      hintStyle:
                      TextStyle(color: colors.onSurface.withOpacity(0.5)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear,
                        size: 16, color: colors.onSurface.withOpacity(0.6)),
                    onPressed: () => setState(() => _searchQuery = ''),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton(IconData icon, bool isGrid) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _gridView == isGrid ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        color: _gridView == isGrid
            ? colors.onPrimary
            : colors.onSurface.withOpacity(0.6),
        padding: EdgeInsets.zero,
        onPressed: () => setState(() => _gridView = isGrid),
      ),
    );
  }

  // ------------------- Stats -------------------
  Widget _buildStatsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('gyms').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: CircularProgressIndicator()));
        }

        final gyms = snapshot.data!.docs;
        final stats = {
          'total': gyms.length,
          'active': gyms
              .where((g) {
            final d = g.data() as Map<String, dynamic>? ?? {};
            return ['active', 'approved'].contains(d['status']);
          })
              .length,
          'pending': gyms
              .where((g) {
            final d = g.data() as Map<String, dynamic>? ?? {};
            return d['status'] == 'pending';
          })
              .length,
          'suspended': gyms
              .where((g) {
            final d = g.data() as Map<String, dynamic>? ?? {};
            return d['status'] == 'suspended';
          })
              .length,
        };

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: SizedBox(
            height: 70,
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
              children: [
                _statCard('Total', stats['total']!,
                    Icons.fitness_center, colors.primary),
                _statCard('Active', stats['active']!,
                    Icons.check_circle, AppTheme.primaryGreen),
                _statCard('Pending', stats['pending']!,
                    Icons.pending_actions, AppTheme.fitnessOrange),
                _statCard('Suspended', stats['suspended']!,
                    Icons.pause_circle, colors.error),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statCard(String title, int value, IconData icon, Color color) {
    return Card(
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value.toString(),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                        fontSize: 10,
                        color: colors.onSurface.withOpacity(0.6)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------- Toolbar -------------------
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _statusFilter,
              icon: Icon(Icons.keyboard_arrow_down,
                  size: 16, color: colors.onSurface.withOpacity(0.7)),
              items: _statusOptions
                  .map((s) => DropdownMenuItem(
                value: s,
                child: Text(_capitalize(s),
                    style: TextStyle(
                        color: _getStatusColor(s),
                        fontWeight: FontWeight.w500)),
              ))
                  .toList(),
              onChanged: (v) => setState(() => _statusFilter = v!),
            ),
          ),
          const Spacer(),
          if (_selectedGyms.isNotEmpty)
            Text('${_selectedGyms.length} selected',
                style: TextStyle(
                    color: colors.primary, fontWeight: FontWeight.w500)),
          if (_selectedGyms.isNotEmpty)
            TextButton(
                onPressed: _clearSelection, child: const Text('Clear')),
        ],
      ),
    );
  }

  Widget _buildBulkActions() {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _bulkBtn('Approve', Icons.check, AppTheme.primaryGreen),
          _bulkBtn('Suspend', Icons.pause, AppTheme.fitnessOrange),
          _bulkBtn('Activate', Icons.play_arrow, colors.primary),
          _bulkBtn('Reject', Icons.close, colors.error),
        ],
      ),
    );
  }

  ElevatedButton _bulkBtn(String text, IconData icon, Color color) {
    return ElevatedButton.icon(
      onPressed: () => _bulkUpdateStatus(text.toLowerCase()),
      icon: Icon(icon, size: 12),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }

  // ------------------- Content -------------------
  Widget _buildGymContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('gyms').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final gyms = _filterGyms(snap.data!.docs);
        return _gridView ? _grid(gyms) : _list(gyms);
      },
    );
  }

  // ----- Grid -----
  Widget _grid(List<QueryDocumentSnapshot> gyms) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8),
      itemCount: gyms.length,
      itemBuilder: (context, i) {
        final doc = gyms[i];
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final name = (data['businessName'] ?? 'Unnamed Gym').toString();
        final status = (data['status'] ?? 'pending').toString();
        final owner = (data['ownerName'] ?? '').toString();
        final address = _formatAddress(data['address']);

        return Card(
          color: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _viewGymDetails(doc.id, data),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fitness_center,
                          color: _getStatusColor(status), size: 18),
                      const Spacer(),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Chip(
                            label: Text(status.toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.bold)),
                            backgroundColor:
                            _getStatusColor(status).withOpacity(0.15),
                            labelStyle:
                            TextStyle(color: _getStatusColor(status)),
                            padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                            materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface)),
                  const SizedBox(height: 4),
                  Text(owner,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.onSurface.withOpacity(0.6))),
                  const Spacer(),
                  Text(address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10,
                          color: colors.onSurface.withOpacity(0.6))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ----- List -----
  Widget _list(List<QueryDocumentSnapshot> gyms) {
    return ListView.builder(
      itemCount: gyms.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, i) {
        final doc = gyms[i];
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final name = (data['businessName'] ?? 'Unnamed Gym').toString();
        final status = (data['status'] ?? 'pending').toString();
        final owner = (data['ownerName'] ?? '').toString();
        final address = _formatAddress(data['address']);

        return Card(
          color: colors.surface,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            title: Text(name, overflow: TextOverflow.ellipsis),
            subtitle: Text('$owner • $address',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Chip(
              label: Text(status.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 9, fontWeight: FontWeight.bold)),
              backgroundColor: _getStatusColor(status).withOpacity(0.15),
              labelStyle: TextStyle(color: _getStatusColor(status)),
            ),
            onTap: () => _viewGymDetails(doc.id, data),
          ),
        );
      },
    );
  }

  // ==================== BOTTOM SHEET ====================
  Future<void> _viewGymDetails(String id, Map<String, dynamic> data) async {
    final doc = await FirebaseFirestore.instance.collection('gyms').doc(id).get();
    final gymData = doc.data() ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: CustomScrollView(
          slivers: [
            _stickyHeader('Gym Details'),
            _detailSection([
              _detail('Business Name', gymData['businessName']),
              _detail('Type', gymData['businessType']),
              _detail('Description', gymData['description']),
            ]),
            _stickyHeader('Owner & Contact'),
            _detailSection([
              _detail('Owner', gymData['ownerName']),
              _detail('Email', gymData['contact']?['email']),
              _detail('Phone', gymData['contact']?['phone']),
            ]),
            _stickyHeader('Subscription'),
            _detailSection([
              _detail('Plan', gymData['subscriptionPlan']),
              _detail('Price', '₹${gymData['planPrice']}'),
              _detail('Status', gymData['subscriptionStatus']),
            ]),
            _stickyHeader('Opening Hours'),
            _detailSection(
              (gymData['openingHours'] as Map<String, dynamic>?)
                  ?.entries
                  .map((e) => _detail(
                  e.key.capitalize(),
                  '${e.value['open']} - ${e.value['close']}'))
                  .toList() ??
                  [const Text('Not available')],
            ),

            // ----- ACTION BUTTONS -----
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Actions',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _actionButton('Activate', Icons.play_arrow,
                            Colors.blue, () => _updateStatus(id, 'active')),
                        _actionButton('Deactivate', Icons.stop, Colors.grey,
                                () => _updateStatus(id, 'inactive')),
                        _actionButton('Suspend', Icons.pause,
                            AppTheme.fitnessOrange,
                                () => _updateStatus(id, 'suspended')),
                        _actionButton('Delete', Icons.delete_forever,
                            Colors.red,
                                () => _deleteGym(id, gymData['businessName'])),
                        _actionButton('Notify', Icons.notifications_active,
                            Colors.purple,
                                () => _showNotificationDialog(id, gymData)),
                      ],
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

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ==================== NOTIFICATION DIALOG ====================
  void _showNotificationDialog(String gymId, Map<String, dynamic> gymData) {
    final controller = TextEditingController();
    Navigator.pop(context); // close sheet first

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Notify ${gymData['businessName']}'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter your message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final msg = controller.text.trim();
              if (msg.isNotEmpty) {
                _sendNotification(gymId, gymData, msg);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  // ==================== FCM PUSH (SAFE & WORKING) ====================
  Future<void> _sendNotification(
      String gymId, Map<String, dynamic> gymData, String message) async {
    try {
      // ---- 1. Get ownerId (you said it exists) ----
      final contact = gymData['contact'] as Map<String, dynamic>?;
      final ownerId = contact?['ownerId']?.toString();

      if (ownerId == null || ownerId.isEmpty) {
        _showSnackBar('Owner ID missing in gym document.', isError: true);
        return;
      }

      // ---- 2. Get FCM token from users collection ----
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();

      if (!userSnap.exists) {
        _showSnackBar('Owner not found in users collection.', isError: true);
        return;
      }

      final token = userSnap.data()?['fcmToken'] as String?;
      if (token == null || token.isEmpty) {
        _showSnackBar(
            'Owner has no FCM token (hasn\'t opened the app yet).',
            isError: true);
        return;
      }

      // ---- 3. Load service-account & create JWT ----
      final serviceAccountJson = await rootBundle
          .loadString('assets/service-account.json');
      final serviceAccount = jsonDecode(serviceAccountJson);

      final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final exp = iat + 3600; // 1 hour

      final claims = {
        'iss': serviceAccount['client_email'],
        'scope': 'https://www.googleapis.com/auth/firebase.messaging',
        'aud': 'https://oauth2.googleapis.com/token',
        'iat': iat,
        'exp': exp,
      };

      final key = JsonWebKey.fromPem(serviceAccount['private_key']);
      final jws = JsonWebSignatureBuilder()
        ..jsonContent = claims
        ..setProtectedHeader('alg', 'RS256')
        ..addRecipient(key, algorithm: 'RS256')
        ..build()
            .toCompactSerialization();

      // ---- 4. Exchange JWT for access token ----
      final tokenResp = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': jws,
        },
      );

      if (tokenResp.statusCode != 200) {
        throw Exception('OAuth error: ${tokenResp.body}');
      }

      final accessToken = jsonDecode(tokenResp.body)['access_token'];
      final projectId = serviceAccount['project_id'];

      // ---- 5. Send FCM message ----
      final payload = {
        "message": {
          "token": token,
          "notification": {"title": "Fitnophedia Admin", "body": message},
          "data": {"gymId": gymId, "type": "admin_message"},
          "android": {"priority": "high"},
          "apns": {"headers": {"apns-priority": "10"}}
        }
      };

      final fcmResp = await http.post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/$projectId/messages:send'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (fcmResp.statusCode == 200) {
        _showSnackBar('Notification sent to ${gymData['businessName']}',
            isSuccess: true);
      } else {
        _showSnackBar('FCM error: ${fcmResp.body}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Send failed: $e', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess
            ? Colors.green
            : isError
            ? Colors.red
            : null,
      ),
    );
  }

  // ==================== STATUS / DELETE ====================
  Future<void> _updateStatus(String id, String status) async {
    await FirebaseFirestore.instance
        .collection('gyms')
        .doc(id)
        .update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});
    Navigator.pop(context);
    _showSnackBar('Status → $status');
  }

  Future<void> _deleteGym(String id, String? name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Gym?'),
        content: Text('Delete "$name" permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('gyms').doc(id).delete();
      Navigator.pop(context);
      _showSnackBar('Deleted $name');
    }
  }

  // ==================== STICKY HEADER (47 px) ====================
  SliverPersistentHeader _stickyHeader(String title) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyHeaderDelegate(
        child: Container(
          color: colors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11.5),
          alignment: Alignment.centerLeft,
          child: Text(title,
              style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ),
    );
  }

  SliverToBoxAdapter _detailSection(List<Widget> children) =>
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );

  Widget _detail(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.w500))),
        Expanded(
            child: Text(
                value == null || value.toString().isEmpty
                    ? 'Not provided'
                    : value.toString(),
                overflow: TextOverflow.ellipsis)),
      ],
    ),
  );

  // ==================== HELPERS ====================
  void _clearSelection() => setState(() => _selectedGyms.clear());

  Future<void> _bulkUpdateStatus(String newStatus) async {
    if (_selectedGyms.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selectedGyms) {
        batch.update(FirebaseFirestore.instance.collection('gyms').doc(id),
            {'status': newStatus});
      }
      await batch.commit();
      _showSnackBar('Bulk → $newStatus');
      _clearSelection();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<QueryDocumentSnapshot> _filterGyms(List<QueryDocumentSnapshot> gyms) {
    return gyms.where((doc) {
      final d = doc.data() as Map<String, dynamic>? ?? {};
      final name = (d['businessName'] ?? '').toString().toLowerCase();
      final owner = (d['ownerName'] ?? '').toString().toLowerCase();
      final status = (d['status'] ?? '').toString();

      final matchesStatus =
          _statusFilter == 'all' || status == _statusFilter;
      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery) ||
          owner.contains(_searchQuery);

      return matchesStatus && matchesSearch;
    }).toList();
  }

  String _formatAddress(dynamic address) {
    if (address == null) return 'No address';
    if (address is String) return address;
    if (address is Map) {
      final parts = <String>[];
      for (final k in ['street', 'city', 'state', 'postalCode']) {
        final v = address[k]?.toString();
        if (v != null && v.isNotEmpty) parts.add(v);
      }
      return parts.isEmpty ? 'No address' : parts.join(', ');
    }
    return address.toString();
  }

  Color _getStatusColor(String? s) {
    switch (s) {
      case 'active':
      case 'approved':
        return AppTheme.primaryGreen;
      case 'pending':
        return AppTheme.fitnessOrange;
      case 'suspended':
        return AppTheme.fitnessgreen;
      case 'rejected':
      case 'inactive':
        return AppTheme.alertRed;
      default:
        return Colors.grey;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ==================== STICKY HEADER DELEGATE ====================
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyHeaderDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  double get maxExtent => 47;

  @override
  double get minExtent => 47;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate old) => false;
}

// ==================== EXTENSION ====================
extension StringCasing on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}