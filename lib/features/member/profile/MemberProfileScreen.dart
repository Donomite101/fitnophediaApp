// member_profile_screen.dart
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:fitnophedia/features/member/profile/terms_conditions_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/app_theme.dart';
import '../../../core/theme_notifier.dart';
import '../../../routes/app_routes.dart';
import '../Subscriptions/member_renewal_subscription.dart';
import 'SupportScreen.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/login_screen.dart';

enum ThemeModeOption { system, light, dark }

class MemberProfileScreen extends StatefulWidget {
  final String gymId;
  final String memberId;

  const MemberProfileScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  Map<String, dynamic>? _memberData;
  bool _isLoading = true;
  bool _isEditing = false;

  ThemeModeOption _themeOption = ThemeModeOption.system;
  bool _notificationsEnabled = true;
  bool _subscriptionEnabled = true;

  // Controllers removed as they are not used in the dashboard view


  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadMemberData();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('app_theme_mode') ?? 'system';
    setState(() {
      _themeOption = theme == 'light'
          ? ThemeModeOption.light
          : (theme == 'dark' ? ThemeModeOption.dark : ThemeModeOption.system);
      _notificationsEnabled = prefs.getBool('push_notifications') ?? true;
    });
  }

  Future<void> _saveThemePreference(ThemeModeOption option) async {
    final prefs = await SharedPreferences.getInstance();
    final str = option == ThemeModeOption.light
        ? 'light'
        : (option == ThemeModeOption.dark ? 'dark' : 'system');
    await prefs.setString('app_theme_mode', str);

  }

  Future<void> _loadMemberData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(widget.gymId)
          .collection('members')
          .doc(widget.memberId)
          .get();

      if (doc.exists) {
        setState(() {
          _memberData = doc.data()!;
          // _initializeControllers(); // Removed

        });
      } else {
        setState(() {
          _memberData = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading member data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }



  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Logout', style: GoogleFonts.poppins())),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.logout();
        
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        debugPrint('Sign out error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout failed: $e')),
          );
        }
      }
    }
  }

  // ---------------- UI helpers to mimic provided image ----------------

  Widget _buildCenteredProfileHeader() {
    final profileImageUrl = _memberData?['profileImageUrl'];
    final firstName = _memberData?['firstName'] ?? '';
    final lastName = _memberData?['lastName'] ?? '';
    final email = _memberData?['email'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Container(
      padding: const EdgeInsets.only(top: 28, bottom: 20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryGreen.withOpacity(0.12),
              boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.08), blurRadius: 20, spreadRadius: 8)],
            ),
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              child: ClipOval(
                child: profileImageUrl != null && profileImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: profileImageUrl,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => Icon(Iconsax.user, size: 36, color: textColor),
                      )
                    : Icon(Iconsax.user, size: 36, color: AppTheme.primaryGreen),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            ('$firstName $lastName').trim().isEmpty ? 'User Name' : '$firstName $lastName',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 6),
          Text(
            email.isEmpty ? 'your.email@domain.com' : email,
            style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 14),

          // Edit profile pill -> opens MemberEditProfileScreen
          ElevatedButton(
            onPressed: () async {
              // Navigate to full edit screen; on return refresh the profile.
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberEditProfileScreen(
                    gymId: widget.gymId,
                    memberId: widget.memberId,
                    initialData: _memberData,
                  ),
                ),
              );
              await _loadMemberData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text('Edit profile', style: GoogleFonts.poppins(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGroup({required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRowItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? iconColor,
    VoidCallback? onTap,
    bool destructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: (iconColor ?? AppTheme.primaryGreen).withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: iconColor ?? AppTheme.primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: destructive ? Colors.redAccent : textColor)),
              if (subtitle != null) const SizedBox(height: 4),
              if (subtitle != null) Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ]),
          ),
          if (trailing != null) 
            IconTheme(
              data: IconThemeData(color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
              child: trailing,
            ),
        ]),
      ),
    );
  }

