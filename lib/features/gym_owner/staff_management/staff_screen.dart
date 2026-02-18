import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../../../core/services/emails/staff_email_service.dart';
import '../models/staff_member_model.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({Key? key}) : super(key: key);

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? gymId;
  String? gymName;
  bool _loading = true;

  // Search & filters
  String searchQuery = '';
  String selectedRole = 'all';
  String selectedStatus = 'all';

  // View mode
  String viewMode = 'grid';

  @override
  void initState() {
    super.initState();
    _loadGymDetails();
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
        gymId = gyms.docs.first.id;
        final gymData = gyms.docs.first.data();
        gymName = gymData['name'] ?? 'Our Gym';
        setState(() => _loading = false);
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error loading gym: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _addStaff(Map<String, dynamic> staffData) async {
    if (gymId == null) return;

    try {
      staffData['createdAt'] = FieldValue.serverTimestamp();
      staffData['updatedAt'] = FieldValue.serverTimestamp();
      staffData['joinDate'] = staffData['joinDate'] ?? Timestamp.now();

      await _firestore.collection('gyms/$gymId/staff').add(staffData);

      // SEND WELCOME EMAIL
      try {
        await StaffEmailService.sendStaffWelcomeEmail(
          staffName: staffData['name'],
          staffEmail: staffData['email'],
          role: _capitalize(staffData['role']),
          gymName: gymName ?? 'Our Gym',
        );
        debugPrint('STAFF EMAIL SENT SUCCESSFULLY to ${staffData['email']}');
      } catch (emailError) {
        debugPrint('STAFF EMAIL FAILED: $emailError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Staff added, but welcome email failed to send.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${staffData['name']} added successfully! Welcome email sent.'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding staff: $e');
      _showSnackBar('Failed to add staff: $e', isError: true);
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _updateStaff(String staffId, Map<String, dynamic> updates) async {
    if (gymId == null) {
      _showSnackBar('No gym found', isError: true);
      return;
    }

    try {
      updates.removeWhere((key, value) => value == null);
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('gyms/$gymId/staff').doc(staffId).update(updates);

      if (mounted) {
        _showSnackBar('✅ Staff updated successfully');
      }
    } catch (e) {
      debugPrint('Error updating staff: $e');
      if (mounted) {
        _showSnackBar('Failed to update staff: $e', isError: true);
      }
      rethrow;
    }
  }

  Future<void> _deleteStaff(String staffId, String staffName) async {
    if (gymId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Delete Staff Member?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Text('Are you sure you want to remove $staffName?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('gyms/$gymId/staff').doc(staffId).delete();
        _showSnackBar('✅ $staffName removed');
      } catch (e) {
        debugPrint('Delete error: $e');
        _showSnackBar('Failed to delete: $e', isError: true);
      }
    }
  }

  // === BULK IMPORT ===
  Future<void> _importStaffFromCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final lines = const LineSplitter().convert(content);

      if (lines.length < 2) {
        _showSnackBar('CSV file is empty or invalid', isError: true);
        return;
      }

      final headers = lines[0].toLowerCase().split(',');
      final staffList = <Map<String, dynamic>>[];

      for (int i = 1; i < lines.length; i++) {
        final values = lines[i].split(',');
        if (values.length >= 5) {
          final staff = {
            'name': values[0].trim(),
            'email': values[1].trim(),
            'phone': values[2].trim(),
            'role': values[3].trim(),
            'status': values[4].trim(),
            'salary': double.tryParse(values[5].trim()) ?? 0.0,
            'specialization': values.length > 6 ? values[6].trim() : '',
            'workingDays': values.length > 7 ? values[7].trim().split(';') : [],
            'joinDate': Timestamp.now(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          staffList.add(staff);
        }
      }

      if (staffList.isEmpty) {
        _showSnackBar('No valid staff data found in CSV', isError: true);
        return;
      }

      await _showImportPreview(staffList);
    } catch (e) {
      debugPrint('Import error: $e');
      _showSnackBar('Import failed: $e', isError: true);
    }
  }

  Future<void> _showImportPreview(List<Map<String, dynamic>> staffList) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Import ${staffList.length} Staff Members', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: staffList.length,
            itemBuilder: (ctx, index) {
              final staff = staffList[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRoleColor(staff['role']),
                  child: Text(staff['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(staff['name'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text('${staff['role']} • ${staff['email']}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _bulkImportStaff(staffList);
    }
  }

  Future<void> _bulkImportStaff(List<Map<String, dynamic>> staffList) async {
    if (gymId == null) return;

    try {
      final batch = _firestore.batch();
      for (final staff in staffList) {
        final docRef = _firestore.collection('gyms/$gymId/staff').doc();
        batch.set(docRef, staff);
      }
      await batch.commit();
      _showSnackBar('✅ ${staffList.length} staff members imported successfully');
    } catch (e) {
      debugPrint('Bulk import error: $e');
      _showSnackBar('Import failed: $e', isError: true);
    }
  }

  // === EXPORT ===
  Future<void> _exportStaffToCSV() async {
    if (gymId == null) return;

    try {
      final snapshot = await _firestore
          .collection('gyms/$gymId/staff')
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        _showSnackBar('No staff members to export', isError: true);
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('name,email,phone,role,status,salary,specialization,workingDays,joinDate');

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = _escapeCsv(data['name'] ?? '');
        final email = _escapeCsv(data['email'] ?? '');
        final phone = _escapeCsv(data['phone'] ?? '');
        final role = _escapeCsv(data['role'] ?? '');
        final status = _escapeCsv(data['status'] ?? '');
        final salary = _escapeCsv(data['salary']?.toString() ?? '0');
        final specialization = _escapeCsv(data['specialization'] ?? '');
        final workingDays = _escapeCsv((data['workingDays'] as List?)?.join(';') ?? '');
        final joinDate = (data['joinDate'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? '';

        buffer.writeln('$name,$email,$phone,$role,$status,$salary,$specialization,$workingDays,$joinDate');
      }

      final csvBytes = utf8.encode(buffer.toString());

      if (kIsWeb) {
        final XFile file = XFile.fromData(csvBytes, name: 'staff_export.csv', mimeType: 'text/csv');
        await file.saveTo('staff_export.csv');
        _showSnackBar('✅ Export started');
        return;
      }

      if (Platform.isAndroid || Platform.isIOS) {
        final dir = await getExternalStorageDirectory();
        final path = dir?.path ?? '/storage/emulated/0/Download';
        final filePath = '$path/staff_${DateTime.now().millisecondsSinceEpoch}.csv';
        final file = File(filePath);
        await file.writeAsBytes(csvBytes);
        _showSnackBar('✅ Exported to: $filePath');
      } else {
        final String? path = await getSaveLocation(
          suggestedName: 'staff_export.csv',
          acceptedTypeGroups: [const XTypeGroup(label: 'csv', extensions: ['csv'])],
        ) as String?;
        if (path != null) {
          final file = File(path);
          await file.writeAsBytes(csvBytes);
          _showSnackBar('✅ Exported successfully');
        }
      }
    } catch (e) {
      debugPrint('Export error: $e');
      _showSnackBar('Export failed: $e', isError: true);
    }
  }

  String _escapeCsv(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.alertRed : AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // === IMPROVED UI COMPONENTS ===

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search staff members...',
          hintStyle: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildFilterButton() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_rounded, color: AppTheme.primaryGreen, size: 20),
            const SizedBox(width: 8),
            Text('Filters', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, color: AppTheme.primaryGreen),
          ],
        ),
      ),
      onSelected: (value) {
        if (value.startsWith('role_')) {
          setState(() => selectedRole = value.replaceFirst('role_', ''));
        } else if (value.startsWith('status_')) {
          setState(() => selectedStatus = value.replaceFirst('status_', ''));
        } else if (value == 'clear_filters') {
          setState(() {
            selectedRole = 'all';
            selectedStatus = 'all';
          });
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'header_roles',
          enabled: false,
          child: Text('Filter by Role', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        ..._buildRoleFilterItems(),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'header_status',
          enabled: false,
          child: Text('Filter by Status', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        ..._buildStatusFilterItems(),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'clear_filters',
          child: Row(
            children: [
              Icon(Icons.clear_all_rounded, color: AppTheme.alertRed),
              const SizedBox(width: 12),
              Text('Clear All Filters', style: GoogleFonts.inter(color: AppTheme.alertRed, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  List<PopupMenuItem<String>> _buildRoleFilterItems() {
    final roles = [
      {'label': 'All Roles', 'value': 'all', 'icon': Icons.people_alt_rounded, 'color': AppTheme.primaryGreen},
      {'label': 'Trainers', 'value': 'trainer', 'icon': Icons.fitness_center_rounded, 'color': Color(0xFF8B5FBF)},
      {'label': 'Reception', 'value': 'receptionist', 'icon': Icons.desk_rounded, 'color': Color(0xFF2E86AB)},
      {'label': 'Cleaners', 'value': 'cleaner', 'icon': Icons.cleaning_services_rounded, 'color': Color(0xFF00A896)},
      {'label': 'Managers', 'value': 'manager', 'icon': Icons.manage_accounts_rounded, 'color': Color(0xFFFF6B6B)},
    ];

    return roles.map((role) {
      final isSelected = selectedRole == role['value'];
      return PopupMenuItem(
        value: 'role_${role['value']}',
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected ? role['color'] as Color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: role['color'] as Color),
              ),
              child: Icon(role['icon'] as IconData,
                  size: 16,
                  color: isSelected ? Colors.white : role['color'] as Color
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(role['label'] as String,
                  style: GoogleFonts.inter(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? role['color'] as Color : Theme.of(context).colorScheme.onSurface,
                  )
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, size: 18, color: role['color'] as Color),
          ],
        ),
      );
    }).toList();
  }

  List<PopupMenuItem<String>> _buildStatusFilterItems() {
    final statuses = [
      {'label': 'All Status', 'value': 'all', 'icon': Icons.filter_list_rounded, 'color': Colors.grey},
      {'label': 'Active', 'value': 'active', 'icon': Icons.check_circle_rounded, 'color': AppTheme.primaryGreen},
      {'label': 'Inactive', 'value': 'inactive', 'icon': Icons.pause_circle_rounded, 'color': Colors.orange},
      {'label': 'On Leave', 'value': 'on_leave', 'icon': Icons.beach_access_rounded, 'color': Color(0xFF64B5F6)},
    ];

    return statuses.map((status) {
      final isSelected = selectedStatus == status['value'];
      return PopupMenuItem(
        value: 'status_${status['value']}',
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected ? status['color'] as Color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: status['color'] as Color),
              ),
              child: Icon(status['icon'] as IconData,
                  size: 16,
                  color: isSelected ? Colors.white : status['color'] as Color
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(status['label'] as String,
                  style: GoogleFonts.inter(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? status['color'] as Color : Theme.of(context).colorScheme.onSurface,
                  )
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, size: 18, color: status['color'] as Color),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildActiveFiltersChips() {
    final hasActiveFilters = selectedRole != 'all' || selectedStatus != 'all';

    if (!hasActiveFilters) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (selectedRole != 'all')
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                label: Text(
                  _getRoleLabel(selectedRole),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                backgroundColor: _getRoleColor(selectedRole).withOpacity(0.1),
                deleteIcon: Icon(Icons.close_rounded, size: 16),
                onDeleted: () => setState(() => selectedRole = 'all'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          if (selectedStatus != 'all')
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                label: Text(
                  _getStatusLabel(selectedStatus),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                backgroundColor: _getStatusColor(selectedStatus).withOpacity(0.1),
                deleteIcon: Icon(Icons.close_rounded, size: 16),
                onDeleted: () => setState(() => selectedStatus = 'all'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'trainer': return 'Trainers';
      case 'receptionist': return 'Reception';
      case 'cleaner': return 'Cleaners';
      case 'manager': return 'Managers';
      default: return 'All Roles';
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active': return 'Active';
      case 'inactive': return 'Inactive';
      case 'on_leave': return 'On Leave';
      default: return 'All Status';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active': return AppTheme.primaryGreen;
      case 'inactive': return Colors.orange;
      case 'on_leave': return Color(0xFF64B5F6);
      default: return Colors.grey;
    }
  }

  Widget _buildStaffList() {
    if (gymId == null) {
      return _buildEmptyState();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('gyms/$gymId/staff').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final staffMembers = snapshot.data!.docs.map((doc) {
          return StaffMember.fromFirestore(doc.id, doc.data());
        }).toList();

        final filtered = staffMembers.where((staff) {
          if (searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            final matchesSearch = staff.name.toLowerCase().contains(query) ||
                staff.email.toLowerCase().contains(query) ||
                staff.role.toLowerCase().contains(query) ||
                staff.specialization?.toLowerCase().contains(query) == true;
            if (!matchesSearch) return false;
          }

          if (selectedRole != 'all' && staff.role != selectedRole) return false;
          if (selectedStatus != 'all' && staff.status != selectedStatus) return false;

          return true;
        }).toList();

        if (filtered.isEmpty) {
          return _buildNoResultsState();
        }

        return viewMode == 'grid' ? _buildGridView(filtered) : _buildListView(filtered);
      },
    );
  }

  Widget _buildGridView(List<StaffMember> staff) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 :
          (MediaQuery.of(context).size.width > 800 ? 3 : 2),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.65,
        ),
        itemCount: staff.length,
        itemBuilder: (context, index) => _buildStaffCard(staff[index]),
      ),
    );
  }

  Widget _buildListView(List<StaffMember> staff) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: staff.length,
        itemBuilder: (context, index) => _buildStaffListTile(staff[index]),
      ),
    );
  }

  Widget _buildStaffCard(StaffMember staff) {
    final theme = Theme.of(context);
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.cardColor,
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: () => _showStaffDetailsSheet(staff),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          // ensure the card itself doesn't force an unbounded height in some grids
          constraints: const BoxConstraints(minHeight: 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with modern design
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getRoleColor(staff.role),
                      _getRoleColor(staff.role).withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getRoleColor(staff.role).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.transparent,
                  backgroundImage: staff.photoUrl != null ? NetworkImage(staff.photoUrl!) : null,
                  child: staff.photoUrl == null
                      ? Icon(
                    _getRoleIcon(staff.role),
                    size: 20,
                    color: Colors.white,
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 10),

              // Name
              Text(
                staff.name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getRoleColor(staff.role).withOpacity(0.1),
                      _getRoleColor(staff.role).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _getRoleColor(staff.role).withOpacity(0.2)),
                ),
                child: Text(
                  staff.role[0].toUpperCase() + staff.role.substring(1),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _getRoleColor(staff.role),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Status chip
              _buildStatusChip(staff.status),
              const SizedBox(height: 5),
              SizedBox(
                height: 36, // Increased height to fit 2 lines of text
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (staff.specialization != null && staff.specialization!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          staff.specialization!,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Quick actions - fixed height and fixed icon button sizes (prevents overflow)
              Container(
                height: 30,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // avoids forcing full width
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      icon: Icons.visibility_rounded,
                      color: AppTheme.primaryGreen,
                      onPressed: () => _showStaffDetailsSheet(staff),
                      tooltip: 'View',
                    ),
                    const SizedBox(width: 6),
                    _buildActionButton(
                      icon: Icons.delete_rounded,
                      color: AppTheme.alertRed,
                      onPressed: () => _deleteStaff(staff.id, staff.name),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 36, // fixed width so Row can predict total width
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 13),
        onPressed: onPressed,
        color: color,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 32, maxWidth: 36, maxHeight: 36),
      ),
    );
  }

  Widget _buildStaffListTile(StaffMember staff) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.cardColor,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      child: ListTile(
        onTap: () => _showStaffDetailsSheet(staff),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getRoleColor(staff.role),
                _getRoleColor(staff.role).withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _getRoleColor(staff.role).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundColor: Colors.transparent,
            backgroundImage: staff.photoUrl != null ? NetworkImage(staff.photoUrl!) : null,
            child: staff.photoUrl == null
                ? Icon(_getRoleIcon(staff.role), size: 20, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          staff.name,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              staff.email,
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getRoleColor(staff.role).withOpacity(0.1),
                        _getRoleColor(staff.role).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getRoleColor(staff.role).withOpacity(0.2)),
                  ),
                  child: Text(
                    staff.role[0].toUpperCase() + staff.role.substring(1),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _getRoleColor(staff.role),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _buildStatusChip(staff.status),
              ],
            ),
          ],
        ),
        trailing: SizedBox(
          width: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 🔥 Salary removed completely

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: Icons.edit_rounded,
                    color: Color(0xFF4FC3F7),
                    onPressed: () => _showEditStaffSheet(staff),
                    tooltip: 'Edit',
                  ),
                  const SizedBox(width: 2),
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    color: AppTheme.alertRed,
                    onPressed: () => _deleteStaff(staff.id, staff.name),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;

    if (status == 'active') {
      color = AppTheme.primaryGreen;
      icon = Icons.check_circle_rounded;
    } else if (status == 'on_leave') {
      color = Color(0xFF64B5F6);
      icon = Icons.beach_access_rounded;
    } else {
      color = AppTheme.alertRed;
      icon = Icons.pause_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            status.replaceAll('_', ' ')[0].toUpperCase() + status.replaceAll('_', ' ').substring(1),
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'trainer':
        return Color(0xFF8B5FBF);
      case 'receptionist':
        return Color(0xFF2E86AB);
      case 'cleaner':
        return Color(0xFF00A896);
      case 'manager':
        return Color(0xFFFF6B6B);
      default:
        return AppTheme.primaryGreen;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'trainer':
        return Icons.fitness_center_rounded;
      case 'receptionist':
        return Icons.desk_rounded;
      case 'cleaner':
        return Icons.cleaning_services_rounded;
      case 'manager':
        return Icons.manage_accounts_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGreen.withOpacity(0.1),
                      AppTheme.primaryGreen.withOpacity(0.05)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_alt_rounded,
                  size: 70,
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Staff Members Yet',
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Start building your dream team by adding your first staff member',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _showAddStaffSheet,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add First Staff Member',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: AppTheme.primaryGreen.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 50,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
            ),
            const SizedBox(height: 20),
            Text(
              'No staff members found',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // === STAFF DETAILS SHEET ===
  void _showStaffDetailsSheet(StaffMember staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Header
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getRoleColor(staff.role),
                            _getRoleColor(staff.role).withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _getRoleColor(staff.role).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.transparent,
                        backgroundImage: staff.photoUrl != null ? NetworkImage(staff.photoUrl!) : null,
                        child: staff.photoUrl == null
                            ? Icon(
                          _getRoleIcon(staff.role),
                          size: 35,
                          color: Colors.white,
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staff.name,
                            style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            staff.role[0].toUpperCase() + staff.role.substring(1),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: _getRoleColor(staff.role),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildStatusChip(staff.status),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 20),

                // Contact Information
                _buildDetailSection(
                  title: 'Contact Information',
                  icon: Icons.contact_mail_rounded,
                  children: [
                    _buildDetailItem('Email', staff.email, Icons.email_rounded),
                    _buildDetailItem('Phone', staff.phone ?? 'Not provided', Icons.phone_rounded),
                  ],
                ),

                const SizedBox(height: 28),

                // Employment Details
                _buildDetailSection(
                  title: 'Employment Details',
                  icon: Icons.work_rounded,
                  children: [
                    _buildDetailItem('Specialization', staff.specialization ?? 'Not specified', Icons.business_center_rounded),
                    _buildDetailItem('Salary', staff.salary != null ? '₹${staff.salary!.toStringAsFixed(2)}/month' : 'Not set', Icons.currency_rupee_rounded),
                    _buildDetailItem('Join Date', staff.formattedJoinDate, Icons.calendar_today_rounded),
                    _buildDetailItem('Working Days', staff.workingDays.isNotEmpty ? staff.workingDays.join(', ') : 'Not set', Icons.schedule_rounded),
                  ],
                ),

                const SizedBox(height: 32),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditStaffSheet(staff);
                        },
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('Edit Staff', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: AppTheme.primaryGreen, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteStaff(staff.id, staff.name);
                        },
                        icon: const Icon(Icons.delete_rounded),
                        label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.alertRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
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
    );
  }

  Widget _buildDetailSection({required String title, required IconData icon, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppTheme.primaryGreen, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === EDIT STAFF SHEET ===
  void _showEditStaffSheet(StaffMember staff) {
    final nameController = TextEditingController(text: staff.name);
    final emailController = TextEditingController(text: staff.email);
    final phoneController = TextEditingController(text: staff.phone ?? '');
    final salaryController = TextEditingController(text: staff.salary?.toString() ?? '');
    final specializationController = TextEditingController(text: staff.specialization ?? '');

    String selectedRole = staff.role;
    String selectedStatus = staff.status;
    List<String> selectedWorkingDays = List.from(staff.workingDays);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.edit_rounded, color: AppTheme.primaryGreen, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Edit Staff Member',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Update the details for ${staff.name}',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 28),

            // Form Fields
            _buildFormField(nameController, 'Full Name', Icons.person_outline_rounded),
            const SizedBox(height: 18),

            _buildFormField(emailController, 'Email Address', Icons.email_outlined, TextInputType.emailAddress),
            const SizedBox(height: 18),

            _buildFormField(phoneController, 'Phone Number', Icons.phone_outlined, TextInputType.phone),
            const SizedBox(height: 18),

            _buildDropdownField(
              value: selectedRole,
              label: 'Role',
              icon: Icons.work_outline_rounded,
              items: const ['trainer', 'receptionist', 'cleaner', 'manager'],
              onChanged: (value) => selectedRole = value!,
            ),
            const SizedBox(height: 18),

            _buildDropdownField(
              value: selectedStatus,
              label: 'Status',
              icon: Icons.circle_outlined,
              items: const ['active', 'inactive', 'on_leave'],
              onChanged: (value) => selectedStatus = value!,
            ),
            const SizedBox(height: 18),

            _buildFormField(salaryController, 'Monthly Salary', Icons.currency_rupee_outlined, TextInputType.number),
            const SizedBox(height: 18),

            _buildFormField(specializationController, 'Specialization', Icons.business_center_outlined),
            const SizedBox(height: 18),

            _buildWorkingDaysSelector(selectedWorkingDays, (days) {
              selectedWorkingDays = days;
            }),
            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final email = emailController.text.trim();

                      if (name.isEmpty || email.isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Name and Email are required'),
                              backgroundColor: AppTheme.alertRed,
                            ),
                          );
                        }
                        return;
                      }

                      final updates = {
                        'name': name,
                        'email': email,
                        'phone': phoneController.text.trim(),
                        'role': selectedRole,
                        'status': selectedStatus,
                        'salary': double.tryParse(salaryController.text.trim()) ?? 0.0,
                        'specialization': specializationController.text.trim(),
                        'workingDays': selectedWorkingDays,
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      try {
                        await _updateStaff(staff.id, updates);
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ ${staff.name} updated successfully'),
                              backgroundColor: AppTheme.primaryGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update: $e'),
                              backgroundColor: AppTheme.alertRed,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                      shadowColor: AppTheme.primaryGreen.withOpacity(0.3),
                    ),
                    child: Text('Save Changes', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // === ADD STAFF FORM ===
  void _showAddStaffSheet() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final salaryController = TextEditingController();
    final specializationController = TextEditingController();

    String selectedRole = 'trainer';
    String selectedStatus = 'active';
    List<String> selectedWorkingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_add_rounded, color: AppTheme.primaryGreen, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Add New Staff Member',
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Fill in the details to add a new staff member to your team',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 28),

            // Form Fields
            _buildFormField(nameController, 'Full Name', Icons.person_outline_rounded),
            const SizedBox(height: 18),

            _buildFormField(emailController, 'Email Address', Icons.email_outlined, TextInputType.emailAddress),
            const SizedBox(height: 18),

            _buildFormField(phoneController, 'Phone Number', Icons.phone_outlined, TextInputType.phone),
            const SizedBox(height: 18),

            _buildDropdownField(
              value: selectedRole,
              label: 'Role',
              icon: Icons.work_outline_rounded,
              items: const ['trainer', 'receptionist', 'cleaner', 'manager'],
              onChanged: (value) => selectedRole = value!,
            ),
            const SizedBox(height: 18),

            _buildDropdownField(
              value: selectedStatus,
              label: 'Status',
              icon: Icons.circle_outlined,
              items: const ['active', 'inactive', 'on_leave'],
              onChanged: (value) => selectedStatus = value!,
            ),
            const SizedBox(height: 18),

            _buildFormField(salaryController, 'Monthly Salary', Icons.currency_rupee_outlined, TextInputType.number),
            const SizedBox(height: 18),

            _buildFormField(specializationController, 'Specialization', Icons.business_center_outlined),
            const SizedBox(height: 18),

            _buildWorkingDaysSelector(selectedWorkingDays, (days) {
              selectedWorkingDays = days;
            }),
            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty || emailController.text.isEmpty) {
                        _showSnackBar('Name and email are required', isError: true);
                        return;
                      }

                      final staffData = {
                        'name': nameController.text.trim(),
                        'email': emailController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'role': selectedRole,
                        'status': selectedStatus,
                        'salary': double.tryParse(salaryController.text.trim()) ?? 0.0,
                        'specialization': specializationController.text.trim(),
                        'workingDays': selectedWorkingDays,
                        'joinDate': Timestamp.now(),
                        'createdAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      await _addStaff(staffData);
                      if (mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                      shadowColor: AppTheme.primaryGreen.withOpacity(0.3),
                    ),
                    child: Text('Add Staff', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(TextEditingController controller, String label, IconData icon, [TextInputType? keyboardType]) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
      ),
      items: items.map((role) {
        return DropdownMenuItem(
          value: role,
          child: Text(
            role[0].toUpperCase() + role.substring(1),
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      dropdownColor: Theme.of(context).cardColor,
      style: GoogleFonts.inter(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      borderRadius: BorderRadius.circular(14),
    );
  }

  // === WORKING DAYS SELECTOR FIX ===
  // === FIXED WORKING DAYS SELECTOR ===
  Widget _buildWorkingDaysSelector(List<String> selectedDays, Function(List<String>) onDaysChanged) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Working Days',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: days.map((day) {
            final isSelected = selectedDays.contains(day);
            return FilterChip(
              label: Text(day, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              selected: isSelected,
              onSelected: (selected) {
                final newDays = List<String>.from(selectedDays);
                if (selected) {
                  if (!newDays.contains(day)) {
                    newDays.add(day);
                  }
                } else {
                  newDays.remove(day);
                }
                // Call the callback to update the parent state
                onDaysChanged(newDays);
              },
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedColor: AppTheme.primaryGreen,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              checkmarkColor: Colors.white,
              elevation: 1,
            );
          }).toList(),
        ),
      ],
    );
  }
  // === UPDATED ADD STAFF SHEET WITH WORKING DAYS FIX ===
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Staff Management',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            )),
        backgroundColor: theme.cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                viewMode == 'grid' ? Icons.list_rounded : Icons.grid_view_rounded,
                size: 22,
                color: theme.colorScheme.onSurface,
              ),
            ),
            onPressed: () => setState(() => viewMode = viewMode == 'grid' ? 'list' : 'grid'),
            tooltip: 'Toggle view',
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.more_vert_rounded, size: 22, color: theme.colorScheme.onSurface),
            ),
            onSelected: (value) {
              if (value == 'export') {
                _exportStaffToCSV();
              } else if (value == 'import') {
                _importStaffFromCSV();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.upload_rounded, color: theme.colorScheme.onSurface),
                    const SizedBox(width: 12),
                    Text('Import from CSV', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, color: theme.colorScheme.onSurface),
                    const SizedBox(width: 12),
                    Text('Export to CSV', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildSearchBar(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildFilterButton(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActiveFiltersChips(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildStaffList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffSheet,
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: Text('Add Staff', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}