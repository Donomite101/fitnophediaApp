import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/app_theme.dart';

class MemberFullProfileScreen extends StatelessWidget {
  final Map<String, dynamic> memberData;
  const MemberFullProfileScreen({Key? key, required this.memberData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dob = memberData['dateOfBirth'] is Timestamp 
        ? (memberData['dateOfBirth'] as Timestamp).toDate() 
        : (memberData['dateOfBirth'] is String ? DateTime.tryParse(memberData['dateOfBirth']) : null);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    // Calculate BMI
    double? bmi;
    try {
      final h = double.tryParse(memberData['height'].toString()) ?? 0;
      final w = double.tryParse(memberData['weight'].toString()) ?? 0;
      if (h > 0 && w > 0) {
        bmi = w / ((h / 100) * (h / 100));
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('My Profile', style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // 1. Profile Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                      ? [const Color(0xFF1E1E1E), const Color(0xFF121212)] 
                      : [const Color(0xFFFFFFFF), const Color(0xFFF5F5F7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                   Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.5), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                      backgroundImage: (memberData['profileImageUrl'] ?? memberData['photoUrl'] ?? memberData['imageUrl'] ?? '').isNotEmpty
                          ? NetworkImage(memberData['profileImageUrl'] ?? memberData['photoUrl'] ?? memberData['imageUrl'] ?? '')
                          : null,
                      child: (memberData['profileImageUrl'] ?? memberData['photoUrl'] ?? memberData['imageUrl'] ?? '').isEmpty 
                          ? Icon(Iconsax.user, size: 40, color: AppTheme.primaryGreen) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${memberData['firstName'] ?? ''} ${memberData['lastName'] ?? ''}',
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    memberData['email'] ?? memberData['phone'] ?? '',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      memberData['fitnessLevel'] ?? 'Member',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 2. Stats Ledger
            Row(
              children: [
                Expanded(child: _buildLedgerItem(context, 'Height', '${memberData['height'] ?? '--'} cm')),
                const SizedBox(width: 12),
                Expanded(child: _buildLedgerItem(context, 'Weight', '${memberData['weight'] ?? '--'} kg')),
                const SizedBox(width: 12),
                Expanded(child: _buildLedgerItem(context, 'BMI', bmi?.toStringAsFixed(1) ?? '--')),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // 3. Goal & Focus Section
            _buildModernSection(
              context,
              title: "Goals & Focus",
              icon: Iconsax.flag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildInfoRow(context, 'Primary Goal', memberData['primaryGoal'], isHighlight: true),
                   const SizedBox(height: 12),
                   _buildInfoRow(context, 'Target Weight', '${memberData['targetWeight'] ?? '--'} kg'),
                   const SizedBox(height: 16),
                   Text('Focus Areas', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                   const SizedBox(height: 8),
                   _buildFocusAreas(context, memberData['focusedAreas']),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 4. Personal Details
            _buildModernSection(
              context,
              title: "Personal Details", 
              icon: Iconsax.personalcard,
              child: Column(
                children: [
                  _buildInfoRow(context, 'Gender', memberData['gender']),
                   const SizedBox(height: 12),
                  _buildInfoRow(context, 'Birthday', dob != null ? DateFormat('MMM dd, yyyy').format(dob) : '--'),
                   const SizedBox(height: 12),
                  _buildInfoRow(context, 'Phone', memberData['phone']),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 5. Health info
            _buildModernSection(
              context,
              title: "Health & Medical",
              icon: Iconsax.health,
              child: Column(
                children: [
                  _buildInfoRow(context, 'Medical Conditions', memberData['medicalConditions']?.isEmpty ?? true ? 'None' : memberData['medicalConditions']),
                  const SizedBox(height: 12),
                  _buildInfoRow(context, 'Injuries', memberData['injuryHistory']?.isEmpty ?? true ? 'None' : memberData['injuryHistory']),
                   const SizedBox(height: 12),
                  _buildInfoRow(context, 'Diet Type', memberData['dietType']),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerItem(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(isDark?0.2:0.03), blurRadius: 10, offset: const Offset(0,4))
        ],
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildModernSection(BuildContext context, {required String title, required IconData icon, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String? value, {bool isHighlight = false}) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
        Expanded(
          child: Text(
            value ?? '--',
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
              color: isHighlight ? AppTheme.primaryGreen : textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFocusAreas(BuildContext context, dynamic areas) {
    if (areas == null || areas is! List || areas.isEmpty) {
      return Text('None selected', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey));
    }
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: areas.map<Widget>((area) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
             color: AppTheme.primaryGreen.withOpacity(0.1),
             borderRadius: BorderRadius.circular(20),
             border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
          ),
          child: Text(
            area.toString(),
            style: GoogleFonts.poppins(
              fontSize: 12, 
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryGreen
            ),
          ),
        );
      }).toList(),
    );
  }
}
