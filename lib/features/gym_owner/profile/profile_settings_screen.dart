import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/services/cloudinary_config.dart';
import '../../../../core/services/active_gym_manager.dart';
import '../../../../core/utils/cloudinary_helper.dart';
import '../../onboarding/gym_onboarding_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  bool _isLoading = true;
  bool _isUploadingImage = false;
  Map<String, dynamic> _gymData = {};
  final ImagePicker _picker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    _fetchGymProfile();
  }

  Future<void> _fetchGymProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final activeGymId = await ActiveGymManager.getActiveGymId();
      if (activeGymId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final gymDoc = await FirebaseFirestore.instance.collection('gyms').doc(activeGymId).get();
          
      if (gymDoc.exists) {
        final data = gymDoc.data()!;
        data['id'] = gymDoc.id;
        
        try {
          final membersCountSnapshot = await FirebaseFirestore.instance.collection('gyms').doc(gymDoc.id).collection('members').count().get();
          final staffCountSnapshot = await FirebaseFirestore.instance.collection('gyms').doc(gymDoc.id).collection('staff').count().get();
          data['memberCount'] = membersCountSnapshot.count;
          data['staffCount'] = staffCountSnapshot.count;
        } catch (e) {
          debugPrint("Error fetching dynamic counts: $e");
        }

        setState(() {
          _gymData = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching gym profile: \$e");
      setState(() => _isLoading = false);
    }
  }

  void _showGymSwitcherDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Switch Gym', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('gyms').where('ownerId', isEqualTo: user.uid).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading gyms', style: TextStyle(color: AppTheme.alertRed)));
                }
                
                final gyms = snapshot.data?.docs ?? [];
                if (gyms.isEmpty) {
                  return const Center(child: Text('No other gyms found.'));
                }

                return ListView.separated(
                  itemCount: gyms.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final gym = gyms[index];
                    final data = gym.data() as Map<String, dynamic>;
                    final name = data['businessName'] ?? data['gymName'] ?? 'Unnamed Gym';
                    final isActive = gym.id == _gymData['id'];

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                        backgroundImage: data['gymLogoUrl'] != null && data['gymLogoUrl'].isNotEmpty 
                            ? NetworkImage(data['gymLogoUrl']) 
                            : null,
                        child: data['gymLogoUrl'] == null || data['gymLogoUrl'].isEmpty 
                            ? const Icon(Icons.fitness_center_rounded, color: AppTheme.primaryGreen) 
                            : null,
                      ),
                      title: Text(name, style: TextStyle(fontWeight: FontWeight.w600)),
                      trailing: isActive ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen) : null,
                      onTap: () async {
                        if (!isActive) {
                          Navigator.pop(context); // Close dialog
                          setState(() => _isLoading = true);
                          // Set new active gym
                          await ActiveGymManager.setActiveGymId(gym.id);
                          // Reload dashboard data fully
                          _fetchGymProfile();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const GymOnboardingScreen(isAddingNewGym: true)),
                ).then((_) {
                  // Reload Profile after onboarding potential finish
                  setState(() => _isLoading = true);
                  _fetchGymProfile();
                });
              },
              child: const Text('Add New Gym', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Core brand color matching premium corporate feel.
    final primaryColor = AppTheme.primaryGreen;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101010) : const Color(0xFFF9F9FB),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _gymData.isEmpty
              ? Center(child: Text('Profile not found', style: GoogleFonts.inter()))
              : CustomScrollView(
                  slivers: [
                    _buildAppBar(context, primaryColor, isDark),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Gym Info', isDark),
                            const SizedBox(height: 12),
                            // Switch Gym & Edit Actions
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _showGymSwitcherDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryGreen.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.swap_horiz_outlined, 
                                          size: 14, 
                                          color: AppTheme.primaryGreen
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Switch Gym',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _showEditProfileDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit_document, 
                                          size: 14, 
                                          color: isDark ? Colors.white : Colors.black
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Edit',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildPremiumInfoCard(isDark, primaryColor),
                            const SizedBox(height: 24),
                            _buildSectionTitle('Bank Setup & UPI', isDark),
                            const SizedBox(height: 12),
                            _buildBankInfoList(isDark),
                            const SizedBox(height: 24),
                            _buildSectionTitle('Gym Address & Footprint', isDark),
                            const SizedBox(height: 12),
                            _buildInfoList(isDark),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildAppBar(BuildContext context, Color primaryColor, bool isDark) {
    return SliverAppBar(
      expandedHeight: 260.0,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF141414) : const Color(0xFFF9F9FB),
      flexibleSpace: FlexibleSpaceBar(
        background: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            Hero(
                  tag: 'profile-avatar',
                  child: GestureDetector(
                    onTap: _isUploadingImage ? null : _pickAndUploadImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F5),
                            backgroundImage: _gymData['gymLogoUrl'] != null && _gymData['gymLogoUrl'].isNotEmpty 
                                ? NetworkImage(_gymData['gymLogoUrl']) 
                                : null,
                            child: _isUploadingImage 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : _gymData['gymLogoUrl'] == null || _gymData['gymLogoUrl'].isEmpty
                                    ? Icon(Icons.business_rounded, size: 40, color: isDark ? Colors.white70 : Colors.black87)
                                    : null,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : Colors.black,
                            shape: BoxShape.circle,
                            border: Border.all(color: isDark ? const Color(0xFF141414) : Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _gymData['businessName'] ?? 'Business Name',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (_gymData['businessType'] ?? 'Gym').toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumInfoCard(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildDetailRow(Icons.person_outline, 'Owner', _gymData['contact']?['ownerName'] ?? 'N/A', isDark),
          _buildDivider(isDark),
          _buildDetailRow(Icons.email_outlined, 'Email', _gymData['contact']?['email'] ?? 'N/A', isDark),
          _buildDivider(isDark),
          _buildDetailRow(Icons.phone_outlined, 'Phone', _gymData['contact']?['phone'] ?? 'N/A', isDark),
        ],
      ),
    );
  }

  Widget _buildBankInfoList(bool isDark) {
    final String upiId = _gymData['contact']?['upiId'] ?? '';
    final String bankName = _gymData['bankDetails']?['bankName'] ?? '';
    final String acctNum = _gymData['bankDetails']?['accountNumber'] ?? '';
    final String ifsc = _gymData['bankDetails']?['ifscCode'] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildDetailRow(Icons.qr_code_scanner_rounded, 'UPI ID', upiId.isEmpty ? 'Not Set' : upiId, isDark, highlight: upiId.isNotEmpty),
          if (bankName.isNotEmpty) ...[
            _buildDivider(isDark),
            _buildDetailRow(Icons.account_balance_outlined, 'Bank', bankName, isDark),
            _buildDivider(isDark),
            _buildDetailRow(Icons.numbers_rounded, 'A/C Number', acctNum, isDark),
            _buildDivider(isDark),
            _buildDetailRow(Icons.code_rounded, 'IFSC Code', ifsc, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildInfoList(bool isDark) {
    final address = _gymData['address'];
    String fullAddress = 'N/A';

    if (address is Map) {
      final street = address['street']?.toString() ?? '';
      final city = address['city']?.toString() ?? '';
      final state = address['state']?.toString() ?? '';
      final zip = address['postalCode']?.toString() ?? '';
      fullAddress = [street, city, state, zip].where((s) => s.isNotEmpty).join(', ');
    } else if (address is String && address.isNotEmpty) {
      fullAddress = address;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildDetailRow(Icons.location_on_outlined, 'Address', fullAddress.isEmpty ? 'N/A' : fullAddress, isDark, multiLine: true),
          _buildDivider(isDark),
          Row(
            children: [
              Expanded(child: _buildMetricTile('Members', _gymData['memberCount']?.toString() ?? '0', isDark)),
              Container(width: 1, height: 40, color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
              Expanded(child: _buildMetricTile('Staff', _gymData['staffCount']?.toString() ?? '0', isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark, {bool highlight = false, Color? color, bool multiLine = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon, 
              size: 16, 
              color: highlight ? (isDark ? Colors.white : Colors.black) : Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: multiLine ? 3 : 1,
              overflow: multiLine ? TextOverflow.ellipsis : null,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                color: highlight ? (isDark ? Colors.white : Colors.black) : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
      ),
    );
  }

  void _showEditProfileDialog() {
    final businessNameCtrl = TextEditingController(text: _gymData['businessName'] ?? '');
    final phoneCtrl = TextEditingController(text: _gymData['contact']?['phone'] ?? '');
    final upiIdCtrl = TextEditingController(text: _gymData['contact']?['upiId'] ?? '');
    
    // Bank Details
    final bankNameCtrl = TextEditingController(text: _gymData['bankDetails']?['bankName'] ?? '');
    final accountNumberCtrl = TextEditingController(text: _gymData['bankDetails']?['accountNumber'] ?? '');
    final ifscCodeCtrl = TextEditingController(text: _gymData['bankDetails']?['ifscCode'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101010) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Gym Profile',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTextField('Business Name', businessNameCtrl, isDark),
                const SizedBox(height: 16),
                _buildTextField('Phone Number', phoneCtrl, isDark, keyboardType: TextInputType.phone),
                const SizedBox(height: 32),
                
                Text(
                  'Bank & Payment Info',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField('UPI ID', upiIdCtrl, isDark),
                const SizedBox(height: 16),
                _buildTextField('Bank Name', bankNameCtrl, isDark),
                const SizedBox(height: 16),
                _buildTextField('Account Number', accountNumberCtrl, isDark, keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                _buildTextField('IFSC Code', ifscCodeCtrl, isDark, textCapitalization: TextCapitalization.characters),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => _updateProfileData(
                      businessNameCtrl.text.trim(),
                      phoneCtrl.text.trim(),
                      upiIdCtrl.text.trim(),
                      bankNameCtrl.text.trim(),
                      accountNumberCtrl.text.trim(),
                      ifscCodeCtrl.text.trim(),
                    ),
                    child: Text(
                      'Save Changes',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isDark, {TextInputType keyboardType = TextInputType.text, TextCapitalization textCapitalization = TextCapitalization.none}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: isDark ? Colors.white : Colors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white : Colors.black),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Future<void> _updateProfileData(String businessName, String phone, String upiId, String bankName, String accountNum, String ifsc) async {
    Navigator.pop(context); // Close sheet
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final activeGymId = await ActiveGymManager.getActiveGymId();
      if (activeGymId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active gym selected.'), backgroundColor: Colors.red),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final docRef = FirebaseFirestore.instance.collection('gyms').doc(activeGymId);
        
      final contactData = Map<String, dynamic>.from(_gymData['contact'] ?? {});
      contactData['phone'] = phone;
      contactData['upiId'] = upiId;

      final updateData = {
        'businessName': businessName,
        'contact': contactData,
        'bankDetails': {
          'bankName': bankName,
          'accountNumber': accountNum,
          'ifscCode': ifsc,
        }
      };

      await docRef.update(updateData);
      
      // Refresh local UI state
      await _fetchGymProfile();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.black),
        );
      }
    } catch (e) {
      debugPrint("Update error: \$e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: \$e'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final String? secureUrl = await CloudinaryHelper.uploadImage(File(image.path), folder: 'gym_logos');

      if (secureUrl != null) {
        // Update Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final activeGymId = await ActiveGymManager.getActiveGymId();
          if (activeGymId != null) {
            await FirebaseFirestore.instance.collection('gyms').doc(activeGymId).update({'gymLogoUrl': secureUrl});
            await _fetchGymProfile(); // reload data
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile image updated'), backgroundColor: Colors.black),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload failed'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('Upload error: \$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: \$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }
}
