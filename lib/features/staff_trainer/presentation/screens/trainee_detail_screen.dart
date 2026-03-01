import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/app_theme.dart';

class TraineeDetailScreen extends StatelessWidget {
  final String gymId;
  final String trainerId;
  final String memberId;
  final String memberName;
  final Map<String, dynamic> memberData;

  const TraineeDetailScreen({
    Key? key,
    required this.gymId,
    required this.trainerId,
    required this.memberId,
    required this.memberName,
    required this.memberData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(memberName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.wallet),
            onPressed: () => _openPaymentDialog(context),
            tooltip: 'Receive Payment',
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMemberStats(isDark),
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader('Assign Workout & Diet', () {}),
                  const SizedBox(height: 12),
                  _buildActionButtons(context, isDark),
                  const SizedBox(height: 24),

                  _buildSectionHeader('Workout History', () {}),
                  const SizedBox(height: 12),
                  _buildTrackerList(isDark, collectionName: 'assigned_workouts', icon: Iconsax.weight),

                  const SizedBox(height: 24),
                  _buildSectionHeader('Diet Plans', () {}),
                  const SizedBox(height: 12),
                  _buildTrackerList(isDark, collectionName: 'assigned_diets', icon: Iconsax.cup),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberStats(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statCol('Age', memberData['age']?.toString() ?? '24', isDark),
          _statCol('Weight', memberData['weight']?.toString() ?? '75 kg', isDark),
          _statCol('Goal', memberData['fitnessGoal'] ?? 'Muscle Gain', isDark),
        ],
      ),
    );
  }

  Widget _statCol(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _assignAction(context, 'Assign Workout', 'assigned_workouts'),
            icon: const Icon(Iconsax.add_circle, size: 16),
            label: const Text('Workout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _assignAction(context, 'Assign Diet', 'assigned_diets'),
            icon: const Icon(Iconsax.add_circle, size: 16),
            label: const Text('Diet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _assignAction(BuildContext context, String actionType, String collectionName) async {
    final _ctrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(actionType, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _ctrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe the $actionType details...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_ctrl.text.isEmpty) return;
              
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(memberId)
                  .collection(collectionName)
                  .add({
                'trainerId': trainerId,
                'details': _ctrl.text,
                'createdAt': FieldValue.serverTimestamp(),
                'status': 'active', // active, completed
              });
              
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$actionType successfully!'), backgroundColor: AppTheme.primaryGreen)
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text('Assign', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerList(bool isDark, {required String collectionName, required IconData icon}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(memberId)
          .collection(collectionName)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Text('No records found.', style: GoogleFonts.inter(color: Colors.grey));

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(icon, color: AppTheme.primaryGreen),
                title: Text(data['details'] ?? 'Assigned Plan', maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('Status: ${data['status']}'),
                trailing: const Icon(Iconsax.arrow_right_3, size: 16),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _openPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Direct Payment', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receive direct payment from $memberName.', style: GoogleFonts.inter()),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Text('A commission config will transfer appropriate portion to the Gym Owner.', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Request Sent'), backgroundColor: AppTheme.primaryGreen));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text('Request Setup', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
