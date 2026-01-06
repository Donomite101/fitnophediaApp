import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../routes/app_routes.dart';
import '../../../core/app_theme.dart';

class CloudinaryConfig {
  static const String cloudName = 'dntnzraxh'; // Replace with your cloud name
  static const String uploadPreset = 'gym_uploads'; // Replace with your upload preset

  static const String uploadFolder = 'profile_photos';
  static const int maxFileSize = 5 * 1024 * 1024; // 5MB
  static const int imageQuality = 80;
  static const int maxWidth = 800;
  static const int maxHeight = 800;
}

class MemberProfileSetupScreen extends StatefulWidget {
  final Map<String, dynamic> args;
  const MemberProfileSetupScreen({Key? key, required this.args}) : super(key: key);

  @override
  State<MemberProfileSetupScreen> createState() => _MemberProfileSetupScreenState();
}

class _MemberProfileSetupScreenState extends State<MemberProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _goalsController = TextEditingController();
  final _medicalController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _dietaryController = TextEditingController();
  final _sleepController = TextEditingController();
  final _waterController = TextEditingController();
  final _stepsController = TextEditingController();
  final _previousExperienceController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _currentFitnessRoutineController = TextEditingController();
  final _favoriteExercisesController = TextEditingController();
  final _injuryHistoryController = TextEditingController();
  final _mentalHealthController = TextEditingController();
  final _waistController = TextEditingController();
  final _hipController = TextEditingController();
  final _chestController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _workoutPreferenceController = TextEditingController();
  final _activityLevelController = TextEditingController();
  final _workoutFrequencyController = TextEditingController();
  final _workoutDurationController = TextEditingController();
  final _motivationLevelController = TextEditingController();

  // Profile Image Variables
  File? _profileImageFile;
  String? _profileImageUrl;
  bool _isUploadingImage = false;

  // Personal Information
  DateTime? _dateOfBirth;
  String? _gender;
  String? _bloodGroup;
  String? _maritalStatus;
  String? _occupation;

  // Body Metrics
  String? _bodyType;
  double? _waistCircumference;
  double? _hipCircumference;
  double? _chestCircumference;
  double? _bodyFatPercentage;
  bool _weightUnitKg = true;
  bool _heightUnitCm = true;
  double _currentWeight = 66.2;
  double _currentHeight = 182.0;

  // Fitness Goals & Experience
  String? _fitnessLevel;
  String? _primaryGoal;
  String? _workoutPreference;
  String? _activityLevel;
  String? _workoutFrequency;
  String? _workoutDuration;
  String? _motivationLevel;
  List<String> _focusedAreas = [];
  List<String> _avoidAreas = [];

  // Health Information
  String? _dietType;
  String? _stressLevel;
  String? _sleepQuality;
  String? _energyLevel;
  bool _hasMedicalConditions = false;
  bool _smoker = false;
  bool _alcohol = false;
  bool _pregnant = false;
  bool _previousSurgery = false;
  bool _familyHeartDisease = false;
  bool _familyDiabetes = false;

  // Lifestyle & Habits
  String? _mealFrequency;
  String? _waterIntakeGoal;
  String? _alcoholFrequency;
  String? _smokingFrequency;
  String? _caffeineIntake;
  String? _supplements;
  String? _fitnessTracking;

  bool _isLoading = false;
  int _currentStep = 0;

  // Focus areas options
  final List<String> _focusAreaOptions = [
    'Chest', 'Back', 'Shoulders', 'Arms', 'Legs',
    'Core', 'Glutes', 'Cardio', 'Flexibility', 'Balance'
  ];

  // Avoid areas options
  final List<String> _avoidAreaOptions = [
    'Neck', 'Lower Back', 'Knees', 'Shoulders', 'Wrists',
    'Ankles', 'Hips', 'Elbows', 'None'
  ];

  // Step titles for the complete flow
  final List<String> _stepTitles = [
    'Personal Details',
    'Birth Date',
    'Your Gender',
    'Your Height',
    'Your Weight',
    'Body Metrics',
    'Fitness Goals',
    'Health Info',
    'Lifestyle'
  ];

  @override
  void initState() {
    super.initState();
    _dayController = FixedExtentScrollController(initialItem: selectedDay - 1);
    _monthController = FixedExtentScrollController(initialItem: months.indexOf(selectedMonth));
    _yearController = FixedExtentScrollController(initialItem: currentYear - selectedYear);
    _prefillExistingData();
  }

  Future<void> _prefillExistingData() async {
    try {
      final gymId = widget.args['gymId'];
      final memberId = widget.args['memberId'];
      final memberRef = FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId);

      final doc = await memberRef.get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          if (data['dateOfBirth'] != null) {
            _dateOfBirth = (data['dateOfBirth'] as Timestamp).toDate();
          }
          _gender = data['gender'];
          _heightController.text = data['height']?.toString() ?? '';
          _weightController.text = data['weight']?.toString() ?? '';
          _profileImageUrl = data['profileImageUrl'];
          if (data['weight'] != null) {
            _currentWeight = (data['weight'] as num).toDouble();
          }
          if (data['height'] != null) {
            _currentHeight = (data['height'] as num).toDouble();
          }
        });
      }
    } catch (e) {
      debugPrint('Error pre-filling data: $e');
    }
  }

  // Profile Image Methods
  Future<void> _pickProfileImage() async {
    try {
      final int? qualityInt = CloudinaryConfig.imageQuality; // likely int or null
      final double? maxW = CloudinaryConfig.maxWidth != null
          ? (CloudinaryConfig.maxWidth is double
          ? CloudinaryConfig.maxWidth as double
          : (CloudinaryConfig.maxWidth as num).toDouble())
          : null;
      final double? maxH = CloudinaryConfig.maxHeight != null
          ? (CloudinaryConfig.maxHeight is double
          ? CloudinaryConfig.maxHeight as double
          : (CloudinaryConfig.maxHeight as num).toDouble())
          : null;

      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: qualityInt, // int? is correct here
        maxWidth: maxW,           // double?
        maxHeight: maxH,          // double?
      );

      if (picked == null) return; // user cancelled

      final file = File(picked.path);
      if (!await file.exists()) {
        _showError('Selected image file not found');
        return;
      }

      final fileSize = await file.length();
      if (fileSize > CloudinaryConfig.maxFileSize) {
        _showError('Image too large. Please select under 5MB.');
        return;
      }

      setState(() {
        _profileImageFile = file;
        _isUploadingImage = true;
      });

      // Upload to Cloudinary (your existing uploader)
      final uploadedUrl = await _uploadProfileImageToCloudinary(_profileImageFile!);

      setState(() {
        _profileImageUrl = uploadedUrl;
        _isUploadingImage = false;
      });
    } catch (e, st) {
      debugPrint('Error picking image: $e\n$st');
      _showError('Failed to pick image.');
      setState(() => _isUploadingImage = false);
    }
  }


  // Cloudinary upload method
  Future<String?> _uploadProfileImageToCloudinary(File imageFile) async {
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
        ..fields['folder'] = CloudinaryConfig.uploadFolder
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      debugPrint('Uploading profile image to Cloudinary: ${imageFile.path}');

      final response = await request.send().timeout(const Duration(seconds: 40));
      final resStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(resStr);
        final secureUrl = data['secure_url'] as String?;
        debugPrint('Cloudinary upload success: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('Cloudinary upload failed (${response.statusCode}): $resStr');
        _showError('Upload failed (HTTP ${response.statusCode})');
        return null;
      }
    } on TimeoutException {
      _showError('Upload timed out. Please try again.');
      return null;
    } catch (e) {
      debugPrint('Upload error: $e');
      _showError('Failed to upload image.');
      return null;
    }
  }

  // Alternative Firebase Storage upload method
  Future<String?> _uploadProfileImageToFirebase(File imageFile) async {
    try {
      final gymId = widget.args['gymId'];
      final memberId = widget.args['memberId'];

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('gyms/$gymId/members/$memberId/profile_image.jpg');

      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Firebase Storage upload success: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading to Firebase Storage: $e');
      _showError('Failed to upload image to storage.');
      return null;
    }
  }

  // Error display method
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.alertRed,
      ),
    );
  }

  Widget _buildProfileAvatar() {
    if (_isUploadingImage) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryGreen,
          ),
        ),
      );
    }

    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.primaryGreen,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: Image.network(
            _profileImageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  color: AppTheme.primaryGreen,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading profile image: $error');
              return _buildDefaultAvatar();
            },
          ),
        ),
      );
    }

    if (_profileImageFile != null) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.primaryGreen,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: Image.file(
            _profileImageFile!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultAvatar();
            },
          ),
        ),
      );
    }

    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Icon(
        Icons.person,
        size: 40,
        color: AppTheme.primaryGreen,
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final gymId = widget.args['gymId'];
    final memberId = widget.args['memberId'];
    final memberEmail = widget.args['email'];
    final memberName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';

    try {
      final memberRef = FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId);

      // Calculate BMI and other metrics
      double height = _currentHeight;
      double weight = _currentWeight;
      double bmi = height > 0 ? weight / ((height / 100) * (height / 100)) : 0;

      // Calculate BMR (Basal Metabolic Rate)
      double bmr = _calculateBMR(weight, height, _calculateAge());

      // Prepare comprehensive profile data
      Map<String, dynamic> profileData = {
        // Personal Information
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dateOfBirth': _dateOfBirth,
        'gender': _gender,
        'bloodGroup': _bloodGroup,
        'maritalStatus': _maritalStatus,
        'occupation': _occupation,
        'age': _calculateAge(),
        'emergencyContact': _emergencyContactController.text.trim(),
        'emergencyPhone': _emergencyPhoneController.text.trim(),
        'profileImageUrl': _profileImageUrl,

        // Body Metrics
        'height': height,
        'weight': weight,
        'targetWeight': double.tryParse(_targetWeightController.text),
        'bmi': double.parse(bmi.toStringAsFixed(1)),
        'bmiCategory': _getBMICategory(bmi),
        'bodyType': _bodyType,
        'waistCircumference': _waistCircumference,
        'hipCircumference': _hipCircumference,
        'chestCircumference': _chestCircumference,
        'bodyFatPercentage': _bodyFatPercentage,
        'bmr': bmr,

        // Fitness Goals & Experience
        'fitnessLevel': _fitnessLevel,
        'primaryGoal': _primaryGoal,
        'specificGoals': _goalsController.text.trim(),
        'workoutPreference': _workoutPreference,
        'activityLevel': _activityLevel,
        'workoutFrequency': _workoutFrequency,
        'workoutDuration': _workoutDuration,
        'motivationLevel': _motivationLevel,
        'focusedAreas': _focusedAreas,
        'avoidAreas': _avoidAreas,
        'previousExperience': _previousExperienceController.text.trim(),
        'currentFitnessRoutine': _currentFitnessRoutineController.text.trim(),
        'favoriteExercises': _favoriteExercisesController.text.trim(),

        // Health Information
        'medicalConditions': _medicalController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'medications': _medicationsController.text.trim(),
        'injuryHistory': _injuryHistoryController.text.trim(),
        'mentalHealthNotes': _mentalHealthController.text.trim(),
        'hasMedicalConditions': _hasMedicalConditions,
        'smoker': _smoker,
        'alcohol': _alcohol,
        'pregnant': _pregnant,
        'previousSurgery': _previousSurgery,
        'familyHeartDisease': _familyHeartDisease,
        'familyDiabetes': _familyDiabetes,

        // Lifestyle & Habits
        'dietType': _dietType,
        'dietaryRestrictions': _dietaryController.text.trim(),
        'sleepHours': double.tryParse(_sleepController.text),
        'sleepQuality': _sleepQuality,
        'waterIntake': double.tryParse(_waterController.text),
        'waterIntakeGoal': _waterIntakeGoal,
        'dailySteps': int.tryParse(_stepsController.text),
        'stressLevel': _stressLevel,
        'energyLevel': _energyLevel,
        'mealFrequency': _mealFrequency,
        'alcoholFrequency': _alcoholFrequency,
        'smokingFrequency': _smokingFrequency,
        'caffeineIntake': _caffeineIntake,
        'supplements': _supplements,
        'fitnessTracking': _fitnessTracking,

        // System Fields
        'profileCompleted': true,
        'profileCompletionDate': DateTime.now(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastHealthAssessment': DateTime.now(),
        'aiTrainingDataReady': true,
      };

      await memberRef.update(profileData);

      // Navigate based on subscription status
      final updatedDoc = await memberRef.get();
      final updatedData = updatedDoc.data() ?? {};
      final hasOngoingSubscription =
          (updatedData['hasOngoingSubscription'] ?? false) == true;

      if (hasOngoingSubscription) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.memberDashboard,
              (route) => false,
        );
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.memberSubscription,
              (route) => false,
          arguments: {
            'gymId': gymId,
            'memberId': memberId,
            'memberName': memberName,
            'memberEmail': memberEmail,
          },
        );
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Profile saved! Your AI trainer is being configured...'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _calculateBMR(double weight, double height, int? age) {
    if (age == null || weight == 0 || height == 0) return 0;

    // Mifflin-St Jeor Equation
    if (_gender == 'Male') {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
  }

  int? _calculateAge() {
    if (_dateOfBirth == null) return null;
    DateTime now = DateTime.now();
    int age = now.year - _dateOfBirth!.year;
    if (now.month < _dateOfBirth!.month ||
        (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalDetailsStep();
      case 1:
        return _buildBirthDateStep();
      case 2:
        return _buildGenderStep();
      case 3:
        return _buildHeightStep();
      case 4:
        return _buildWeightStep();
      case 5:
        return _buildBodyMetricsStep();
      case 6:
        return _buildFitnessGoalsStep();
      case 7:
        return _buildHealthInfoStep();
      case 8:
        return _buildLifestyleStep();
      default:
        return _buildPersonalDetailsStep();
    }
  }

  // Step 0: Personal Details
  Widget _buildPersonalDetailsStep() {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subtitleColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Personal Details',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about yourself to personalize your experience',
            style: TextStyle(
              fontSize: 16,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 30),

          // Profile Image Section
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    _buildProfileAvatar(),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isUploadingImage ? null : _pickProfileImage,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _isUploadingImage ? Icons.hourglass_top :
                            (_profileImageUrl != null ? Icons.edit : Icons.add_a_photo),
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _isUploadingImage ? null : _pickProfileImage,
                  child: Text(
                    _isUploadingImage ? 'Uploading...' : 'Or add your own photo',
                    style: TextStyle(
                      fontSize: 16,
                      color: _isUploadingImage ? Colors.grey : AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_isUploadingImage) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we upload your photo...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Form Fields
          _buildFormField(
            controller: _firstNameController,
            label: 'First Name',
            hint: 'Enter your first name',
            icon: Icons.person,
            required: true,
          ),
          _buildFormField(
            controller: _lastNameController,
            label: 'Last Name',
            hint: 'Enter your last name',
            icon: Icons.person_outline,
            required: true,
          ),
          _buildFormField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: 'Enter your phone number',
            icon: Icons.phone,
            required: true,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildBirthDateStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          const Text(
            "What's your Birthday?",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Text(
            'Your birthday helps us customize your experience based on your age',
            style: TextStyle(fontSize: 16, color: Colors.black.withOpacity(0.6)),
          ),

          const SizedBox(height: 50),

          // Beautiful 3-wheel date picker with center highlight and fade effects
          Center(
            child: SizedBox(
              height: 220,
              child: Stack(
                children: [
                  // Background container
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),

                  // Top fade effect
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.95),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom fade effect
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.white.withOpacity(0.95),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Center highlight bar (rounded capsule)
                  Center(
                    child: Container(
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),

                  // Date wheels
                  Row(
                    children: [
                      // Day wheel
                      _buildDateWheel(
                        items: List.generate(31, (i) => (i + 1).toString().padLeft(2, '0')),
                        controller: _dayController,
                        selectedValue: selectedDay.toString().padLeft(2, '0'),
                        onChanged: (index) => setState(() => selectedDay = index + 1),
                      ),

                      _verticalDivider(),

                      // Month wheel
                      _buildDateWheel(
                        items: months,
                        controller: _monthController,
                        selectedValue: selectedMonth,
                        onChanged: (index) => setState(() => selectedMonth = months[index]),
                      ),

                      _verticalDivider(),

                      // Year wheel
                      _buildDateWheel(
                        items: List.generate(100, (i) => (currentYear - i).toString()),
                        controller: _yearController,
                        selectedValue: selectedYear.toString(),
                        onChanged: (index) => setState(() => selectedYear = currentYear - index),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 60), // Extra bottom space
        ],
      ),
    );
  }

// Helper widgets
  Widget _buildDateWheel({
    required List<String> items,
    required FixedExtentScrollController controller,
    required String selectedValue,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 60,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        perspective: 0.005,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: items.length,
          builder: (context, index) {
            final value = items[index];
            final bool isSelected = value == selectedValue;

            return Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: isSelected ? 1.0 : 0.4,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    fontSize: isSelected ? 26 : 20,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.green : Colors.green.withOpacity(0.7),
                  ),
                  child: Text(value),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _verticalDivider() => Container(
    width: 1,
    color: Colors.grey.withOpacity(0.2),
    margin: const EdgeInsets.symmetric(vertical: 20),
  );

// Add these in your State class
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;

  final List<String> months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final int currentYear = DateTime.now().year;

  int selectedDay = 20;
  String selectedMonth = 'Mar';
  int selectedYear = 1994;


  // Step 2: Gender
  Widget _buildGenderStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),

          Text(
            "Select Gender",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'To show you accurate Cyms list',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 50),

          // Gender options - only Male and Female
          Row(
            children: [
              Expanded(
                child: _buildGenderCard('Male', Icons.male),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildGenderCard('Female', Icons.female),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderCard(String gender, IconData icon) {
    final isSelected = _gender == gender;

    return GestureDetector(
      onTap: () => setState(() => _gender = gender),
      child: Container(
        height: 140, // Fixed height for square-like appearance
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.primaryGreen,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              gender,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // Step 3: Height
  Widget _buildHeightStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            'Your Height',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We use your height to personalize your fitness and nutrition plan',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 40),

          // Height display - matching reference exactly
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  '${_currentHeight.toStringAsFixed(0)}\ncm',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Height value display
          Center(
            child: Text(
              '${_currentHeight.toStringAsFixed(0)} cm',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Height slider with exact markers from reference
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Slider(
                  value: _currentHeight,
                  min: 140,
                  max: 220,
                  divisions: 80,
                  onChanged: (value) => setState(() => _currentHeight = value),
                  activeColor: AppTheme.primaryGreen,
                  inactiveColor: Colors.grey.shade300,
                ),
                const SizedBox(height: 8),
                // Height markers - exact values from reference
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (int i = 180; i <= 186; i++)
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          '$i',
                          style: TextStyle(
                            fontSize: 12,
                            color: i == _currentHeight.round() ? AppTheme.primaryGreen : Colors.grey,
                            fontWeight: i == _currentHeight.round() ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 4: Weight
  Widget _buildWeightStep() {
    final bmi = _currentHeight > 0 ? _currentWeight / ((_currentHeight / 100) * (_currentHeight / 100)) : 0.0;
    final bmiCategory = _getBMICategory(bmi);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            'Your Current Weight',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We use your weight to tailor your fitness and nutrition plan',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 30),

          // BMI Scale - matching reference exactly
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                // BMI Categories
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBMICategory('Underweight', '15'),
                    _buildBMICategory('Normal', '20'),
                    _buildBMICategory('Overweight', '25'),
                    _buildBMICategory('Obese', '30'),
                  ],
                ),
                const SizedBox(height: 16),

                // BMI Progress Bar
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade400,
                        Colors.green.shade400,
                        Colors.orange.shade400,
                        Colors.red.shade400,
                      ],
                      stops: const [0.15, 0.4, 0.65, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),

                // BMI Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your BMI shows that you are $bmiCategory',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    Text(
                      'BMI: ${bmi.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Weight display
          Center(
            child: Text(
              '${_currentWeight.toStringAsFixed(1)} kg',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Weight slider with exact markers from reference
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Slider(
                  value: _currentWeight,
                  min: 40,
                  max: 150,
                  divisions: 110,
                  onChanged: (value) => setState(() => _currentWeight = value),
                  activeColor: AppTheme.primaryGreen,
                  inactiveColor: Colors.grey.shade300,
                ),
                const SizedBox(height: 8),
                // Weight markers - exact values from reference
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (int i = 64; i <= 68; i++)
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          '$i',
                          style: TextStyle(
                            fontSize: 12,
                            color: i == _currentWeight.round() ? AppTheme.primaryGreen : Colors.grey,
                            fontWeight: i == _currentWeight.round() ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBMICategory(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // Step 5: Body Metrics
  Widget _buildBodyMetricsStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              'Body Metrics',
              'Additional body measurements for precise fitness planning'
          ),
          _buildFormField(
            controller: _targetWeightController,
            label: 'Target Weight (kg)',
            hint: 'Your goal weight',
            icon: Icons.flag,
            keyboardType: TextInputType.number,
          ),
          _buildDropdownField(
            label: 'Body Type',
            value: _bodyType,
            items: ['Ectomorph', 'Mesomorph', 'Endomorph'],
            onChanged: (value) => setState(() => _bodyType = value),
            hint: 'Select your body type',
          ),
          _buildFormField(
            controller: _waistController,
            label: 'Waist Circumference (cm)',
            hint: 'Enter waist measurement',
            icon: Icons.straighten,
            keyboardType: TextInputType.number,
            onChanged: (value) => _waistCircumference = double.tryParse(value),
          ),
          _buildFormField(
            controller: _hipController,
            label: 'Hip Circumference (cm)',
            hint: 'Enter hip measurement',
            icon: Icons.straighten,
            keyboardType: TextInputType.number,
            onChanged: (value) => _hipCircumference = double.tryParse(value),
          ),
          _buildFormField(
            controller: _chestController,
            label: 'Chest Circumference (cm)',
            hint: 'Enter chest measurement',
            icon: Icons.straighten,
            keyboardType: TextInputType.number,
            onChanged: (value) => _chestCircumference = double.tryParse(value),
          ),
          _buildFormField(
            controller: _bodyFatController,
            label: 'Body Fat Percentage',
            hint: 'Enter body fat percentage',
            icon: Icons.pie_chart,
            keyboardType: TextInputType.number,
            onChanged: (value) => _bodyFatPercentage = double.tryParse(value),
          ),
        ],
      ),
    );
  }

  // Step 6: Fitness Goals
  Widget _buildFitnessGoalsStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildSectionHeader(
              'Fitness Goals & Experience',
              'Help us understand your fitness journey and aspirations'
          ),

          // Fitness Level & Primary Goal (Required)
          _buildDropdownField(
            label: 'Fitness Level',
            value: _fitnessLevel,
            items: ['Beginner', 'Intermediate', 'Advanced', 'Athlete'],
            onChanged: (value) => setState(() => _fitnessLevel = value),
            required: true,
          ),

          _buildDropdownField(
            label: 'Primary Goal',
            value: _primaryGoal,
            items: [
              'Weight Loss',
              'Muscle Gain',
              'Endurance',
              'Strength',
              'Toning',
              'General Fitness',
              'Sports Performance',
              'Rehabilitation'
            ],
            onChanged: (value) => setState(() => _primaryGoal = value),
            required: true,
          ),

          // Specific Goals
          _buildFormField(
            controller: _goalsController,
            label: 'Specific Goals',
            hint: 'Describe your specific fitness goals...',
            icon: Icons.flag,
            maxLines: 3,
          ),

          // Focus Areas
          _buildMultiSelectChips(
            label: 'Focus Areas',
            selectedItems: _focusedAreas,
            options: _focusAreaOptions,
            onSelectionChanged: (items) => setState(() => _focusedAreas = items),
          ),

          // Areas to Avoid
          _buildMultiSelectChips(
            label: 'Areas to Avoid',
            selectedItems: _avoidAreas,
            options: _avoidAreaOptions,
            onSelectionChanged: (items) => setState(() => _avoidAreas = items),
          ),

          // Experience
          _buildFormField(
            controller: _previousExperienceController,
            label: 'Previous Experience',
            hint: 'Describe your previous fitness experience...',
            icon: Icons.history,
            maxLines: 3,
          ),

          _buildFormField(
            controller: _currentFitnessRoutineController,
            label: 'Current Fitness Routine',
            hint: 'Describe your current workout routine...',
            icon: Icons.fitness_center,
            maxLines: 3,
          ),

          _buildFormField(
            controller: _favoriteExercisesController,
            label: 'Favorite Exercises',
            hint: 'Exercises you enjoy doing...',
            icon: Icons.favorite,
            maxLines: 2,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Step 7: Health Information
  Widget _buildHealthInfoStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildSectionHeader(
              'Health Information',
              'Important health details for safe and effective training'
          ),

          // Medical Conditions
          _buildToggleField(
            label: 'Existing Medical Conditions',
            value: _hasMedicalConditions,
            onChanged: (value) => setState(() => _hasMedicalConditions = value),
            description: 'Do you have any medical conditions we should know about?',
          ),

          if (_hasMedicalConditions) ...{
            _buildFormField(
              controller: _medicalController,
              label: 'Medical Conditions',
              hint: 'Describe your medical conditions...',
              icon: Icons.medical_services,
              maxLines: 3,
            ),
          },

          // Allergies & Medications
          _buildFormField(
            controller: _allergiesController,
            label: 'Allergies',
            hint: 'List any allergies...',
            icon: Icons.warning,
            maxLines: 2,
          ),

          _buildFormField(
            controller: _medicationsController,
            label: 'Current Medications',
            hint: 'List current medications...',
            icon: Icons.medication,
            maxLines: 2,
          ),

          // Injury History
          _buildFormField(
            controller: _injuryHistoryController,
            label: 'Injury History',
            hint: 'Previous injuries or surgeries...',
            icon: Icons.healing,
            maxLines: 3,
          ),

          // Mental Health
          _buildFormField(
            controller: _mentalHealthController,
            label: 'Mental Health Notes',
            hint: 'Any mental health considerations...',
            icon: Icons.psychology,
            maxLines: 2,
          ),

          // Medical History Toggles
          _buildToggleField(
            label: 'Previous Surgery',
            value: _previousSurgery,
            onChanged: (value) => setState(() => _previousSurgery = value),
          ),

          _buildToggleField(
            label: 'Family History - Heart Disease',
            value: _familyHeartDisease,
            onChanged: (value) => setState(() => _familyHeartDisease = value),
          ),

          _buildToggleField(
            label: 'Family History - Diabetes',
            value: _familyDiabetes,
            onChanged: (value) => setState(() => _familyDiabetes = value),
          ),

          // Female-specific
          if (_gender == 'Female') ...{
            _buildToggleField(
              label: 'Pregnant',
              value: _pregnant,
              onChanged: (value) => setState(() => _pregnant = value),
            ),
          },

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Step 8: Lifestyle
  Widget _buildLifestyleStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildSectionHeader(
              'Lifestyle & Habits',
              'Daily habits that impact your fitness journey'
          ),

          // Diet Information
          _buildDropdownField(
            label: 'Diet Type',
            value: _dietType,
            items: [
              'Omnivore',
              'Vegetarian',
              'Vegan',
              'Pescatarian',
              'Keto',
              'Paleo',
              'Mediterranean',
              'Flexitarian'
            ],
            onChanged: (value) => setState(() => _dietType = value),
            hint: 'Select your diet type',
          ),

          _buildFormField(
            controller: _dietaryController,
            label: 'Dietary Restrictions',
            hint: 'Food allergies, intolerances, or restrictions...',
            icon: Icons.food_bank,
            maxLines: 2,
          ),

          // Sleep Information
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  controller: _sleepController,
                  label: 'Sleep (hours)',
                  hint: 'Average per night',
                  icon: Icons.bedtime,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField(
                  label: 'Sleep Quality',
                  value: _sleepQuality,
                  items: ['Poor', 'Fair', 'Good', 'Excellent'],
                  onChanged: (value) => setState(() => _sleepQuality = value),
                  hint: 'Select quality',
                ),
              ),
            ],
          ),

          // Water Information
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  controller: _waterController,
                  label: 'Water (liters)',
                  hint: 'Daily intake',
                  icon: Icons.water_drop,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField(
                  label: 'Water Intake Goal',
                  value: _waterIntakeGoal,
                  items: ['2L', '3L', '4L', '5L+'],
                  onChanged: (value) => setState(() => _waterIntakeGoal = value),
                  hint: 'Select goal',
                ),
              ),
            ],
          ),

          // Daily Activity
          _buildFormField(
            controller: _stepsController,
            label: 'Daily Steps',
            hint: 'Average steps per day',
            icon: Icons.directions_walk,
            keyboardType: TextInputType.number,
          ),

          // Mental Wellbeing
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Stress Level',
                  value: _stressLevel,
                  items: ['Low', 'Moderate', 'High', 'Very High'],
                  onChanged: (value) => setState(() => _stressLevel = value),
                  hint: 'Select level',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField(
                  label: 'Energy Level',
                  value: _energyLevel,
                  items: ['Very Low', 'Low', 'Moderate', 'High', 'Very High'],
                  onChanged: (value) => setState(() => _energyLevel = value),
                  hint: 'Select level',
                ),
              ),
            ],
          ),

          // Habits
          _buildToggleField(
            label: 'Smoker',
            value: _smoker,
            onChanged: (value) => setState(() => _smoker = value),
          ),

          if (_smoker) ...{
            _buildDropdownField(
              label: 'Smoking Frequency',
              value: _smokingFrequency,
              items: ['Occasionally', 'Daily', 'Several times daily'],
              onChanged: (value) => setState(() => _smokingFrequency = value),
              hint: 'Select frequency',
            ),
          },

          _buildToggleField(
            label: 'Alcohol Consumer',
            value: _alcohol,
            onChanged: (value) => setState(() => _alcohol = value),
          ),

          if (_alcohol) ...{
            _buildDropdownField(
              label: 'Alcohol Frequency',
              value: _alcoholFrequency,
              items: ['Occasionally', 'Weekly', 'Daily'],
              onChanged: (value) => setState(() => _alcoholFrequency = value),
              hint: 'Select frequency',
            ),
          },

          // Additional Lifestyle
          _buildDropdownField(
            label: 'Caffeine Intake',
            value: _caffeineIntake,
            items: ['None', '1 cup/day', '2-3 cups/day', '4+ cups/day'],
            onChanged: (value) => setState(() => _caffeineIntake = value),
            hint: 'Select intake',
          ),

          _buildDropdownField(
            label: 'Supplements',
            value: _supplements,
            items: ['None', 'Protein', 'Vitamins', 'Pre-workout', 'Multiple'],
            onChanged: (value) => setState(() => _supplements = value),
            hint: 'Select supplements',
          ),

          _buildDropdownField(
            label: 'Fitness Tracking',
            value: _fitnessTracking,
            items: ['None', 'Smartwatch', 'Fitness App', 'Manual Log'],
            onChanged: (value) => setState(() => _fitnessTracking = value),
            hint: 'Select tracking method',
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Helper methods
  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: Colors.black87, fontSize: 16),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: '$label${required ? ' *' : ''}',
          hintText: hint,
          labelStyle: TextStyle(color: Colors.black54, fontSize: 14),
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          prefixIcon: Icon(icon, color: AppTheme.primaryGreen, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: required ? (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        } : null,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    bool required = false,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: Colors.white,
        style: TextStyle(color: Colors.black87, fontSize: 16),
        decoration: InputDecoration(
          labelText: '$label${required ? ' *' : ''}',
          labelStyle: TextStyle(color: Colors.black54, fontSize: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryGreen, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        items: [
          DropdownMenuItem(
            value: null,
            child: Text(hint ?? 'Select $label', style: TextStyle(color: Colors.grey.shade500)),
          ),
          ...items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, style: TextStyle(color: Colors.black87)),
            );
          }),
        ],
        onChanged: onChanged,
        validator: required ? (value) {
          if (value == null || value.isEmpty) {
            return 'Please select $label';
          }
          return null;
        } : null,
      ),
    );
  }

  Widget _buildMultiSelectChips({
    required String label,
    required List<String> selectedItems,
    required List<String> options,
    required Function(List<String>) onSelectionChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = selectedItems.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (option == 'None') {
                        selectedItems.clear();
                        selectedItems.add('None');
                      } else {
                        selectedItems.remove('None');
                        selectedItems.add(option);
                      }
                    } else {
                      selectedItems.remove(option);
                    }
                    onSelectionChanged(selectedItems);
                  });
                },
                selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                checkmarkColor: AppTheme.primaryGreen,
                backgroundColor: Theme.of(context).colorScheme.surface,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primaryGreen : Theme.of(context).colorScheme.onSurface,
                ),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleField({
    required String label,
    required bool value,
    required Function(bool) onChanged,
    String? description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Capsule/Dot Progress Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_stepTitles.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                height: 8,
                width: index == _currentStep ? 28 : 10,
                decoration: BoxDecoration(
                  color: index <= _currentStep
                      ? AppTheme.primaryGreen
                      : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          const SizedBox(height: 12),

          // Step counter text
          Text(
            'Step ${_currentStep + 1} of ${_stepTitles.length}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Set Your Fitness Goals',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            const SizedBox(height: 16),
            Text(
              'Saving your profile...',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configuring your AI personal trainer',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      )
          : Form(
        key: _formKey,
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  _buildCurrentStep(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: AppTheme.primaryGreen),
                        ),
                        child: Text(
                          'Previous',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentStep < _stepTitles.length - 1) {
                          if (_formKey.currentState!.validate()) {
                            setState(() => _currentStep++);
                          }
                        } else {
                          _saveProfile();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentStep < _stepTitles.length - 1 ? 'Next' : 'Complete Profile',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    _workoutPreferenceController.dispose();
    _activityLevelController.dispose();
    _workoutFrequencyController.dispose();
    _workoutDurationController.dispose();
    _motivationLevelController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }
}