// In MemberProfileScreen class, update the _personalDetailsGroup method:

// In MemberProfileScreen class, update the _personalDetailsGroup method:

Widget _personalDetailsGroup() {
  return _buildCardGroup(children: [
    _buildRowItem(
      icon: Iconsax.user,
      title: 'View profile',
      subtitle: 'See all personal and fitness details',
      trailing: const Icon(Iconsax.arrow_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberFullProfileScreen(memberData: _memberData ?? {}),
          ),
        );
      },
    ),
    const Divider(height: 1),
    _buildRowItem(
      icon: Iconsax.document,
      title: 'Subscription',
      subtitle: _getSubscriptionSubtitle(),
      trailing: const Icon(Iconsax.arrow_right),
      onTap: () {
        // Use named route instead of MaterialPageRoute
        Navigator.pushNamed(
          context,
          AppRoutes.memberSubscriptionDetails,
          arguments: {
            'gymId': widget.gymId,
            'memberId': widget.memberId,
          },
        );
      },
    ),
  ]);
}
// Add this method to _MemberProfileScreenState to get subscription status
String _getSubscriptionSubtitle() {
  if (_memberData == null) return 'Manage subscription';
  
  final status = _memberData!['subscriptionStatus']?.toString().toLowerCase() ?? '';
  final endDate = _memberData!['subscriptionEndDate'] as Timestamp?;
  
  if (status == 'active' && endDate != null) {
    final daysLeft = endDate.toDate().difference(DateTime.now()).inDays;
    if (daysLeft > 0) {
      return 'Active • $daysLeft days left';
    } else {
      return 'Expired • Renew now';
    }
  } else if (status == 'pending_approval') {
    return 'Pending approval';
  } else {
    return 'No active subscription';
  }
}
  Widget _aboutGroup() {
    return _buildCardGroup(children: [
      _buildRowItem(
        icon: Iconsax.headphone,
        title: 'Support',
        subtitle: 'Contact support',
        trailing: const Icon(Iconsax.arrow_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupportScreen())),
      ),
      const Divider(height: 1),
      _buildRowItem(
        icon: Iconsax.people,
        title: 'My Team',
        subtitle: 'See team members & contacts',
        trailing: const Icon(Iconsax.arrow_right),
        onTap: () => Navigator.pushNamed(context, AppRoutes.myTeam),
      ),

      const Divider(height: 1),
      _buildRowItem(
        icon: Iconsax.document,
        title: 'Terms & Conditions',
        subtitle: 'Read app terms & policies',
        trailing: const Icon(Iconsax.arrow_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TermsConditionsScreen()),
        ),
      ),
    ]);
  }

  Widget _logoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          icon: const Icon(Iconsax.logout, color: Colors.redAccent),
          label: Text('Logout', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: _confirmLogout,
        ),
      ),
    );
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: AppTheme.primaryGreen),
          const SizedBox(height: 12),
          Text('Loading your profile...', style: GoogleFonts.poppins()),
        ])),
      );
    }

    if (_memberData == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppTheme.primaryGreen),
        body: Center(child: Text('Profile not found', style: GoogleFonts.poppins())),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        centerTitle: true,
        title: Text('Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        // edit icon removed as requested
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCenteredProfileHeader(),
            const SizedBox(height: 12),
            // first section: Personal Details (View profile + subscription)
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Align(alignment: Alignment.centerLeft, child: Text('Personal details', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]))),
            ),
            const SizedBox(height: 6),
            _personalDetailsGroup(),
            // about
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8),
              child: Align(alignment: Alignment.centerLeft, child: Text('About', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]))),
            ),
            const SizedBox(height: 6),
            _aboutGroup(),
            _logoutButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();

  }
}

// ---------------- MemberEditProfileScreen ----------------

class MemberEditProfileScreen extends StatefulWidget {
  final String gymId;
  final String memberId;
  final Map<String, dynamic>? initialData;

