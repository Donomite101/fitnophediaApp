// features/onboarding/gym_onboarding_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../routes/app_routes.dart';
import '../../core/app_theme.dart';

class GymOnboardingScreen extends StatefulWidget {
  const GymOnboardingScreen({Key? key}) : super(key: key);
  @override
  State<GymOnboardingScreen> createState() => _GymOnboardingScreenState();
}

class _GymOnboardingScreenState extends State<GymOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  File? _gymLogo;
  final ImagePicker _picker = ImagePicker();

  // Focus nodes for auto navigation
  final List<FocusNode> _focusNodes = List.generate(25, (index) => FocusNode());

  /* ────────────────────── CONTROLLERS ────────────────────── */
  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _ownerEmailCtrl = TextEditingController();
  final _ownerPhoneCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _postalCodeCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _staffCountCtrl = TextEditingController();
  final _memberCountCtrl = TextEditingController();

  // Geofencing Controllers
  final _geofenceRadiusCtrl = TextEditingController(text: '100');
  ll.LatLng? _gymLocation;
  String _locationStatus = 'Not Set';
  bool _isGettingLocation = false;

  // FlutterMap controller + layers
  final MapController _mapController = MapController();
  List<CircleMarker> _geofenceCircles = [];
  List<Marker> _mapMarkers = [];

  // Opening hours controllers
  final Map<String, Map<String, TextEditingController>> _hoursCtrl = {
    'monday': {'open': TextEditingController(text: '06:00'), 'close': TextEditingController(text: '22:00')},
    'tuesday': {'open': TextEditingController(text: '06:00'), 'close': TextEditingController(text: '22:00')},
    'wednesday': {'open': TextEditingController(text: '06:00'), 'close': TextEditingController(text: '22:00')},
    'thursday': {'open': TextEditingController(text: '06:00'), 'close': TextEditingController(text: '22:00')},
    'friday': {'open': TextEditingController(text: '06:00'), 'close': TextEditingController(text: '22:00')},
    'saturday': {'open': TextEditingController(text: '08:00'), 'close': TextEditingController(text: '20:00')},
    'sunday': {'open': TextEditingController(text: '08:00'), 'close': TextEditingController(text: '18:00')},
  };

  // Second shift timing controllers
  final Map<String, Map<String, TextEditingController>> _secondShiftCtrl = {
    'monday': {'open': TextEditingController(text: ''), 'close': TextEditingController(text: '')},
    'tuesday': {'open': TextEditingController(text: ''), 'close': TextEditingController(text: '')},
    'wednesday': {'open': TextEditingController(text: ''), 'close': TextEditingController(text: '')},
    'thursday': {'open': TextEditingController(text: ''), 'close': TextEditingController(text: '')},
    'friday': {'open': TextEditingController(text: ''), 'close': TextEditingController(text: '')},
    'saturday': {'open': TextEditingController(text: ''), 'close': TextEditingController(text: '')},
    'sunday': {'open': TextEditingController(text: ''), 'close': TextEditingController(text: '')},
  };

  // Closed days and holidays
  final Map<String, bool> _closedDays = {
    'monday': false,
    'tuesday': false,
    'wednesday': false,
    'thursday': false,
    'friday': false,
    'saturday': false,
    'sunday': false,
  };

  // Second shift enabled for days
  final Map<String, bool> _secondShiftEnabled = {
    'monday': false,
    'tuesday': false,
    'wednesday': false,
    'thursday': false,
    'friday': false,
    'saturday': false,
    'sunday': false,
  };

  // Quick setup timing controllers
  final TextEditingController _quickOpenCtrl1 = TextEditingController(text: '06:00');
  final TextEditingController _quickCloseCtrl1 = TextEditingController(text: '22:00');
  final TextEditingController _quickOpenCtrl2 = TextEditingController(text: '14:00');
  final TextEditingController _quickCloseCtrl2 = TextEditingController(text: '18:00');

  // Quick setup second shift controllers
  final TextEditingController _quickSecondOpenCtrl = TextEditingController(text: '14:00');
  final TextEditingController _quickSecondCloseCtrl = TextEditingController(text: '18:00');

  // Services
  final List<String> _selectedServices = [];
  final TextEditingController _otherServicesCtrl = TextEditingController();

  // Pricing plans
  final List<Map<String, dynamic>> _pricingPlans = [];

  /* ────────────────────── DATA MAP ────────────────────── */
  late final Map<String, dynamic> _data = {
    'businessName': '',
    'businessType': '',
    'ownerName': '',
    'ownerEmail': '',
    'ownerPhone': '',
    'street': '',
    'city': '',
    'state': '',
    'postalCode': '',
    'country': '',
    'staffCount': 0,
    'memberCount': 0,
    'gymLogoUrl': '',
    'location': null, // Will store GeoPoint
    'geofenceRadius': 100.0, // meters
    'openingHours': {
      for (var d in ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'])
        d: {
          'open': _hoursCtrl[d]!['open']!.text,
          'close': _hoursCtrl[d]!['close']!.text,
          'closed': _closedDays[d]!,
          'secondShift': {
            'enabled': _secondShiftEnabled[d]!,
            'open': _secondShiftCtrl[d]!['open']!.text,
            'close': _secondShiftCtrl[d]!['close']!.text,
          }
        }
    },
    'services': <String>[],
    'otherServices': '',
    'pricingPlans': <Map<String, dynamic>>[],
  };

  /* ────────────────────── CONSTANTS ────────────────────── */
  final _businessTypes = ['Gym', 'Fitness Studio', 'CrossFit Box', 'Yoga Studio', 'Martial Arts Studio', 'Sports Club', 'Other'];
  final _serviceTypes = ['Gym Access', 'Personal Training', 'Group Classes', 'Yoga', 'Pilates', 'CrossFit', 'Swimming', 'Martial Arts', 'Other'];
  final _weekDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  final _dayNames = {
    'monday': 'Monday', 'tuesday': 'Tuesday', 'wednesday': 'Wednesday',
    'thursday': 'Thursday', 'friday': 'Friday', 'saturday': 'Saturday', 'sunday': 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _setupFocusNodes();
    _checkLocationPermissions();
  }

  void _setupFocusNodes() {
    for (int i = 0; i < _focusNodes.length - 1; i++) {
      _focusNodes[i].addListener(() {
        if (!_focusNodes[i].hasFocus) return;
      });
    }
  }

  void _loadUserEmail() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      _ownerEmailCtrl.text = user!.email!;
      _data['ownerEmail'] = user.email!;
    }
  }

  /* ────────────────────── LOCATION & GEOFENCING METHODS ────────────────────── */

  Future<bool> _checkLocationPermissions() async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        return true;
      } else if (status.isDenied) {
        _snack('Location permission is required to set gym location');
      } else if (status.isPermanentlyDenied) {
        _snack('Location permission permanently denied. Please enable it in app settings.');
        await openAppSettings();
      }
      return false;
    } catch (e) {
      debugPrint('Location permission error: $e');
      return false;
    }
  }

  Future<bool> _ensureLocationEnabledAndPermission() async {
    try {
      // 1. Check if location services (GPS) are ON
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Enable location'),
            content: const Text('Location services are disabled. Please enable GPS to set gym location.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open Settings')),
            ],
          ),
        );
        if (open == true) {
          await Geolocator.openLocationSettings();
        }
        return false;
      }

      // 2. Check current permission
      LocationPermission permission = await Geolocator.checkPermission();

      // If denied → request once
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _snack('Location permission is required to set gym location.');
          return false;
        }
      }

      // If permanently denied → direct to settings
      if (permission == LocationPermission.deniedForever) {
        _snack('Location permission permanently denied. Please enable it in app settings.');
        await openAppSettings();
        return false;
      }

      // Allowed
      return true;
    } catch (e) {
      debugPrint('Location permission error: $e');
      _snack('Failed to access location permission.');
      return false;
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!await _ensureLocationEnabledAndPermission()) return;

    setState(() {
      _isGettingLocation = true;
      _locationStatus = 'Getting your location...';
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      _gymLocation = ll.LatLng(position.latitude, position.longitude);

      // Update map immediately
      _updateGeofenceCircle();
      _updateMarker();
      _mapController.move(_gymLocation!, 15);

      setState(() {
        _locationStatus = 'Location captured! Getting address...';
      });

      // NOW do reverse geocoding
      await _getAddressFromLatLng(_gymLocation!);

      // Only when everything is done → allow continue
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
          _locationStatus = 'Location & address ready! Tap Continue';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGettingLocation = false;
        _locationStatus = 'Failed: $e';
      });
      _snack('Failed to get location: $e');
    }
  }

  Future<void> _getAddressFromLatLng(ll.LatLng latLng) async {
    try {
      final places = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
        localeIdentifier: "en", // Helps consistency
      );

      if (places.isEmpty) {
        _snack('No address found for this location');
        return;
      }

      final place = places.first;

      setState(() {
        _streetCtrl.text = [place.street, place.subThoroughfare]
            .where((e) => e != null && e.isNotEmpty)
            .join(', ')
            .trim();
        _cityCtrl.text = place.locality ?? place.subLocality ?? '';
        _stateCtrl.text = place.administrativeArea ?? '';
        _postalCodeCtrl.text = place.postalCode ?? '';
        _countryCtrl.text = place.country ?? 'India';
      });

      // Force validation to recheck
      if (mounted) {
        setState(() {}); // Trigger rebuild so validation sees updated fields
      }

      debugPrint("Reverse geocoding success: ${_cityCtrl.text}, ${_stateCtrl.text}");
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
      _snack('Could not get address. Please enter it manually.');
    }
  }

  Future<void> _getLocationFromAddress() async {
    if (_streetCtrl.text.isEmpty || _cityCtrl.text.isEmpty) {
      _snack('Please enter street address and city first');
      return;
    }

    try {
      final address = '${_streetCtrl.text}, ${_cityCtrl.text}, ${_stateCtrl.text}, ${_postalCodeCtrl.text}, ${_countryCtrl.text}';
      final locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        final location = locations.first;
        setState(() {
          _gymLocation = ll.LatLng(location.latitude, location.longitude);
          _locationStatus = 'Address found on map! ✅';
          _updateGeofenceCircle();
          _updateMarker();
          _isGettingLocation = false;
        });

        // Animate map to the location
        try {
          _mapController.move(_gymLocation!, 15);
        } catch (_) {}
      } else {
        setState(() {
          _locationStatus = 'Address not found on map';
          _isGettingLocation = false;
        });
        _snack('Could not find this address on map. Please check the address.');
      }
    } catch (e) {
      setState(() {
        _locationStatus = 'Geocoding failed: $e';
        _isGettingLocation = false;
      });
      _snack('Failed to find address on map: $e');
    }
  }

  void _updateGeofenceCircle() {
    if (_gymLocation == null) return;

    // parse and clamp radius
    final parsed = double.tryParse(_geofenceRadiusCtrl.text) ?? 100.0;
    final radius = parsed.clamp(50.0, 500.0);

    // keep controller normalized (integer meters)
    if (mounted) {
      _geofenceRadiusCtrl.text = radius.toInt().toString();
      setState(() {
        _geofenceCircles = [
          CircleMarker(
            point: _gymLocation!,
            radius: radius, // when useRadiusInMeter true below
            useRadiusInMeter: true,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
            borderStrokeWidth: 2,
            borderColor: Theme.of(context).colorScheme.primary,
          ),
        ];
      });
    }
  }

  void _updateMarker() {
    if (_gymLocation == null) return;
    setState(() {
      _mapMarkers = [
        Marker(
          point: _gymLocation!,
          width: 40,
          height: 40,
          child: Icon(
            Icons.location_pin,
            size: 40,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ];
    });
  }

  void _onGeofenceRadiusChanged(String value) {
    if (_gymLocation != null) {
      _updateGeofenceCircle();
    }
  }

  /* ────────────────────── IMAGE PICKER ────────────────────── */
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _gymLogo = File(image.path);
        });
      }
    } catch (e) {
      _snack('Failed to pick image: $e');
    }
  }

  /* ────────────────────── CLOUDINARY UPLOAD ────────────────────── */
  Future<String?> _uploadLogoToCloudinary(File imageFile) async {
    try {
      const cloudName = 'dntnzraxh';
      const uploadPreset = 'gym_uploads';

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      debugPrint('🚀 Uploading to Cloudinary: ${imageFile.path}');
      final response = await request.send().timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final resStr = await response.stream.bytesToString();
        final data = jsonDecode(resStr);
        final secureUrl = data['secure_url'];
        debugPrint('✅ Cloudinary upload success: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('❌ Cloudinary upload failed: ${response.statusCode}');
        _showError('Upload failed (HTTP ${response.statusCode})');
        return null;
      }
    } on TimeoutException {
      _showError('Upload timed out. Please try again.');
      return null;
    } catch (e) {
      debugPrint('💥 Upload error: $e');
      _showError('Failed to upload image.');
      return null;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  /* ────────────────────── VALIDATION ────────────────────── */
  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validateIndianPhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^(\+91[\-\s]?)?[0]?(91)?[6789]\d{9}$');
    if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
      return 'Enter a valid Indian phone number';
    }
    return null;
  }

  String? _validateTime(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName time is required';
    }
    final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
    if (!timeRegex.hasMatch(value)) {
      return 'Enter time in HH:MM format';
    }
    return null;
  }

  String? _validatePostalCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Pin code is required';
    }
    final postalRegex = RegExp(r'^[0-9]+$');
    if (!postalRegex.hasMatch(value)) {
      return 'Pin code should contain only numbers';
    }
    if (value.length != 6) {
      return 'Pin code should be 6 digits';
    }
    return null;
  }

  String? _validateNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final numberRegex = RegExp(r'^[0-9]+$');
    if (!numberRegex.hasMatch(value)) {
      return '$fieldName should contain only numbers';
    }
    if (int.tryParse(value) == null) {
      return 'Enter a valid number';
    }
    return null;
  }

  /* ────────────────────── NAVIGATION ────────────────────── */
  void _next() {
    if (!_validateCurrentPage()) return;
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);
  }

  void _back() => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.ease);

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0: // Business Info
        if (_businessNameCtrl.text.isEmpty) return _snackWithReturn('Please enter gym name');
        if (_data['businessType'].isEmpty) return _snackWithReturn('Please select gym type');
        if (_ownerNameCtrl.text.isEmpty) return _snackWithReturn('Please enter owner name');
        if (_ownerEmailCtrl.text.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_ownerEmailCtrl.text)) {
          return _snackWithReturn('Please enter valid email');
        }
        if (_ownerPhoneCtrl.text.isEmpty || !RegExp(r'^(\+91[\-\s]?)?[0]?(91)?[6789]\d{9}$').hasMatch(_ownerPhoneCtrl.text.replaceAll(' ', ''))) {
          return _snackWithReturn('Please enter valid Indian phone number');
        }
        return true;

      case 1: // Location & Geofencing - FIXED VALIDATION
        if (_gymLocation == null) {
          _snack('Please set gym location first');
          return false;
        }

        // Check if address fields are filled (allow manual entry if auto-fill failed)
        if (_streetCtrl.text.isEmpty) {
          _snack('Please enter street address');
          return false;
        }
        if (_cityCtrl.text.isEmpty) {
          _snack('Please enter city');
          return false;
        }
        if (_stateCtrl.text.isEmpty) {
          _snack('Please enter state');
          return false;
        }
        if (_countryCtrl.text.isEmpty) {
          _snack('Please enter country');
          return false;
        }

        // Postal code validation - only if filled
        if (_postalCodeCtrl.text.isNotEmpty) {
          if (_postalCodeCtrl.text.length != 6 || !RegExp(r'^\d{6}$').hasMatch(_postalCodeCtrl.text)) {
            _snack('Please enter a valid 6-digit pin code');
            return false;
          }
        } else {
          // If postal code is empty, ask user to fill it
          _snack('Please enter your 6-digit Pin Code');
          return false;
        }

        // Geofence radius validation
        final radius = double.tryParse(_geofenceRadiusCtrl.text);
        if (radius == null || radius < 50 || radius > 500) {
          _snack('Geofence radius must be 50–500 meters');
          return false;
        }

        return true;

      case 2: // Opening Hours
        bool hasOpenDay = false;
        for (var day in _weekDays) {
          if (!_closedDays[day]!) {
            hasOpenDay = true;
            break;
          }
        }
        if (!hasOpenDay) return _snackWithReturn('Please set timings for at least one day');
        return true;

      case 3: // Services
        if (_selectedServices.isEmpty) return _snackWithReturn('Please select at least one service');
        if (_selectedServices.contains('Other') && _otherServicesCtrl.text.isEmpty) {
          return _snackWithReturn('Please specify other services');
        }
        return true;

      case 4: // Staff & Members
        if (_staffCountCtrl.text.isEmpty) return _snackWithReturn('Please enter staff count');
        if (_memberCountCtrl.text.isEmpty) return _snackWithReturn('Please enter member count');
        if (!RegExp(r'^[0-9]+$').hasMatch(_staffCountCtrl.text)) return _snackWithReturn('Staff count should be a number');
        if (!RegExp(r'^[0-9]+$').hasMatch(_memberCountCtrl.text)) return _snackWithReturn('Member count should be a number');
        return true;

      case 5: // Pricing
        if (_pricingPlans.isEmpty) return _snackWithReturn('Please add at least one pricing plan');
        return true;

      default:
        return true;
    }
  }

  bool _snackWithReturn(String msg) {
    _snack(msg);
    return false;
  }

  /* ────────────────────── TIME PICKER ────────────────────── */
  Future<void> _pickTime(TextEditingController controller) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked != null) {
      final txt = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        controller.text = txt;
      });
    }
  }

  Future<void> _pickTimeForDay(String day, String type, bool isSecondShift) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked != null) {
      final txt = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isSecondShift) {
          _secondShiftCtrl[day]![type]!.text = txt;
        } else {
          _hoursCtrl[day]![type]!.text = txt;
        }
      });
    }
  }

  /* ────────────────────── FORM SYNC ────────────────────── */
  void _syncData() {
    _data.update('businessName', (_) => _businessNameCtrl.text);
    _data.update('ownerName', (_) => _ownerNameCtrl.text);
    _data.update('ownerEmail', (_) => _ownerEmailCtrl.text);
    _data.update('ownerPhone', (_) => _ownerPhoneCtrl.text);
    _data.update('street', (_) => _streetCtrl.text);
    _data.update('city', (_) => _cityCtrl.text);
    _data.update('state', (_) => _stateCtrl.text);
    _data.update('postalCode', (_) => _postalCodeCtrl.text);
    _data.update('country', (_) => _countryCtrl.text);
    _data.update('staffCount', (_) => int.tryParse(_staffCountCtrl.text) ?? 0);
    _data.update('memberCount', (_) => int.tryParse(_memberCountCtrl.text) ?? 0);

    // Store location data
    if (_gymLocation != null) {
      _data['location'] = GeoPoint(_gymLocation!.latitude, _gymLocation!.longitude);
      _data['geofenceRadius'] = double.tryParse(_geofenceRadiusCtrl.text) ?? 100.0;
    }

    for (var d in _weekDays) {
      _data['openingHours'][d] = {
        'open': _hoursCtrl[d]!['open']!.text,
        'close': _hoursCtrl[d]!['close']!.text,
        'closed': _closedDays[d]!,
        'secondShift': {
          'enabled': _secondShiftEnabled[d]!,
          'open': _secondShiftCtrl[d]!['open']!.text,
          'close': _secondShiftCtrl[d]!['close']!.text,
        }
      };
    }

    // Services
    _data['services'] = _selectedServices;
    _data['otherServices'] = _otherServicesCtrl.text;

    // Pricing plans
    _data['pricingPlans'] = _pricingPlans;
  }

  /* ────────────────────── SUBMIT ────────────────────── */
  Future<void> _submit() async {
    if (!_validateCurrentPage()) return;
    _syncData();

    setState(() => _isLoading = true);
    try {
      // Upload image if selected
      String? logoUrl;
      if (_gymLogo != null) {
        logoUrl = await _uploadLogoToCloudinary(_gymLogo!);
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'onboardingCompleted': true,
        'onboardingData': _data,
        'onboardingSubmittedAt': FieldValue.serverTimestamp(),
      });

      // Create gym document with geofencing data
      final gymsRef = FirebaseFirestore.instance.collection('gyms');
      final counterRef = FirebaseFirestore.instance.collection('counters').doc('gyms');

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final counterSnap = await tx.get(counterRef);
        int nextNum;
        if (counterSnap.exists && counterSnap.data() != null && counterSnap.data()!.containsKey('next')) {
          final dynamic val = counterSnap.data()!['next'];
          if (val is int) {
            nextNum = val + 1;
          } else if (val is String) {
            nextNum = int.tryParse(val) != null ? int.parse(val) + 1 : 1;
          } else {
            nextNum = 1;
          }
        } else {
          nextNum = 1;
        }

        final docId = 'gym-${nextNum.toString().padLeft(3, '0')}';
        final gymDocRef = gymsRef.doc(docId);

        // Write gym document with location data
        tx.set(gymDocRef, {
          'ownerId': uid,
          'businessName': _data['businessName'],
          'businessType': _data['businessType'],
          'gymLogoUrl': logoUrl ?? '',
          'staffCount': _data['staffCount'],
          'memberCount': _data['memberCount'],
          'contact': {
            'ownerName': _data['ownerName'],
            'email': _data['ownerEmail'],
            'phone': _data['ownerPhone'],
          },
          'address': {
            'street': _data['street'],
            'city': _data['city'],
            'state': _data['state'],
            'postalCode': _data['postalCode'],
            'country': _data['country'],
          },
          'location': _data['location'], // GeoPoint
          'geofenceRadius': _data['geofenceRadius'], // meters
          'openingHours': _data['openingHours'],
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'services': _data['services'],
          'otherServices': _data['otherServices'],
          'pricingPlans': _data['pricingPlans'],
        });

        tx.set(counterRef, {'next': nextNum});
      });

      Navigator.pushReplacementNamed(context, AppRoutes.approvalWaiting);
    } catch (e) {
      _snack('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ),
  );

  /* ────────────────────── UI HELPERS ────────────────────── */
  Widget _field(TextEditingController c, String label, IconData icon, int focusIndex,
      {TextInputType? kb, String? Function(String?)? validator, int? maxLines, bool isLastInSection = false}) {
    return TextFormField(
      controller: c,
      focusNode: _focusNodes[focusIndex],
      keyboardType: kb,
      maxLines: maxLines,
      textInputAction: isLastInSection ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: (value) {
        if (!isLastInSection && focusIndex < _focusNodes.length - 1) {
          FocusScope.of(context).requestFocus(_focusNodes[focusIndex + 1]);
        }
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        hintText: 'Enter $label',
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        isDense: true,
        contentPadding: const EdgeInsets.all(16),
      ),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
      validator: validator,
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required String label,
    required List<T> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
    int focusIndex = 0,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      focusNode: _focusNodes[focusIndex],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        hintText: 'Select $label',
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
        prefixIcon: Icon(Icons.category, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        isDense: true,
        contentPadding: const EdgeInsets.all(16),
      ),
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
      items: items.map((e) => DropdownMenuItem(
        value: e,
        child: Text(e.toString(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      )).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _section({required String title, required String subtitle, required List<Widget> children}) {
    return Container(
      color: Theme.of(context).colorScheme.background,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _timeFieldQuickSetup(TextEditingController controller, String label, int focusIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickTime(controller),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  controller.text.isEmpty ? 'HH:MM' : controller.text,
                  style: TextStyle(
                    fontSize: 16,
                    color: controller.text.isEmpty ?
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.5) :
                    Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(Icons.access_time, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _applyToAllOpenDays() {
    setState(() {
      for (var day in _weekDays) {
        if (!_closedDays[day]!) {
          _hoursCtrl[day]!['open']!.text = _quickOpenCtrl1.text;
          _hoursCtrl[day]!['close']!.text = _quickCloseCtrl1.text;

          // Apply second shift if enabled
          if (_quickSecondOpenCtrl.text.isNotEmpty && _quickSecondCloseCtrl.text.isNotEmpty) {
            _secondShiftEnabled[day] = true;
            _secondShiftCtrl[day]!['open']!.text = _quickSecondOpenCtrl.text;
            _secondShiftCtrl[day]!['close']!.text = _quickSecondCloseCtrl.text;
          } else {
            _secondShiftEnabled[day] = false;
            _secondShiftCtrl[day]!['open']!.text = '';
            _secondShiftCtrl[day]!['close']!.text = '';
          }
        }
      }
    });

    int openDaysCount = _closedDays.values.where((v) => !v).length;
    String shiftInfo = _quickSecondOpenCtrl.text.isNotEmpty ? ' with dual shifts' : '';
    _snack('Timings applied to $openDaysCount open days$shiftInfo');
  }

  Widget _holidaySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select days when your gym is regularly closed:',
          style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _weekDays.map((day) {
            return FilterChip(
              label: Text(
                _dayNames[day]!,
                style: TextStyle(
                  color: _closedDays[day]! ? Colors.white : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              selected: _closedDays[day]!,
              onSelected: (selected) => setState(() => _closedDays[day] = selected),
              selectedColor: Theme.of(context).colorScheme.error,
              checkmarkColor: Colors.white,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showPlanDialog() {
    String name = '', price = '', features = '';
    String type = 'month';
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Pricing Plan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                decoration: InputDecoration(
                  labelText: 'Plan Name*',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  hintText: 'e.g., Basic Monthly, Premium Yearly',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 16),
              TextField(
                style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                decoration: InputDecoration(
                  labelText: 'Price (₹)*',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  hintText: 'e.g., 1999',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => price = v,
              ),
              const SizedBox(height: 16),
              TextField(
                style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                decoration: InputDecoration(
                  labelText: 'Features (comma separated)',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  hintText: 'e.g., Gym Access, Group Classes, Locker',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                onChanged: (v) => features = v,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: type,
                items: [
                  DropdownMenuItem(value: 'month', child: Text('Monthly', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                  DropdownMenuItem(value: '3 months', child: Text('Quarterly (3 Months)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                  DropdownMenuItem(value: '6 months', child: Text('Half Yearly (6 Months)', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                  DropdownMenuItem(value: 'year', child: Text('Yearly', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                  DropdownMenuItem(value: 'session', child: Text('Per Session', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                ],
                onChanged: (v) => type = v!,
                decoration: InputDecoration(
                  labelText: 'Billing Type*',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                dropdownColor: Theme.of(context).colorScheme.surface,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (name.isNotEmpty && price.isNotEmpty) {
                          setState(() => _pricingPlans.add({
                            'name': name,
                            'price': double.tryParse(price) ?? 0,
                            'type': type,
                            'features': features
                          }));
                          Navigator.pop(context);
                        } else {
                          _snack('Please fill required fields');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Add Plan',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPlanColor(int index) {
    final colors = [
      Theme.of(context).colorScheme.primary,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];
    return colors[index % colors.length];
  }

  /* ────────────────────── PAGE BUILDERS ────────────────────── */
  Widget _pageBusiness() => _section(
    title: 'Business Information',
    subtitle: 'Tell us about your gym business',
    children: [
      // Gym Logo Upload
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          children: [
            Text(
              'Gym Logo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                  image: _gymLogo != null
                      ? DecorationImage(
                    image: FileImage(_gymLogo!),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: _gymLogo == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, size: 32, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text(
                      'Add Logo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to upload gym logo',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      _field(_businessNameCtrl, 'Gym Name', Icons.business, 0,
          validator: (v) => _validateRequired(v, 'Gym name')),
      const SizedBox(height: 20),
      _dropdown<String>(
        value: _data['businessType'].isEmpty ? null : _data['businessType'],
        label: 'Business Type',
        items: _businessTypes,
        focusIndex: 1,
        onChanged: (v) => setState(() => _data['businessType'] = v ?? ''),
        validator: (v) => v == null ? 'Business type is required' : null,
      ),
      const SizedBox(height: 20),
      _field(_ownerNameCtrl, 'Owner Full Name', Icons.person, 2,
          validator: (v) => _validateRequired(v, 'Owner name')),
      const SizedBox(height: 20),
      _field(_ownerEmailCtrl, 'Contact Email', Icons.email, 3,
          kb: TextInputType.emailAddress,
          validator: _validateEmail),
      const SizedBox(height: 20),
      _field(_ownerPhoneCtrl, 'Contact Phone', Icons.phone, 4,
          kb: TextInputType.phone,
          isLastInSection: true,
          validator: (v) => _validateIndianPhone(v)),
    ],
  );

  Widget _pageLocation() => _section(
    title: 'Gym Location & Geofencing',
    subtitle: 'Set your gym location and check-in boundary for members',
    children: [
      // Location Setup Section
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.primary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_pin, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '📍 Gym Location Setup',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Set your gym location to enable check-ins. Members must be within the geofence to log workouts.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Location Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _gymLocation != null ?
                Theme.of(context).colorScheme.tertiaryContainer :
                Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _gymLocation != null ?
                  Theme.of(context).colorScheme.tertiary :
                  Theme.of(context).colorScheme.error,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _gymLocation != null ? Icons.check_circle : Icons.info,
                    color: _gymLocation != null ?
                    Theme.of(context).colorScheme.tertiary :
                    Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationStatus,
                      style: TextStyle(
                        color: _gymLocation != null ?
                        Theme.of(context).colorScheme.onTertiaryContainer :
                        Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Location Buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: '📱 Use Current Location',
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    textColor: Theme.of(context).colorScheme.onPrimary,
                    isLoading: _isGettingLocation,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: '🏢 Use Address',
                    onPressed: _isGettingLocation ? null : _getLocationFromAddress,
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    textColor: Theme.of(context).colorScheme.onSecondary,
                    isLoading: _isGettingLocation,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Address Fields
      Text(
        'Business Address',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onBackground,
        ),
      ),
      const SizedBox(height: 12),
      _field(_streetCtrl, 'Street Address', Icons.location_on, 5,
          validator: (v) => _validateRequired(v, 'Street address')),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _field(_cityCtrl, 'City', Icons.location_city, 6,
            validator: (v) => _validateRequired(v, 'City'))),
        const SizedBox(width: 16),
        Expanded(child: _field(_stateCtrl, 'State', Icons.map, 7,
            validator: (v) => _validateRequired(v, 'State'))),
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: _field(_postalCodeCtrl, 'Pin Code', Icons.markunread_mailbox, 8,
            kb: TextInputType.number,
            validator: _validatePostalCode)),
        const SizedBox(width: 16),
        Expanded(child: _field(_countryCtrl, 'Country', Icons.public, 9,
            validator: (v) => _validateRequired(v, 'Country'))),
      ]),
      const SizedBox(height: 20),

      // Geofence Settings
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fence, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Geofence Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Set the check-in boundary radius around your gym. Members must be within this area to log workouts.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _geofenceRadiusCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: _onGeofenceRadiusChanged,
                    decoration: InputDecoration(
                      labelText: 'Geofence Radius (meters)',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      hintText: 'e.g., 100',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.radio, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'meters',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Recommended: 50-200 meters. Members will see this radius on their map.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Map Preview (OpenStreetMap via flutter_map)
      if (_gymLocation != null) ...[
        Text(
          'Location Preview',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _gymLocation!,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.fitnopedia',
                ),
                RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution(
                      '© OpenStreetMap contributors',
                      textStyle: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ],
                ),
                if (_geofenceCircles.isNotEmpty)
                  CircleLayer(circles: _geofenceCircles),
                if (_mapMarkers.isNotEmpty)
                  MarkerLayer(markers: _mapMarkers),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '📍 Blue circle shows the check-in boundary for members',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ] else ...[
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                'Map will appear here',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
              Text(
                'Set your gym location to see the map preview',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _pageHours() => _section(
    title: 'Opening Hours',
    subtitle: 'Set your business operating hours',
    children: [
      // Quick Setup for All Days
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Quick Setup for All Days', style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                )),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Set the same timing for all open days:',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),

            // First Shift
            Text(
              'First Shift (Morning/Afternoon):',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _timeFieldQuickSetup(_quickOpenCtrl1, 'Open Time', 10),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _timeFieldQuickSetup(_quickCloseCtrl1, 'Close Time', 11),
                ),
              ],
            ),

            // Second Shift Toggle
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.switch_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                const SizedBox(width: 8),
                Text('Add Second Shift', style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                )),
                const Spacer(),
                Switch(
                  value: _quickSecondOpenCtrl.text.isNotEmpty && _quickSecondCloseCtrl.text.isNotEmpty,
                  onChanged: (value) {
                    setState(() {
                      if (value) {
                        _quickSecondOpenCtrl.text = '14:00';
                        _quickSecondCloseCtrl.text = '18:00';
                      } else {
                        _quickSecondOpenCtrl.text = '';
                        _quickSecondCloseCtrl.text = '';
                      }
                    });
                  },
                ),
              ],
            ),

            // Second Shift
            if (_quickSecondOpenCtrl.text.isNotEmpty && _quickSecondCloseCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Second Shift (Evening):',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _timeFieldQuickSetup(_quickSecondOpenCtrl, 'Open Time', 12),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _timeFieldQuickSetup(_quickSecondCloseCtrl, 'Close Time', 13),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Apply to All Open Days',
                onPressed: _applyToAllOpenDays,
                backgroundColor: Theme.of(context).colorScheme.primary,
                textColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),

      // Holidays section
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.event_busy, color: Theme.of(context).colorScheme.onSurface),
                const SizedBox(width: 8),
                Text('Regular Holidays', style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                )),
              ],
            ),
            const SizedBox(height: 16),
            _holidaySelection(),
          ],
        ),
      ),
    ],
  );

  Widget _pageServices() => _section(
    title: 'Services Offered',
    subtitle: 'What services do you provide at your gym?',
    children: [
      Text(
        'Select all that apply:',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onBackground,
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _serviceTypes.map((s) {
          final sel = _selectedServices.contains(s);
          return ChoiceChip(
            label: Text(s),
            selected: sel,
            onSelected: (b) => setState(() => b ? _selectedServices.add(s) : _selectedServices.remove(s)),
            selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            labelStyle: TextStyle(
              color: sel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: sel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),

      if (_selectedServices.contains('Other')) ...[
        _field(
          _otherServicesCtrl,
          'Specify Other Services',
          Icons.list,
          14,
          maxLines: 3,
          isLastInSection: true,
          validator: (v) => _validateRequired(v, 'Other services'),
        ),
        const SizedBox(height: 16),
      ],
    ],
  );

  Widget _pageStaffMembers() => _section(
    title: 'Staff & Members',
    subtitle: 'Tell us about your current team and members',
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '👥 Team Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This helps us understand the scale of your operations and provide better support.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      _field(_staffCountCtrl, 'Number of Staff Members', Icons.people, 15,
          kb: TextInputType.number,
          validator: (v) => _validateNumber(v, 'Staff count')),
      const SizedBox(height: 20),
      _field(_memberCountCtrl, 'Current Number of Members', Icons.group, 16,
          kb: TextInputType.number,
          isLastInSection: true,
          validator: (v) => _validateNumber(v, 'Member count')),
      const SizedBox(height: 16),

      // Info cards
      Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary),
              ),
              child: Column(
                children: [
                  Icon(Icons.people, color: Theme.of(context).colorScheme.primary, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Staff',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Trainers, front desk, managers',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.secondary),
              ),
              child: Column(
                children: [
                  Icon(Icons.group, color: Theme.of(context).colorScheme.secondary, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Members',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Current active members',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _pagePricing() => _section(
    title: 'Pricing Plans',
    subtitle: 'Add your membership and pricing plans',
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💡 Pricing Tips',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• Add different plans for monthly, quarterly, and yearly memberships\n• Include features like gym access, classes, personal training\n• Consider offering discounts for longer commitments',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      SizedBox(
        width: double.infinity,
        child: CustomButton(
          text: '➕ Add Pricing Plan',
          onPressed: _showPlanDialog,
          backgroundColor: Theme.of(context).colorScheme.primary,
          textColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      const SizedBox(height: 20),

      if (_pricingPlans.isEmpty)
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Column(
            children: [
              Icon(Icons.attach_money, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'No pricing plans added yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Click the button above to add your first plan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ),
        )
      else
        Column(
          children: _pricingPlans.asMap().entries.map<Widget>((entry) {
            final index = entry.key;
            final p = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getPlanColor(index),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.attach_money, color: Colors.white),
                ),
                title: Text(
                  p['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${p['price']}/${p['type']}',
                      style: TextStyle(
                        color: _getPlanColor(index),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (p['features'] != null && p['features'].isNotEmpty)
                      Text(
                        'Features: ${p['features']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                  onPressed: () => setState(() => _pricingPlans.removeAt(index)),
                ),
              ),
            );
          }).toList(),
        ),
    ],
  );

  List<Widget> _dots() => List.generate(
    6,
        (i) => AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _currentPage == i ? 24 : 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: _currentPage == i ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Gym Onboarding',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.background,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onBackground),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          },
        ),
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : Form(
        key: _formKey,
        child: Column(
          children: [
            // progress dots
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: Theme.of(context).colorScheme.background,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _dots(),
              ),
            ),
            // pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  SingleChildScrollView(child: _pageBusiness()),
                  SingleChildScrollView(child: _pageLocation()),
                  SingleChildScrollView(child: _pageHours()),
                  SingleChildScrollView(child: _pageServices()),
                  SingleChildScrollView(child: _pageStaffMembers()),
                  SingleChildScrollView(child: _pagePricing()),
                ],
              ),
            ),
            // bottom buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.background,
                border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline)),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: CustomButton(
                        text: 'Back',
                        onPressed: _back,
                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                        textColor: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: _currentPage == 5 ? 'Submit Application' : 'Continue',
                      onPressed: _currentPage == 5 ? _submit : _next,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      textColor: Theme.of(context).colorScheme.onPrimary,
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
    // Dispose all controllers
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerEmailCtrl.dispose();
    _ownerPhoneCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _postalCodeCtrl.dispose();
    _countryCtrl.dispose();
    _staffCountCtrl.dispose();
    _memberCountCtrl.dispose();
    _geofenceRadiusCtrl.dispose();
    _quickOpenCtrl1.dispose();
    _quickCloseCtrl1.dispose();
    _quickOpenCtrl2.dispose();
    _quickCloseCtrl2.dispose();
    _quickSecondOpenCtrl.dispose();
    _quickSecondCloseCtrl.dispose();
    _otherServicesCtrl.dispose();

    for (var d in _weekDays) {
      _hoursCtrl[d]!['open']!.dispose();
      _hoursCtrl[d]!['close']!.dispose();
      _secondShiftCtrl[d]!['open']!.dispose();
      _secondShiftCtrl[d]!['close']!.dispose();
    }

    for (var node in _focusNodes) {
      node.dispose();
    }

    _pageController.dispose();
    super.dispose();
  }
}