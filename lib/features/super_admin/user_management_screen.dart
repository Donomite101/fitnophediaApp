// features/super_admin/user_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/custom_button.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _roles = ['superadmin', 'gym_owner', 'trainer', 'member'];

  @override
  void initState() {
    super.initState();
    // Initialize with exact number of roles
    _tabController = TabController(length: _roles.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Super Admins'),
            Tab(text: 'Gym Owners'),
            Tab(text: 'Trainers'),
            Tab(text: 'Members'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _roles.map((role) => _buildUserTab(role)).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewUser,
        backgroundColor: Colors.red,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildUserTab(String role) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(role);
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final userData = user.data() as Map<String, dynamic>;

            return _buildUserCard(user.id, userData, role, context);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String role) {
    String message = '';
    String icon = '';

    switch (role) {
      case 'superadmin':
        message = 'No Super Admins found';
        icon = '👑';
        break;
      case 'gym_owner':
        message = 'No Gym Owners found';
        icon = '💪';
        break;
      case 'trainer':
        message = 'No Trainers found';
        icon = '🏋️';
        break;
      case 'member':
        message = 'No Members found';
        icon = '👤';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(String userId, Map<String, dynamic> userData, String role, BuildContext context) {
    Color roleColor = _getRoleColor(role);
    IconData roleIcon = _getRoleIcon(role);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: roleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(roleIcon, color: roleColor, size: 20),
        ),
        title: Text(
          userData['email'] ?? 'No Email',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getRoleDisplayName(role),
              style: TextStyle(
                color: roleColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (userData['createdAt'] != null)
              Text(
                'Joined: ${DateFormat('MMM dd, yyyy').format((userData['createdAt'] as Timestamp).toDate())}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            if (role == 'gym_owner') _buildGymOwnerStatus(userData),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, size: 20),
              onPressed: () => _viewUserDetails(userId, userData, context),
              color: Colors.blue,
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editUserRole(userId, userData, context),
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGymOwnerStatus(Map<String, dynamic> userData) {
    bool approved = userData['approved'] ?? false;
    bool onboardingCompleted = userData['onboardingCompleted'] ?? false;
    bool subscriptionActive = userData['subscriptionActive'] ?? false;

    String status = 'Not Started';
    Color color = Colors.grey;

    if (!onboardingCompleted) {
      status = 'Onboarding';
      color = Colors.orange;
    } else if (!approved) {
      status = 'Pending Approval';
      color = Colors.orange;
    } else if (!subscriptionActive) {
      status = 'Needs Subscription';
      color = Colors.blue;
    } else {
      status = 'Active';
      color = Colors.green;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'superadmin':
        return Colors.green;
      case 'gym_owner':
        return Colors.red;
      case 'trainer':
        return Colors.blue;
      case 'member':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'superadmin':
        return Icons.admin_panel_settings;
      case 'gym_owner':
        return Icons.business;
      case 'trainer':
        return Icons.fitness_center;
      case 'member':
        return Icons.person;
      default:
        return Icons.person;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'superadmin':
        return 'Super Admin';
      case 'gym_owner':
        return 'Gym Owner';
      case 'trainer':
        return 'Trainer';
      case 'member':
        return 'Member';
      default:
        return role;
    }
  }

  void _viewUserDetails(String userId, Map<String, dynamic> userData, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailItem('Email', userData['email']),
              _buildDetailItem('Role', _getRoleDisplayName(userData['role'])),
              _buildDetailItem('User ID', userId),
              if (userData['createdAt'] != null)
                _buildDetailItem(
                    'Created',
                    DateFormat('MMM dd, yyyy - HH:mm').format(
                        (userData['createdAt'] as Timestamp).toDate()
                    )
                ),

              if (userData['role'] == 'gym_owner') ...[
                const SizedBox(height: 16),
                const Text(
                  'Gym Owner Status:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                _buildDetailItem('Onboarding Completed', userData['onboardingCompleted']?.toString() ?? 'false'),
                _buildDetailItem('Approved', userData['approved']?.toString() ?? 'false'),
                _buildDetailItem('Subscription Active', userData['subscriptionActive']?.toString() ?? 'false'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value ?? 'Not provided'),
        ],
      ),
    );
  }

  void _editUserRole(String userId, Map<String, dynamic> userData, BuildContext context) {
    String currentRole = userData['role'] ?? 'member';
    String? newRole = currentRole;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Change User Role'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select new role for this user:'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: newRole,
                  items: _roles.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(_getRoleDisplayName(role)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      newRole = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (newRole != null && newRole != currentRole) {
                    await _updateUserRole(userId, newRole!);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Update Role'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User role updated to ${_getRoleDisplayName(newRole)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating role: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _createNewUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New User'),
        content: const Text('User creation feature will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}