  const MemberEditProfileScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
    this.initialData,
  }) : super(key: key);

  @override
  State<MemberEditProfileScreen> createState() => _MemberEditProfileScreenState();
}

class _MemberEditProfileScreenState extends State<MemberEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Image upload state
  File? _localPickedImageFile;
  bool _isUploadingImage = false;
  double _uploadProgress = 0.0;

  // Personal
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  // late final TextEditingController _email; // Removed unused controller

  
  // Body Stats
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _targetWeight;
  DateTime? _dateOfBirth; 
  String? _gender;

  // Fitness
  String? _fitnessLevel;
  String? _primaryGoal;
  List<String> _focusedAreas = [];

  // Health
  bool _hasMedicalConditions = false;
  late final TextEditingController _medicalConditions;
  String? _dietType;
  late final TextEditingController _injuryHistory;

  late final TextEditingController _profileImageUrl;

  final List<String> _fitnessLevelOptions = ['Beginner', 'Intermediate', 'Advanced', 'Athlete'];
  final List<String> _goalOptions = ['Weight Loss', 'Muscle Gain', 'Endurance', 'General Fitness', 'Strength'];
  final List<String> _dietOptions = ['None', 'Vegetarian', 'Vegan', 'Keto', 'Paleo'];
  final List<String> _focusAreaOptions = [
    'Chest', 'Back', 'Shoulders', 'Arms', 'Legs',
    'Core', 'Glutes', 'Cardio', 'Flexibility', 'Balance'
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? <String, dynamic>{};

    _firstName = TextEditingController(text: d['firstName'] ?? '');
    _lastName = TextEditingController(text: d['lastName'] ?? '');
    _phone = TextEditingController(text: d['phone'] ?? '');


    
    _height = TextEditingController(text: d['height']?.toString() ?? '');
    _weight = TextEditingController(text: d['weight']?.toString() ?? '');
    _targetWeight = TextEditingController(text: d['targetWeight']?.toString() ?? '');
    
    if (d['dateOfBirth'] is Timestamp) {
      _dateOfBirth = (d['dateOfBirth'] as Timestamp).toDate();
    } else if (d['dateOfBirth'] is String) {
       _dateOfBirth = DateTime.tryParse(d['dateOfBirth']);
    }

    _gender = d['gender'];
    _fitnessLevel = d['fitnessLevel'];
    _primaryGoal = d['primaryGoal'];
    
    if (d['focusedAreas'] is List) {
      _focusedAreas = List<String>.from(d['focusedAreas']);
    }

    _medicalConditions = TextEditingController(text: d['medicalConditions'] ?? '');
    _hasMedicalConditions = (d['hasMedicalConditions'] == true) || _medicalConditions.text.isNotEmpty;
    
    _dietType = d['dietType'];
    _injuryHistory = TextEditingController(text: d['injuryHistory'] ?? '');
    
    _profileImageUrl = TextEditingController(text: d['profileImageUrl'] ?? '');
  }

  // ---------------- Image picker & upload ----------------

  Future<void> _showImageSourceSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Iconsax.gallery), title: const Text('Gallery'), onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); }),
          ListTile(leading: const Icon(Iconsax.camera), title: const Text('Camera'), onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); }),
        ]),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 800);
      if (picked == null) return;
      setState(() => _localPickedImageFile = File(picked.path));
      await _uploadImageToStorage(_localPickedImageFile!);
    } catch (e) {
      debugPrint('Pick error: $e');
    }
  }

  Future<void> _uploadImageToStorage(File file) async {
    setState(() { _isUploadingImage = true; _uploadProgress = 0.0; });
    try {
      final ref = FirebaseStorage.instance.ref().child('members/${widget.memberId}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final task = ref.putFile(file);
      task.snapshotEvents.listen((e) { if(e.totalBytes>0) setState(() => _uploadProgress = e.bytesTransferred / e.totalBytes); });
      await task;
      final url = await ref.getDownloadURL();
      _profileImageUrl.text = url;
      // update doc for image immediately
      await FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('members').doc(widget.memberId).update({'profileImageUrl': url});
    } catch (e) {
      debugPrint('Upload error: $e');
    } finally {
      setState(() { _isUploadingImage = false; _localPickedImageFile = null; });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1995),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppTheme.primaryGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // Calculate age
      int? age;
      if (_dateOfBirth != null) {
        final now = DateTime.now();
        age = now.year - _dateOfBirth!.year;
        if (now.month < _dateOfBirth!.month || (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day)) age--;
      }

      final data = {
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'phone': _phone.text.trim(),
        'dateOfBirth': _dateOfBirth,
        'age': age,
        'gender': _gender,
        'height': double.tryParse(_height.text),
        'weight': double.tryParse(_weight.text),
        'targetWeight': double.tryParse(_targetWeight.text),
        'fitnessLevel': _fitnessLevel,
        'primaryGoal': _primaryGoal,
        'focusedAreas': _focusedAreas,
        'medicalConditions': _hasMedicalConditions ? _medicalConditions.text.trim() : '',
        'hasMedicalConditions': _hasMedicalConditions,
        'dietType': _dietType,
        'injuryHistory': _injuryHistory.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('members').doc(widget.memberId).update(data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600)),
        backgroundColor: isDark ? Colors.transparent : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: textColor),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Center(child: _buildAvatarSection()),
              const SizedBox(height: 30),

              _buildSectionTitle('Personal Details'),
              _buildTextField('First Name', _firstName, Iconsax.user, required: true),
              _buildTextField('Last Name', _lastName, Iconsax.user),
              _buildTextField('Phone', _phone, Iconsax.call, type: TextInputType.phone),
              
              const SizedBox(height: 20),
              _buildSectionTitle('Body Statistics'),
              Row(children: [
                Expanded(child: _buildGenderSelector()),
              ]),
              const SizedBox(height: 16),
               GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: _buildTextField(
                    'Date of Birth', 
                    TextEditingController(text: _dateOfBirth != null ? DateFormat('MMM dd, yyyy').format(_dateOfBirth!) : ''), 
                    Iconsax.calendar_1,
                    hint: 'Select Date'
                  ),
                ),
              ),
              Row(children: [
                Expanded(child: _buildTextField('Height (cm)', _height, Iconsax.ruler, type: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('Weight (kg)', _weight, Iconsax.monitor, type: TextInputType.number)),
              ]),

              const SizedBox(height: 20),
              _buildSectionTitle('Fitness Goals'),
              _buildDropdown('Fitness Level', _fitnessLevel, _fitnessLevelOptions, (v) => setState(() => _fitnessLevel = v)),
              const SizedBox(height: 16),
              _buildDropdown('Primary Goal', _primaryGoal, _goalOptions, (v) => setState(() => _primaryGoal = v)),
              const SizedBox(height: 16),
              _buildTextField('Target Weight (kg)', _targetWeight, Iconsax.flag, type: TextInputType.number),
              const SizedBox(height: 16),
              _buildMultiSelect('Areas to Focus', _focusedAreas, _focusAreaOptions),

              const SizedBox(height: 20),
              _buildSectionTitle('Health & Lifestyle'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppTheme.primaryGreen,
                title: Text('Any Medical Conditions?', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: textColor)),
                value: _hasMedicalConditions, 
                onChanged: (v) => setState(() => _hasMedicalConditions = v)
              ),

              if (_hasMedicalConditions)
                _buildTextField('Specify Conditions', _medicalConditions, Iconsax.health, maxLines: 2),
              
              const SizedBox(height: 16),
              _buildDropdown('Diet Preference', _dietType, _dietOptions, (v) => setState(() => _dietType = v), hint: 'None'),
              const SizedBox(height: 16),
              _buildTextField('Existing Injuries (Optional)', _injuryHistory, Iconsax.danger, maxLines: 2),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving || _isUploadingImage ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text('Save Changes', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
             Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.2), width: 2),
                ),
                child: ClipOval(
                  child: _localPickedImageFile != null
                    ? Image.file(_localPickedImageFile!, fit: BoxFit.cover)
                    : (_profileImageUrl.text.isNotEmpty 
                        ? CachedNetworkImage(imageUrl: _profileImageUrl.text, fit: BoxFit.cover, errorWidget: (_,__,___) => const Icon(Iconsax.user))
                        : Icon(Iconsax.user, size: 50, color: AppTheme.primaryGreen)),
                ),
             ),
             GestureDetector(
               onTap: _showImageSourceSheet,
               child: Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                 child: const Icon(Iconsax.edit, size: 16, color: Colors.white),
               ),
             ),
          ],
        ),
        if (_isUploadingImage) 
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Uploading...', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey))),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, {bool required = false, TextInputType type = TextInputType.text, int maxLines = 1, String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        maxLines: maxLines,
        style: TextStyle(color: textColor),
        validator: required ? (v) => (v==null||v.isEmpty) ? 'Required' : null : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
          prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey.shade500, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: cardColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryGreen)),
        ),
      ),
    );

  }

  Widget _buildGenderSelector() {
    return Row(
      children: [
        Expanded(child: _genderOption('Male', Icons.male)),
        const SizedBox(width: 12),
        Expanded(child: _genderOption('Female', Icons.female)),
      ],
    );
  }

  Widget _genderOption(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final isSelected = _gender == label;
    final textColor = isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.grey.shade800);
    
    return GestureDetector(
      onTap: () => setState(() => _gender = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.primaryGreen : (isDark ? Colors.white12 : Colors.grey.shade200)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey.shade600), size: 20),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor)),
          ],
        ),
      ),
    );
  }


  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged, {String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          hint: Text(hint ?? 'Select $label', style: GoogleFonts.poppins(color: isDark ? Colors.grey[400] : Colors.grey.shade500)),
          isExpanded: true,
          dropdownColor: cardColor,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.poppins(color: textColor)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }


  Widget _buildMultiSelect(String label, List<String> selected, List<String> options) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final cardColor = Theme.of(context).cardColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: textColor)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSel = selected.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: isSel,
              onSelected: (v) => setState(() {
                  if(v) selected.add(opt); else selected.remove(opt);
              }),
              backgroundColor: cardColor,
              selectedColor: AppTheme.primaryGreen.withOpacity(0.15),
              labelStyle: GoogleFonts.poppins(color: isSel ? AppTheme.primaryGreen : (isDark ? Colors.grey[300] : Colors.grey.shade700), fontWeight: isSel?FontWeight.w600:FontWeight.normal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSel ? AppTheme.primaryGreen : (isDark ? Colors.white12 : Colors.grey.shade200))),
              checkmarkColor: AppTheme.primaryGreen,
            );
          }).toList(),
        ),
      ],
    );
  }


  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _height.dispose();
    _weight.dispose();
    _targetWeight.dispose();
    _medicalConditions.dispose();
    _injuryHistory.dispose();
    _profileImageUrl.dispose();
    super.dispose();
  }
}

// ---------------- MemberFullProfileScreen ----------------

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
                  Stack(
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
                          backgroundImage: memberData['profileImageUrl'] != null && memberData['profileImageUrl'].isNotEmpty
                              ? NetworkImage(memberData['profileImageUrl'])
                              : null,
                          child: (memberData['profileImageUrl'] == null || memberData['profileImageUrl'].isEmpty) 
                              ? Icon(Iconsax.user, size: 40, color: AppTheme.primaryGreen) : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: cardColor, width: 2),
                          ),
                          child: const Icon(Iconsax.edit, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
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
