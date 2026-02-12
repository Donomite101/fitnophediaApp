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

  // Controllers for editable form in this screen are used only to prefill new edit screen
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // other controllers are reused when showing details inside "full profile screen"
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  final TextEditingController _goalsController = TextEditingController();
  final TextEditingController _medicalController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  final TextEditingController _dietaryController = TextEditingController();
  final TextEditingController _sleepController = TextEditingController();
  final TextEditingController _waterController = TextEditingController();
  final TextEditingController _stepsController = TextEditingController();
  final TextEditingController _previousExperienceController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _currentFitnessRoutineController = TextEditingController();
  final TextEditingController _favoriteExercisesController = TextEditingController();
  final TextEditingController _injuryHistoryController = TextEditingController();
  final TextEditingController _mentalHealthController = TextEditingController();
  final TextEditingController _waistController = TextEditingController();
  final TextEditingController _hipController = TextEditingController();
  final TextEditingController _chestController = TextEditingController();
  final TextEditingController _bodyFatController = TextEditingController();

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
          _initializeControllers();
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

  void _initializeControllers() {
    if (_memberData == null) return;
    _firstNameController.text = _memberData!['firstName'] ?? '';
    _lastNameController.text = _memberData!['lastName'] ?? '';
    _phoneController.text = _memberData!['phone'] ?? '';
    _emailController.text = _memberData!['email'] ?? '';

    _heightController.text = _memberData!['height']?.toString() ?? '';
    _weightController.text = _memberData!['weight']?.toString() ?? '';
    _targetWeightController.text = _memberData!['targetWeight']?.toString() ?? '';
    _goalsController.text = _memberData!['specificGoals'] ?? '';
    _medicalController.text = _memberData!['medicalConditions'] ?? '';
    _allergiesController.text = _memberData!['allergies'] ?? '';
    _medicationsController.text = _memberData!['medications'] ?? '';
    _dietaryController.text = _memberData!['dietaryRestrictions'] ?? '';
    _sleepController.text = _memberData!['sleepHours']?.toString() ?? '';
    _waterController.text = _memberData!['waterIntake']?.toString() ?? '';
    _stepsController.text = _memberData!['dailySteps']?.toString() ?? '';
    _previousExperienceController.text = _memberData!['previousExperience'] ?? '';
    _emergencyContactController.text = _memberData!['emergencyContact'] ?? '';
    _emergencyPhoneController.text = _memberData!['emergencyPhone'] ?? '';
    _currentFitnessRoutineController.text = _memberData!['currentFitnessRoutine'] ?? '';
    _favoriteExercisesController.text = _memberData!['favoriteExercises'] ?? '';
    _injuryHistoryController.text = _memberData!['injuryHistory'] ?? '';
    _mentalHealthController.text = _memberData!['mentalHealthNotes'] ?? '';
    _waistController.text = _memberData!['waistCircumference']?.toString() ?? '';
    _hipController.text = _memberData!['hipCircumference']?.toString() ?? '';
    _chestController.text = _memberData!['chestCircumference']?.toString() ?? '';
    _bodyFatController.text = _memberData!['bodyFatPercentage']?.toString() ?? '';
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
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Sign out error: $e');
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  // ---------------- UI helpers to mimic provided image ----------------

  Widget _buildCenteredProfileHeader() {
    final profileImageUrl = _memberData?['profileImageUrl'];
    final firstName = _memberData?['firstName'] ?? '';
    final lastName = _memberData?['lastName'] ?? '';
    final email = _memberData?['email'] ?? '';

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
              backgroundColor: Colors.white,
              child: ClipOval(
                child: profileImageUrl != null && profileImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: profileImageUrl,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const Icon(Iconsax.user, size: 36),
                      )
                    : const Icon(Iconsax.user, size: 36),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            ('$firstName $lastName').trim().isEmpty ? 'User Name' : '$firstName $lastName',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            email.isEmpty ? 'your.email@domain.com' : email,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
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
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text('Edit profile', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGroup({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
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
              Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: destructive ? Colors.redAccent : null)),
              if (subtitle != null) const SizedBox(height: 4),
              if (subtitle != null) Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
            ]),
          ),
          if (trailing != null) trailing,
        ]),
      ),
    );
  }

  Widget _personalDetailsGroup() {
    return _buildCardGroup(children: [
      _buildRowItem(
        icon: Iconsax.user,
        title: 'View profile',
        subtitle: 'See all personal and fitness details',
        trailing: const Icon(Iconsax.arrow_right),
        onTap: () {
          // Navigate to full profile screen (full screen)
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
        subtitle: 'Manage subscription',
        trailing: const Icon(Iconsax.arrow_right),
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.memberSubscription,
            arguments: {'gymId': widget.gymId, 'memberId': widget.memberId},
          );
        },
      ),
    ]);
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _goalsController.dispose();
    _medicalController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _dietaryController.dispose();
    _sleepController.dispose();
    _waterController.dispose();
    _stepsController.dispose();
    _previousExperienceController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    _currentFitnessRoutineController.dispose();
    _favoriteExercisesController.dispose();
    _injuryHistoryController.dispose();
    _mentalHealthController.dispose();
    _waistController.dispose();
    _hipController.dispose();
    _chestController.dispose();
    _bodyFatController.dispose();
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

  // All controllers for fields present in view screen
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _dateOfBirth; // will be filled by date picker (yyyy-MM-dd)
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _targetWeight;
  late final TextEditingController _bmi;
  late final TextEditingController _bodyFat;
  late final TextEditingController _bmr;
  late final TextEditingController _waist;
  late final TextEditingController _hip;
  late final TextEditingController _chest;
  late final TextEditingController _bodyType;

  // Fitness & goals
  late final TextEditingController _primaryGoal;
  late final TextEditingController _specificGoals;
  late final TextEditingController _fitnessLevel;
  late final TextEditingController _workoutPreference;
  late final TextEditingController _activityLevel;
  late final TextEditingController _focusedAreas; // comma separated input -> List<String>

  // Health & lifestyle
  late final TextEditingController _medicalConditions;
  late final TextEditingController _allergies;
  late final TextEditingController _medications;
  late final TextEditingController _injuryHistory;
  late final TextEditingController _mentalHealthNotes;
  late final TextEditingController _dietaryRestrictions;
  late final TextEditingController _sleepHours;
  late final TextEditingController _waterIntake;
  late final TextEditingController _dailySteps;

  // Emergency + other
  late final TextEditingController _emergencyContact;
  late final TextEditingController _emergencyPhone;
  late final TextEditingController _bloodGroup;
  late final TextEditingController _occupation;
  late final TextEditingController _profileImageUrl; // holds current uploaded URL

  @override
  void initState() {
    super.initState();
    final d = widget.initialData ?? <String, dynamic>{};

    _firstName = TextEditingController(text: d['firstName'] ?? '');
    _lastName = TextEditingController(text: d['lastName'] ?? '');
    _email = TextEditingController(text: d['email'] ?? '');
    _phone = TextEditingController(text: d['phone'] ?? '');

    // DOB handling: if Timestamp, format to yyyy-MM-dd
    if (d['dateOfBirth'] is Timestamp) {
      _dateOfBirth = TextEditingController(text: DateFormat('yyyy-MM-dd').format((d['dateOfBirth'] as Timestamp).toDate()));
    } else {
      _dateOfBirth = TextEditingController(text: d['dateOfBirth']?.toString() ?? '');
    }

    _height = TextEditingController(text: d['height']?.toString() ?? '');
    _weight = TextEditingController(text: d['weight']?.toString() ?? '');
    _targetWeight = TextEditingController(text: d['targetWeight']?.toString() ?? '');
    _bmi = TextEditingController(text: d['bmi']?.toString() ?? '');
    _bodyFat = TextEditingController(text: d['bodyFatPercentage']?.toString() ?? '');
    _bmr = TextEditingController(text: d['bmr']?.toString() ?? '');
    _waist = TextEditingController(text: d['waistCircumference']?.toString() ?? '');
    _hip = TextEditingController(text: d['hipCircumference']?.toString() ?? '');
    _chest = TextEditingController(text: d['chestCircumference']?.toString() ?? '');
    _bodyType = TextEditingController(text: d['bodyType'] ?? '');

    _primaryGoal = TextEditingController(text: d['primaryGoal'] ?? '');
    _specificGoals = TextEditingController(text: d['specificGoals'] ?? '');
    _fitnessLevel = TextEditingController(text: d['fitnessLevel'] ?? '');
    _workoutPreference = TextEditingController(text: d['workoutPreference'] ?? '');
    _activityLevel = TextEditingController(text: d['activityLevel'] ?? '');
    _focusedAreas = TextEditingController(text: (d['focusedAreas'] is List) ? (d['focusedAreas'] as List).join(', ') : (d['focusedAreas']?.toString() ?? ''));

    _medicalConditions = TextEditingController(text: d['medicalConditions'] ?? '');
    _allergies = TextEditingController(text: d['allergies'] ?? '');
    _medications = TextEditingController(text: d['medications'] ?? '');
    _injuryHistory = TextEditingController(text: d['injuryHistory'] ?? '');
    _mentalHealthNotes = TextEditingController(text: d['mentalHealthNotes'] ?? '');
    _dietaryRestrictions = TextEditingController(text: d['dietaryRestrictions'] ?? '');
    _sleepHours = TextEditingController(text: d['sleepHours']?.toString() ?? '');
    _waterIntake = TextEditingController(text: d['waterIntake']?.toString() ?? '');
    _dailySteps = TextEditingController(text: d['dailySteps']?.toString() ?? '');

    _emergencyContact = TextEditingController(text: d['emergencyContact'] ?? '');
    _emergencyPhone = TextEditingController(text: d['emergencyPhone'] ?? '');
    _bloodGroup = TextEditingController(text: d['bloodGroup'] ?? '');
    _occupation = TextEditingController(text: d['occupation'] ?? '');
    _profileImageUrl = TextEditingController(text: d['profileImageUrl'] ?? '');
  }

  // ---------------- Image picker & upload ----------------

  Future<void> _showImageSourceSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Iconsax.gallery), title: const Text('Choose from gallery'), onTap: () {
              Navigator.of(ctx).pop();
              _pickImage(ImageSource.gallery);
            }),
            ListTile(leading: const Icon(Iconsax.camera), title: const Text('Take a photo'), onTap: () {
              Navigator.of(ctx).pop();
              _pickImage(ImageSource.camera);
            }),
            ListTile(leading: const Icon(Iconsax.close_square), title: const Text('Cancel'), onTap: () => Navigator.of(ctx).pop()),
          ]),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot upload image while offline'), backgroundColor: Colors.orange));
      return;
    }
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1200);
      if (picked == null) return;
      setState(() => _localPickedImageFile = File(picked.path));
      await _uploadImageToStorage(_localPickedImageFile!);
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image error: $e')));
    }
  }

  Future<void> _uploadImageToStorage(File file) async {
    setState(() {
      _isUploadingImage = true;
      _uploadProgress = 0.0;
    });

    final storage = FirebaseStorage.instance;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'members/${widget.memberId}/profile_$timestamp.jpg';
    final ref = storage.ref().child(path);
    final uploadTask = ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));

    uploadTask.snapshotEvents.listen((event) {
      if (event.totalBytes > 0) {
        setState(() => _uploadProgress = event.bytesTransferred / event.totalBytes);
      }
    });

    try {
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Delete old image if present (best-effort)
      final oldUrl = _profileImageUrl.text;
      if (oldUrl.isNotEmpty) {
        try {
          final oldRef = FirebaseStorage.instance.refFromURL(oldUrl);
          await oldRef.delete();
        } catch (e) {
          debugPrint('Old image delete failed (non-fatal): $e');
        }
      }

      // update controller + member doc immediately with new URL
      _profileImageUrl.text = downloadUrl;
      await FirebaseFirestore.instance
          .collection('gyms')
          .doc(widget.gymId)
          .collection('members')
          .doc(widget.memberId)
          .set({'profileImageUrl': downloadUrl, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile image updated'), backgroundColor: AppTheme.primaryGreen));
    } catch (e) {
      debugPrint('Upload failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
    } finally {
      if (mounted) setState(() {
        _isUploadingImage = false;
        _uploadProgress = 0.0;
        _localPickedImageFile = null; // we've uploaded and saved URL
      });
    }
  }

  // ---------------- Date picker ----------------

  Future<void> _pickDateOfBirth() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 25));
    if ((_dateOfBirth.text).isNotEmpty) {
      final parsed = DateTime.tryParse(_dateOfBirth.text);
      if (parsed != null) initial = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _dateOfBirth.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  // ---------------- Save ----------------

  Future<void> _save() async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity.contains(ConnectivityResult.none);
    
    if (!_formKey.currentState!.validate()) return;
    if (_isUploadingImage) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please wait for the image upload to finish')));
      return;
    }
    
    if (isOffline) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Working offline. Changes will be saved when you are online.'), backgroundColor: Colors.orange));
    }

    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> updateData = {
        // Personal
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        // dateOfBirth parsing (try ISO yyyy-MM-dd)
        if (_dateOfBirth.text.trim().isNotEmpty) 'dateOfBirth': Timestamp.fromDate(DateTime.parse(_dateOfBirth.text.trim())),
        'occupation': _occupation.text.trim(),
        'bloodGroup': _bloodGroup.text.trim(),
        'profileImageUrl': _profileImageUrl.text.trim(),

        // Body metrics (defensive parsing)
        'height': double.tryParse(_height.text),
        'weight': double.tryParse(_weight.text),
        'targetWeight': double.tryParse(_targetWeight.text),
        'bmi': double.tryParse(_bmi.text),
        'bodyFatPercentage': double.tryParse(_bodyFat.text),
        'bmr': double.tryParse(_bmr.text),
        'waistCircumference': double.tryParse(_waist.text),
        'hipCircumference': double.tryParse(_hip.text),
        'chestCircumference': double.tryParse(_chest.text),
        'bodyType': _bodyType.text.trim(),

        // Fitness & goals
        'primaryGoal': _primaryGoal.text.trim(),
        'specificGoals': _specificGoals.text.trim(),
        'fitnessLevel': _fitnessLevel.text.trim(),
        'workoutPreference': _workoutPreference.text.trim(),
        'activityLevel': _activityLevel.text.trim(),
        'focusedAreas': _focusedAreas.text.trim().isEmpty
            ? []
            : _focusedAreas.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),

        // Health & Lifestyle
        'medicalConditions': _medicalConditions.text.trim(),
        'allergies': _allergies.text.trim(),
        'medications': _medications.text.trim(),
        'injuryHistory': _injuryHistory.text.trim(),
        'mentalHealthNotes': _mentalHealthNotes.text.trim(),
        'dietaryRestrictions': _dietaryRestrictions.text.trim(),
        'sleepHours': double.tryParse(_sleepHours.text),
        'waterIntake': double.tryParse(_waterIntake.text),
        'dailySteps': int.tryParse(_dailySteps.text),

        // Emergency
        'emergencyContact': _emergencyContact.text.trim(),
        'emergencyPhone': _emergencyPhone.text.trim(),

        'updatedAt': FieldValue.serverTimestamp(),
      };

      // remove null / empty string / empty list entries so we don't overwrite with empties
      updateData.removeWhere((k, v) {
        if (v == null) return true;
        if (v is String && v.isEmpty) return true;
        if (v is List && v.isEmpty) return true;
        return false;
      });

      final memberRef = FirebaseFirestore.instance.collection('gyms').doc(widget.gymId).collection('members').doc(widget.memberId);
      await memberRef.set(updateData, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved'), backgroundColor: AppTheme.primaryGreen));
        Navigator.pop(context);
      }
    } catch (e, st) {
      debugPrint('Save profile error: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------- UI small helpers ----------------

  Widget _avatarPicker() {
    final url = _profileImageUrl.text;
    final ImageProvider? displayImageProvider = _localPickedImageFile != null
        ? FileImage(_localPickedImageFile!)
        : (url.isNotEmpty ? CachedNetworkImageProvider(url) : null);

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            InkWell(
              onTap: _showImageSourceSheet,
              borderRadius: BorderRadius.circular(80),
              child: CircleAvatar(
                radius: 46,
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.12),
                child: displayImageProvider != null
                    ? ClipOval(child: Image(image: displayImageProvider as ImageProvider, width: 92, height: 92, fit: BoxFit.cover))
                    : const Icon(Iconsax.user, size: 48),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _showImageSourceSheet,
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Iconsax.camera, size: 18, color: Colors.black54),
                ),
              ),
            )
          ],
        ),
        if (_isUploadingImage) ...[
          const SizedBox(height: 8),
          SizedBox(width: 140, child: LinearProgressIndicator(value: _uploadProgress)),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _rowField(String label, TextEditingController controller, {TextInputType keyboard = TextInputType.text, int maxLines = 1, String? hint, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: validator,
      ),
    );
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _dateOfBirth.dispose();
    _height.dispose();
    _weight.dispose();
    _targetWeight.dispose();
    _bmi.dispose();
    _bodyFat.dispose();
    _bmr.dispose();
    _waist.dispose();
    _hip.dispose();
    _chest.dispose();
    _bodyType.dispose();

    _primaryGoal.dispose();
    _specificGoals.dispose();
    _fitnessLevel.dispose();
    _workoutPreference.dispose();
    _activityLevel.dispose();
    _focusedAreas.dispose();

    _medicalConditions.dispose();
    _allergies.dispose();
    _medications.dispose();
    _injuryHistory.dispose();
    _mentalHealthNotes.dispose();
    _dietaryRestrictions.dispose();
    _sleepHours.dispose();
    _waterIntake.dispose();
    _dailySteps.dispose();

    _emergencyContact.dispose();
    _emergencyPhone.dispose();
    _bloodGroup.dispose();
    _occupation.dispose();
    _profileImageUrl.dispose();

    super.dispose();
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit profile', style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Center(child: _avatarPicker()),
                Row(children: [
                  Expanded(child: _rowField('First name', _firstName, validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null)),
                  const SizedBox(width: 10),
                  Expanded(child: _rowField('Last name', _lastName)),
                ]),
                _rowField('Email', _email, keyboard: TextInputType.emailAddress, validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'Required';
                  if (!s.contains('@')) return 'Invalid email';
                  return null;
                }),
                Row(children: [
                  Expanded(child: _rowField('Phone', _phone, keyboard: TextInputType.phone)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDateOfBirth,
                      child: AbsorbPointer(child: _rowField('DOB (yyyy-MM-dd)', _dateOfBirth, keyboard: TextInputType.datetime, hint: 'yyyy-MM-dd')),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('Body Metrics', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _rowField('Height (cm)', _height, keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _rowField('Weight (kg)', _weight, keyboard: TextInputType.number)),
                ]),
                Row(children: [
                  Expanded(child: _rowField('Target weight (kg)', _targetWeight, keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _rowField('BMI', _bmi, keyboard: TextInputType.number)),
                ]),
                Row(children: [
                  Expanded(child: _rowField('Body fat %', _bodyFat, keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _rowField('BMR', _bmr, keyboard: TextInputType.number)),
                ]),
                Row(children: [
                  Expanded(child: _rowField('Waist (cm)', _waist, keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _rowField('Hip (cm)', _hip, keyboard: TextInputType.number)),
                ]),
                Row(children: [
                  Expanded(child: _rowField('Chest (cm)', _chest, keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _rowField('Body type', _bodyType)),
                ]),
                const SizedBox(height: 12),
                Text('Fitness & Goals', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _rowField('Primary goal', _primaryGoal),
                _rowField('Specific goals', _specificGoals, maxLines: 3),
                Row(children: [
                  Expanded(child: _rowField('Fitness level', _fitnessLevel)),
                  const SizedBox(width: 10),
                  Expanded(child: _rowField('Workout preference', _workoutPreference)),
                ]),
                Row(children: [
                  Expanded(child: _rowField('Activity level', _activityLevel)),
                  const SizedBox(width: 10),
                  Expanded(child: _rowField('Focused areas (comma separated)', _focusedAreas)),
                ]),
                const SizedBox(height: 12),
                Text('Health & Lifestyle', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _rowField('Medical conditions', _medicalConditions, maxLines: 3),
                _rowField('Allergies', _allergies),
                _rowField('Medications', _medications),
                _rowField('Injury history', _injuryHistory, maxLines: 2),
                _rowField('Mental health notes', _mentalHealthNotes, maxLines: 2),
                _rowField('Dietary restrictions', _dietaryRestrictions),
                Row(children: [
                  Expanded(child: _rowField('Sleep hours', _sleepHours, keyboard: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _rowField('Water intake (L)', _waterIntake, keyboard: TextInputType.number)),
                ]),
                _rowField('Daily steps', _dailySteps, keyboard: TextInputType.number),
                const SizedBox(height: 12),
                Text('Emergency Contact', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _rowField('Contact name', _emergencyContact)),
                  const SizedBox(width: 10),
                  Expanded(child: _rowField('Contact phone', _emergencyPhone, keyboard: TextInputType.phone)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _rowField('Blood group', _bloodGroup)),
                  const SizedBox(width: 10),
                  Expanded(child: _rowField('Occupation', _occupation)),
                ]),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: (_isSaving || _isUploadingImage) ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, minimumSize: const Size.fromHeight(48)),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Save', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// ---------------- MemberFullProfileScreen ----------------

class MemberFullProfileScreen extends StatelessWidget {
  final Map<String, dynamic> memberData;
  const MemberFullProfileScreen({Key? key, required this.memberData}) : super(key: key);

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(children: [
        Expanded(flex: 2, child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
        Expanded(flex: 3, child: Text(value.isEmpty ? 'Not set' : value, style: GoogleFonts.poppins())),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = memberData['createdAt'] is Timestamp ? (memberData['createdAt'] as Timestamp).toDate() : null;
    return Scaffold(
      appBar: AppBar(title: Text('Profile details', style: GoogleFonts.poppins()), backgroundColor: AppTheme.primaryGreen),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.12),
              child: memberData['profileImageUrl'] != null && (memberData['profileImageUrl'] as String).isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: memberData['profileImageUrl'],
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const Icon(Iconsax.user, size: 40),
                      ),
                    )
                  : const Icon(Iconsax.user, size: 40),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text('${memberData['firstName'] ?? ''} ${memberData['lastName'] ?? ''}', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600))),
          if (createdAt != null) Center(child: Text('Member since ${DateFormat('MMM yyyy').format(createdAt)}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]))),
          const SizedBox(height: 18),

          // Personal section
          Text('Personal Information', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          infoRow('Email', memberData['email'] ?? ''),
          infoRow('Phone', memberData['phone'] ?? ''),
          infoRow('DOB', memberData['dateOfBirth'] is Timestamp ? DateFormat('MMM dd, yyyy').format((memberData['dateOfBirth'] as Timestamp).toDate()) : (memberData['dateOfBirth']?.toString() ?? '')),
          infoRow('Gender', memberData['gender'] ?? ''),
          infoRow('Occupation', memberData['occupation'] ?? ''),

          const SizedBox(height: 16),
          Text('Body Metrics', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          infoRow('Height (cm)', memberData['height']?.toString() ?? ''),
          infoRow('Weight (kg)', memberData['weight']?.toString() ?? ''),
          infoRow('Target weight (kg)', memberData['targetWeight']?.toString() ?? ''),
          infoRow('BMI', memberData['bmi']?.toString() ?? ''),
          infoRow('Body fat %', memberData['bodyFatPercentage']?.toString() ?? ''),

          const SizedBox(height: 16),
          Text('Fitness & Goals', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          infoRow('Primary goal', memberData['primaryGoal'] ?? ''),
          infoRow('Specific goals', memberData['specificGoals'] ?? ''),
          infoRow('Fitness level', memberData['fitnessLevel'] ?? ''),

          const SizedBox(height: 16),
          Text('Health & Lifestyle', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          infoRow('Medical conditions', memberData['medicalConditions'] ?? ''),
          infoRow('Allergies', memberData['allergies'] ?? ''),
          infoRow('Medications', memberData['medications'] ?? ''),
          infoRow('Dietary restrictions', memberData['dietaryRestrictions'] ?? ''),
          infoRow('Sleep hours', memberData['sleepHours']?.toString() ?? ''),

          const SizedBox(height: 16),
          Text('Emergency Contact', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          infoRow('Contact name', memberData['emergencyContact'] ?? ''),
          infoRow('Phone', memberData['emergencyPhone'] ?? ''),

          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}
