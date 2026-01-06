// Put this file at lib/profile_settings_screen.dart (or adjust import)
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../core/app_theme.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? _gymId;
  String? _gymName;
  String? _contactNumber;
  String? _address;
  String? _description;
  String? _logoUrl;
  bool _loading = true;
  bool _saving = false;
  File? _imageFile;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadGymData();
  }

  Future<void> _loadGymData() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final gyms = await _firestore.collection('gyms').where('ownerId', isEqualTo: user.uid).limit(1).get();
      if (gyms.docs.isNotEmpty) {
        final gymDoc = gyms.docs.first;
        final data = gymDoc.data();

        String safeString(dynamic value) {
          if (value == null) return '';
          if (value is Map) return value.values.join(', ');
          return value.toString();
        }

        setState(() {
          _gymId = gymDoc.id;
          _gymName = safeString(data['businessName']);
          _contactNumber = safeString(data['contactNumber']);
          _address = safeString(data['address']);
          _description = safeString(data['description']);
          _logoUrl = safeString(data['logoUrl']);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error loading gym data: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200, maxHeight: 1200);
      if (picked != null) {
        final file = File(picked.path);
        if (!await file.exists()) {
          _showError('Selected image file not found');
          return;
        }
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          _showError('Image too large. Please select under 5MB.');
          return;
        }
        setState(() => _imageFile = file);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showError('Failed to pick image.');
    }
  }

  Future<String?> _uploadLogoToCloudinary(File imageFile) async {
    try {
      const cloudName = 'dntnzraxh'; // replace with yours
      const uploadPreset = 'gym_uploads'; // replace with your unsigned preset
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      debugPrint('Uploading to Cloudinary: ${imageFile.path}');
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _saving = true);

    // show modal progress using rootNavigator so we can safely pop it later
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen)),
                  SizedBox(height: 12),
                  Text('Saving profile...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      String? finalLogoUrl = _logoUrl;

      if (_imageFile != null) {
        final uploaded = await _uploadLogoToCloudinary(_imageFile!);
        if (uploaded != null) finalLogoUrl = uploaded;
      }

      if (_gymId == null) throw Exception('Gym ID not found');

      final updateData = {
        'businessName': _gymName?.trim(),
        'contactNumber': _contactNumber?.trim(),
        'address': _address?.trim(),
        'description': _description?.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (finalLogoUrl != null && finalLogoUrl.isNotEmpty) updateData['logoUrl'] = finalLogoUrl;

      await _firestore.collection('gyms').doc(_gymId!).update(updateData);
      debugPrint('Firestore updated');

      // close the progress dialog (rootNavigator)
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // safe navigation: go back if possible; otherwise replace with dashboard
      final nav = Navigator.of(context);
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      if (nav.canPop()) {
        nav.pop();
      } else {
        nav.pushReplacementNamed('/dashboard');
      }
    } catch (e, st) {
      debugPrint('Save error: $e\n$st');
      // ensure dialog closed
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showError('Failed to save changes. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF3D00),
      ),
    );
  }

  ImageProvider? _buildLogoImage() {
    if (_imageFile != null) return FileImage(_imageFile!);
    if (_logoUrl != null && _logoUrl!.isNotEmpty) return NetworkImage(_logoUrl!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile Settings'),
        elevation: 1,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickLogo,
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: _buildLogoImage(),
                        child: _buildLogoImage() == null
                            ? Icon(Icons.fitness_center, size: 38, color: Colors.grey.shade700)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_gymName ?? 'Your Gym', style: s.titleLarge),
                          const SizedBox(height: 4),
                          Text(_contactNumber ?? '', style: s.bodyMedium),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _pickLogo,
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Change Logo'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: _gymName,
                        decoration: const InputDecoration(labelText: 'Gym Name *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        onSaved: (v) => _gymName = v?.trim(),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _contactNumber,
                        decoration: const InputDecoration(labelText: 'Contact Number *'),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        onSaved: (v) => _contactNumber = v?.trim(),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _address,
                        decoration: const InputDecoration(labelText: 'Address *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        onSaved: (v) => _address = v?.trim(),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _description,
                        decoration: const InputDecoration(labelText: 'Description'),
                        minLines: 2,
                        maxLines: 4,
                        onSaved: (v) => _description = v?.trim(),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save),
                          label: Text(_saving ? 'SAVING...' : 'SAVE CHANGES'),
                          onPressed: _saving ? null : _saveChanges,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
