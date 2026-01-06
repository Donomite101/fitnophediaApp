import 'dart:async';
import 'dart:convert';
import 'package:fitnophedia/features/member/streak/streak_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../../core/services/cloudinary_config.dart';
import '../../../routes/app_routes.dart';
import '../../workout/data/models/exercise_model.dart';
import '../../workout/presentation/screens/workout_detail_screen.dart';
import '../../workout/presentation/screens/workout_home_screen.dart';
import '../banner/BannerCarousel.dart';
import '../challenges/member_challenges_screen.dart';
import '../chat/ChatScreen.dart';
import '../diet/screens/daily_diet_plan_screen.dart';
import 'workout_section_card.dart';
import 'diet_plans_card.dart';
import 'notices_updates_card.dart';
import 'challenge_card.dart';

class MemberDashboardScreen extends StatefulWidget {
  const MemberDashboardScreen({Key? key}) : super(key: key);

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen>
    with SingleTickerProviderStateMixin {
  // ========== STATE VARIABLES ==========
  bool _isLoading = true;
  bool _hasActiveSubscription = false;
  bool _subscriptionCheckComplete = false;

  // User Profile
  String _userName = 'Member';
  String _userEmail = '';
  String _profileImageUrl = '';
  String _gymName = 'My Gym';

  // Identifiers
  String _memberId = '';
  String _gymId = '';

  // Stats
  int _currentStreak = 0;
  int _steps = 0;
  int _goal = 10000;
  List<bool> _activeDays = List.filled(7, false);

  // Notifications & Data
  int _notificationCount = 0;
  List<Map<String, dynamic>> _notices = [];
  List<Map<String, dynamic>> _challenges = [];

  // Controllers
  late SharedPreferences _prefs;
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  late AnimationController _lottiePulseController;
  StreamSubscription? _notificationSubscription;

  // Cache
  static const String _cacheKeyUserData = 'dashboard_user_data_v7';
  static const String _cacheKeyStats = 'dashboard_stats_v7';

  // Navigation throttling
  DateTime? _lastNavigationTime;

  // ========== UI Colors using Theme ==========
  Color _backgroundColor(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;
  Color _textPrimary(BuildContext context) => Theme.of(context).textTheme.bodyLarge!.color!;
  Color _greyText(BuildContext context) => Theme.of(context).textTheme.bodyMedium!.color!;
  Color _cardBackground(BuildContext context) => Theme.of(context).cardColor;

  bool _isDarkMode(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  // ========== LIFECYCLE METHODS ==========
  @override
  void initState() {
    super.initState();
    _initializeAnimationController();
    _initializeApp();
  }

  void _initializeAnimationController() {
    _lottiePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
      lowerBound: 0.95,
      upperBound: 1.05,
    )..repeat(reverse: true);
  }

  Future<void> _initializeApp() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _checkFlow();
    } catch (e) {
      _handleInitializationError(e);
    }
  }

  void _handleInitializationError(dynamic error) {
    debugPrint('App initialization error: $error');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _subscriptionCheckComplete = true;
      });
    }
  }

  @override
  void dispose() {
    _lottiePulseController.dispose();
    _notificationSubscription?.cancel();
    _refreshController.dispose();
    super.dispose();
  }

  // ========== CACHE MANAGEMENT ==========
  Future<void> _saveCacheData() async {
    try {
      final userData = {
        'userName': _userName,
        'userEmail': _userEmail,
        'profileImageUrl': _profileImageUrl,
        'gymId': _gymId,
        'memberId': _memberId,
        'gymName': _gymName,
        'hasActiveSubscription': _hasActiveSubscription,
      };

      final statsData = {
        'currentStreak': _currentStreak,
        'steps': _steps,
        'goal': _goal,
        'activeDays': _activeDays.map((d) => d ? 1 : 0).toList(),
      };

      await _prefs.setString(_cacheKeyUserData, json.encode(userData));
      await _prefs.setString(_cacheKeyStats, json.encode(statsData));
    } catch (e) {
      debugPrint('Cache save error: $e');
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final userJson = _prefs.getString(_cacheKeyUserData);
      final statsJson = _prefs.getString(_cacheKeyStats);

      if (userJson != null) {
        final userData = json.decode(userJson) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _userName = userData['userName']?.toString() ?? 'Member';
            _userEmail = userData['userEmail']?.toString() ?? '';
            _profileImageUrl = userData['profileImageUrl']?.toString() ?? '';
            _gymId = userData['gymId']?.toString() ?? '';
            _memberId = userData['memberId']?.toString() ?? '';
            _gymName = userData['gymName']?.toString() ?? 'My Gym';
            _hasActiveSubscription = userData['hasActiveSubscription'] == true;
          });
        }
      }

      if (statsJson != null) {
        final statsData = json.decode(statsJson) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentStreak = (statsData['currentStreak'] as num?)?.toInt() ?? 0;
            _steps = (statsData['steps'] as num?)?.toInt() ?? 0;
            _goal = (statsData['goal'] as num?)?.toInt() ?? 10000;

            final activeDaysList = statsData['activeDays'] as List<dynamic>?;
            if (activeDaysList != null && activeDaysList.length == 7) {
              _activeDays = activeDaysList.map((d) => d == 1).toList();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Cache load error: $e');
      await _clearCorruptedCache();
    }
  }

  Future<void> _clearCorruptedCache() async {
    try {
      await _prefs.remove(_cacheKeyUserData);
      await _prefs.remove(_cacheKeyStats);
    } catch (_) {
      // Non-critical failure
    }
  }

  // ========== MAIN FLOW ==========
  Future<void> _checkFlow() async {
    if (!mounted) return;

    // Load from cache for instant UI
    await _loadFromCache();

    if (mounted) {
      setState(() => _isLoading = false);
    }

    // Start background initialization
    unawaited(_backgroundInitialize());
  }

  Future<void> _backgroundInitialize() async {
    try {
      // Verify user authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _redirectToLogin();
        });
        return;
      }

      _userEmail = user.email ?? _userEmail;

      // Resolve gym and member
      final ids = await _resolveGymAndMember(user.uid);
      if (ids == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _redirectToSubscription();
        });
        return;
      }

      final gymId = ids['gymId']!;
      final memberId = ids['memberId']!;

      // Update state with resolved IDs
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _gymId = gymId;
            _memberId = memberId;
          });
        }
      });

      // Validate subscription
      final subscriptionValid = await _validateSubscription(gymId, memberId);

      if (!subscriptionValid) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _redirectToSubscription();
        });
        return;
      }

      // Mark subscription as valid
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasActiveSubscription = true;
            _subscriptionCheckComplete = true;
          });
        }
      });

      // Load all data
      await _loadAllData(gymId, memberId);

      // Setup listener
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setupNotificationListener(gymId, memberId);
        }
      });

      // Save to cache
      await _saveCacheData();

    } catch (e, st) {
      debugPrint('Background initialization error: $e\n$st');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _subscriptionCheckComplete = true);
        }
      });
    }
  }

  // ========== SUBSCRIPTION VALIDATION ==========
  Future<bool> _validateSubscription(String gymId, String memberId) async {
    try {
      if (gymId.isEmpty || memberId.isEmpty) return false;

      final memberDoc = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .get();

      if (!memberDoc.exists) return false;

      final data = memberDoc.data() as Map<String, dynamic>;

      // Check subscription indicators
      final subscriptionStatus = (data['subscriptionStatus'] as String?)?.toLowerCase();
      final status = (data['status'] as String?)?.toLowerCase();
      final hasOngoing = data['hasOngoingSubscription'] == true;
      final isActive = data['isActive'] == true;
      final isSubscribed = data['isSubscribed'] == true;

      // Primary check
      bool isPaid = subscriptionStatus == 'active' || status == 'active';

      // Secondary check
      if (!isPaid) {
        isPaid = hasOngoing || isActive || isSubscribed;
      }

      // Check expiry date
      if (isPaid) {
        final expiryDate = _parseExpiryDate(data['expiryDate'] ?? data['subscriptionEndDate']);
        if (expiryDate != null && expiryDate.isBefore(DateTime.now())) {
          isPaid = false;
        }
      }

      return isPaid;
    } catch (e) {
      debugPrint('Subscription validation error: $e');
      return false;
    }
  }

  DateTime? _parseExpiryDate(dynamic expiryRaw) {
    try {
      if (expiryRaw is Timestamp) return expiryRaw.toDate();
      if (expiryRaw is String) return DateTime.tryParse(expiryRaw);
      if (expiryRaw is DateTime) return expiryRaw;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ========== GYM RESOLUTION ==========
  Future<Map<String, String>?> _resolveGymAndMember(String uid) async {
    try {
      // Try member_index collection first
      final indexDoc = await FirebaseFirestore.instance
          .collection('member_index')
          .doc(uid)
          .get();

      if (indexDoc.exists) {
        final data = indexDoc.data() as Map<String, dynamic>?;
        final gymId = data?['gymId'] as String?;
        if (gymId != null && gymId.isNotEmpty) {
          return {'gymId': gymId, 'memberId': uid};
        }
      }

      // Fallback: Search through gyms
      final gymsSnapshot = await FirebaseFirestore.instance
          .collection('gyms')
          .limit(50)
          .get();

      for (final gymDoc in gymsSnapshot.docs) {
        final memberDoc = await FirebaseFirestore.instance
            .collection('gyms')
            .doc(gymDoc.id)
            .collection('members')
            .doc(uid)
            .get();

        if (memberDoc.exists) {
          return {'gymId': gymDoc.id, 'memberId': uid};
        }
      }

      return null;
    } catch (e) {
      debugPrint('Gym resolution error: $e');
      return null;
    }
  }

  // ========== DATA LOADING ==========
  Future<void> _loadAllData(String gymId, String memberId) async {
    try {
      await Future.wait([
        _loadUserProfile(gymId, memberId),
        _loadStreakData(gymId, memberId),
        _loadStats(gymId, memberId),
        _loadActiveDays(gymId, memberId),
        _loadNotices(gymId),
        _loadChallenges(),
        _loadNotificationCount(gymId, memberId),
      ]);
    } catch (e) {
      debugPrint('Data loading error: $e');
    }
  }

  Future<void> _loadUserProfile(String gymId, String memberId) async {
    try {
      final memberDoc = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .get();

      if (!memberDoc.exists) return;

      final data = memberDoc.data() as Map<String, dynamic>;

      // Update name
      final firstName = data['firstName'] as String?;
      final lastName = data['lastName'] as String?;
      final fullName = data['name'] as String?;

      String displayName = 'Member';
      if (firstName != null && firstName.isNotEmpty) {
        displayName = '$firstName${lastName != null ? ' $lastName' : ''}';
      } else if (fullName != null && fullName.isNotEmpty) {
        displayName = fullName;
      }

      // Update email
      final email = data['email'] as String?;

      // Load profile image
      final profileImageUrl = await _resolveProfileImage(data);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _userName = displayName;
            if (email != null && email.isNotEmpty) _userEmail = email;
            _profileImageUrl = profileImageUrl;
          });
        }
      });
    } catch (e) {
      debugPrint('Profile loading error: $e');
    }
  }

  Future<String> _resolveProfileImage(Map<String, dynamic> data) async {
    try {
      final profileImageUrl = data['profileImageUrl'] as String?;
      final imageUrl = data['imageUrl'] as String?;
      final profileImage = data['profileImage'] as String?;

      // Check URLs in order of preference
      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        if (await _urlExists(profileImageUrl)) return profileImageUrl;
      }

      if (imageUrl != null && imageUrl.isNotEmpty) {
        if (await _urlExists(imageUrl)) return imageUrl;
      }

      if (profileImage != null && profileImage.isNotEmpty) {
        final cloudinaryUrl = await _getCloudinaryUrl(profileImage);
        if (cloudinaryUrl.isNotEmpty) return cloudinaryUrl;
      }

      return '';
    } catch (e) {
      debugPrint('Profile image resolution error: $e');
      return '';
    }
  }

  Future<String> _getCloudinaryUrl(String publicId) async {
    try {
      final cloudName = CloudinaryConfig.cloudName;
      final url = 'https://res.cloudinary.com/$cloudName/image/upload/w_200,h_200,c_fill/$publicId';

      if (await _urlExists(url)) return url;

      // Fallback to original
      final fallbackUrl = 'https://res.cloudinary.com/$cloudName/image/upload/$publicId';
      if (await _urlExists(fallbackUrl)) return fallbackUrl;

      return '';
    } catch (e) {
      debugPrint('Cloudinary URL error: $e');
      return '';
    }
  }

  Future<bool> _urlExists(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;

      final response = await http.get(uri).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadStreakData(String gymId, String memberId) async {
    try {
      final streakDoc = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('stats')
          .doc('streak')
          .get();

      int streak = 0;
      if (streakDoc.exists) {
        final data = streakDoc.data() as Map<String, dynamic>;
        final raw = data['currentStreak'];
        streak = (raw is num) ? raw.toInt() : int.tryParse(raw?.toString() ?? '0') ?? 0;
      }

      if (mounted) {
        setState(() => _currentStreak = streak);
      }
    } catch (e) {
      debugPrint('Streak loading error: $e');
    }
  }

  Future<void> _loadStats(String gymId, String memberId) async {
    try {
      final statsDoc = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('stats')
          .doc('current')
          .get();

      if (statsDoc.exists) {
        final data = statsDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _steps = (data['steps'] as num?)?.toInt() ?? _steps;
            _goal = (data['stepsGoal'] as num?)?.toInt() ?? _goal;
          });
        }
      }
    } catch (e) {
      debugPrint('Stats loading error: $e');
    }
  }

  Future<void> _loadActiveDays(String gymId, String memberId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('attendance')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeekMidnight))
          .limit(7)
          .get();

      final attendanceDates = attendanceSnapshot.docs
          .map((doc) {
        final timestamp = doc.data()['timestamp'];
        return timestamp is Timestamp ? timestamp.toDate() : null;
      })
          .whereType<DateTime>()
          .toList();

      if (mounted) {
        setState(() {
          _activeDays = _calculateActiveDays(attendanceDates);
        });
      }
    } catch (e) {
      debugPrint('Active days loading error: $e');
    }
  }

  List<bool> _calculateActiveDays(List<DateTime> attendanceDates) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final activeDays = List.filled(7, false);
    final attendanceSet = attendanceDates.map((date) {
      final local = date.toLocal();
      return '${local.year}-${local.month}-${local.day}';
    }).toSet();

    for (int i = 0; i < 7; i++) {
      final day = startOfWeekMidnight.add(Duration(days: i));
      final key = '${day.year}-${day.month}-${day.day}';
      if (attendanceSet.contains(key)) activeDays[i] = true;
    }

    return activeDays;
  }

  Future<void> _loadNotices(String gymId) async {
    try {
      final noticesSnapshot = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('notices')
          .where('expiryDate', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('expiryDate', descending: true)
          .limit(3)
          .get();

      final notices = noticesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title']?.toString() ?? '',
          'message': data['message']?.toString() ?? '',
          'date': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'isImportant': data['isImportant'] == true,
        };
      }).toList();

      if (mounted) {
        setState(() => _notices = notices);
      }
    } catch (e) {
      debugPrint('Notices loading error: $e');
    }
  }

  Future<void> _loadChallenges() async {
    try {
      final challengesSnapshot = await FirebaseFirestore.instance
          .collection('global_challenges')
          .where('status', isEqualTo: 'active')
          .where('isActive', isEqualTo: true)
          .limit(3)
          .get();

      final now = DateTime.now();
      final challenges = challengesSnapshot.docs
          .map((doc) {
        final data = doc.data();
        final startAt = (data['startAt'] as Timestamp?)?.toDate();
        final endAt = (data['endAt'] as Timestamp?)?.toDate();

        // Filter by date range
        if (startAt != null && now.isBefore(startAt)) return null;
        if (endAt != null && now.isAfter(endAt)) return null;

        return {
          'id': doc.id,
          'title': data['title']?.toString() ?? '',
          'description': data['description']?.toString() ?? '',
          'startDate': startAt,
          'endDate': endAt,
          'participants': (data['joinedBy'] as List?)?.length ?? 0,
          'type': data['type']?.toString() ?? 'general',
        };
      })
          .whereType<Map<String, dynamic>>()
          .toList();

      if (mounted) {
        setState(() => _challenges = challenges);
      }
    } catch (e) {
      debugPrint('Challenges loading error: $e');
    }
  }

  Future<void> _loadNotificationCount(String gymId, String memberId) async {
    try {
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .limit(50)
          .get();

      if (mounted) {
        setState(() => _notificationCount = notificationsSnapshot.docs.length);
      }
    } catch (e) {
      debugPrint('Notification count error: $e');
    }
  }

  void _setupNotificationListener(String gymId, String memberId) {
    _notificationSubscription?.cancel();

    _notificationSubscription = FirebaseFirestore.instance
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(memberId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _notificationCount = snapshot.docs.length);
      }
    }, onError: (error) {
      debugPrint('Notification listener error: $error');
    });
  }

  // ========== REFRESH HANDLER ==========
  Future<void> _onRefresh() async {
    try {
      // Reload all data
      if (_gymId.isNotEmpty && _memberId.isNotEmpty) {
        await _loadAllData(_gymId, _memberId);
        await _saveCacheData();
      }

      if (mounted) {
        setState(() {});
        _refreshController.refreshCompleted();
      }
    } catch (e) {
      debugPrint('Refresh error: $e');
      _refreshController.refreshFailed();
      _showSnackbar('Refresh failed. Please try again.');
    }
  }

  // ========== SIMPLIFIED NAVIGATION ==========
  Future<void> _navigateWithThrottle(Future<void> Function() navigationFunction) async {
    // Simple throttle to prevent rapid navigation
    final now = DateTime.now();
    if (_lastNavigationTime != null &&
        now.difference(_lastNavigationTime!) < const Duration(milliseconds: 300)) {
      return;
    }

    _lastNavigationTime = now;

    try {
      await navigationFunction();
    } catch (e) {
      debugPrint('Navigation error: $e');
      _showSnackbar('Navigation failed. Please try again.');
    }
  }

  Future<void> _navigateToWorkouts() async {
    await _navigateWithThrottle(() async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutHomeScreen(gymId: _gymId, memberId: _memberId),
        ),
      );
    });
  }

  Future<void> _navigateToDiet() async {
    if (_gymId.isEmpty || _memberId.isEmpty) {
      _showSnackbar('Profile not loaded yet');
      return;
    }

    await _navigateWithThrottle(() async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DailyDietPlanScreen(gymId: _gymId, memberId: _memberId),
        ),
      );
    });
  }

  Future<void> _navigateToChat() async {
    await _navigateWithThrottle(() async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(gymId: _gymId, memberId: _memberId),
        ),
      );
    });
  }

  Future<void> _navigateToProfile() async {
    if (_gymId.isEmpty || _memberId.isEmpty) {
      _showSnackbar('Profile data not ready');
      return;
    }

    await _navigateWithThrottle(() async {
      await Navigator.pushNamed(
        context,
        AppRoutes.memberProfile,
        arguments: {'gymId': _gymId, 'memberId': _memberId},
      );
    });
  }

  Future<void> _navigateToChallenges() async {
    await _navigateWithThrottle(() async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MemberChallengesScreen(gymId: _gymId, memberId: _memberId),
        ),
      );
    });
  }

  Future<void> _navigateToNotifications() async {
    await _navigateWithThrottle(() async {
      await Navigator.pushNamed(context, AppRoutes.memberNotifications);
    });
  }

  // ========== UI HELPERS ==========
  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
            (route) => false,
      );
    });
  }

  void _redirectToSubscription() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.memberSubscription,
            (route) => false,
      );
    });
  }

  // ========== BUILD METHODS ==========
  @override
  Widget build(BuildContext context) {
    // Show loading screen until initial check is complete
    if (_isLoading) {
      return _buildLoadingScreen(context);
    }

    // If subscription check is not complete yet, show loading
    if (!_subscriptionCheckComplete) {
      return _buildLoadingScreenWithMessage(context, 'Verifying subscription...');
    }

    // If subscription is not active, redirect
    if (!_hasActiveSubscription) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _redirectToSubscription());
      return _buildLoadingScreen(context);
    }

    // All checks passed, show dashboard
    return _buildDashboardScreen(context);
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'Loading Dashboard...',
              style: TextStyle(
                color: _textPrimary(context),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreenWithMessage(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: _backgroundColor(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: _textPrimary(context),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardScreen(BuildContext context) {
    final isDarkMode = _isDarkMode(context);

    return Scaffold(
      backgroundColor: _backgroundColor(context),
      body: SafeArea(
        child: SmartRefresher(
          controller: _refreshController,
          onRefresh: _onRefresh,
          enablePullDown: true,
          header: ClassicHeader(
            textStyle: TextStyle(color: _greyText(context)),
            refreshingIcon: CircularProgressIndicator(color: Colors.green),
            completeText: 'Refresh Complete',
            failedText: 'Refresh Failed',
            idleText: 'Pull down to refresh',
            releaseText: 'Release to refresh',
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildAppBar(context)),
              SliverToBoxAdapter(child: const SizedBox(height: 16)),
              SliverToBoxAdapter(child: _buildBannerSection(context)),
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildStatsCard(context, isDarkMode)),
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
              if (_challenges.isNotEmpty) SliverToBoxAdapter(child: _buildChallengesSection(context)),
              SliverToBoxAdapter(child: const SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildQuickActions(context)),
              SliverToBoxAdapter(child: const SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomTabBar(context),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 18) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: _navigateToProfile,
            child: _profileImageUrl.isNotEmpty
                ? CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(_profileImageUrl),
              onBackgroundImageError: (_, __) {
                if (mounted) {
                  setState(() => _profileImageUrl = '');
                }
              },
            )
                : CircleAvatar(
              radius: 24,
              backgroundColor: Colors.green,
              child: Icon(
                Iconsax.profile_circle,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: _greyText(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Stack(
            children: [
              IconButton(
                icon: Icon(Iconsax.notification, color: _textPrimary(context), size: 28),
                onPressed: _navigateToNotifications,
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(
                      _notificationCount > 9 ? '9+' : _notificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerSection(BuildContext context) {
    if (_notices.isEmpty) {
      return _buildDefaultBanner();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Latest Notices',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary(context),
                ),
              ),
              if (_notices.length > 1)
                Text(
                  '${_notices.length} notices',
                  style: TextStyle(
                    color: _greyText(context),
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: PageView.builder(
              itemCount: _notices.length,
              itemBuilder: (context, index) => _buildNoticeBanner(context, _notices[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return BannerCarousel(
      assetPaths: ['assets/ads/ad1.jpg', 'assets/ads/ad2.jpg', 'assets/ads/ad3.jpg'],
      autoScrollDuration: const Duration(seconds: 5),
      borderRadius: 20,
    );
  }

  Widget _buildNoticeBanner(BuildContext context, Map<String, dynamic> notice) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBackground(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notice['title'] ?? '',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _textPrimary(context),
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            notice['message'] ?? '',
            style: TextStyle(
              color: _greyText(context),
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            DateFormat('MMM dd').format(notice['date'] ?? DateTime.now()),
            style: TextStyle(
              color: _greyText(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, bool isDarkMode) {
    final stepPercent = _goal > 0 ? (_steps / _goal).clamp(0.0, 1.0) : 0.0;
    final weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBackground(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Stats',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _textPrimary(context),
                  fontSize: 16,
                ),
              ),
              Text(
                '$_currentStreak day streak',
                style: TextStyle(
                  color: _greyText(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 100,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _lottiePulseController,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Lottie.asset(
                          'assets/animations/streak_fire.json',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_currentStreak',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _textPrimary(context),
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'days',
                      style: TextStyle(
                        color: _greyText(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Steps',
                          style: TextStyle(
                            color: _greyText(context),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$_steps/$_goal',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _textPrimary(context),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final progressWidth = constraints.maxWidth * stepPercent;
                        return Stack(
                          children: [
                            Container(
                              height: 6,
                              width: constraints.maxWidth,
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            Container(
                              height: 6,
                              width: progressWidth.isFinite ? progressWidth : 0,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'This Week',
                      style: TextStyle(
                        color: _greyText(context),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        return Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: _activeDays[index]
                                ? Colors.green
                                : (isDarkMode ? Colors.grey[800] : Colors.grey[300]),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              weekdayLabels[index],
                              style: TextStyle(
                                color: _activeDays[index] ? Colors.white : _greyText(context),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Challenges',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary(context),
                ),
              ),
              GestureDetector(
                onTap: _navigateToChallenges,
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _challenges.length,
              itemBuilder: (context, index) {
                final challenge = _challenges[index];
                return Container(
                  width: 280,
                  margin: EdgeInsets.only(right: 16),
                  child: ChallengeCard(
                    title: challenge['title'] ?? '',
                    description: challenge['description'] ?? '',
                    startDate: challenge['startDate'],
                    endDate: challenge['endDate'],
                    participants: challenge['participants'] ?? 0,
                    status: 'active',
                    type: challenge['type'] ?? 'general',
                    onTap: () => _showSnackbar('Opening ${challenge['title']}'),
                    isDarkMode: _isDarkMode(context),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          WorkoutSectionCard(
            gymId: _gymId,
            memberId: _memberId,
            onTapSeeAll: _navigateToWorkouts,
            onTapItem: (id, data) async {
              await _navigateWithThrottle(() async {
                await Navigator.push(
                  context,
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExerciseDetailScreen(
                          gymId: _gymId,
                          memberId: _memberId,
                          exercise: Exercise.fromJson(data),
                          isPremade: data['isPremade'] ?? false,
                        ),
                      ),
                    ),
                );
              });
            },
            primaryGreen: Colors.green,
            cardBackground: _cardBackground(context),
            textPrimary: _textPrimary(context),
            greyText: _greyText(context),
          ),
          const SizedBox(height: 16),
          _buildMealPlansSection(context),
          const SizedBox(height: 16),
          if (_notices.isNotEmpty) ...[
            const SizedBox(height: 16),
            NoticesUpdatesCard(
              onTap: () {
                // optional: navigate to notices screen
                _navigateWithThrottle(() async {
                  // example navigation - replace with your notices screen if you have one
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => NoticesScreen(...)));
                  _showSnackbar('Opening notices');
                });
              },
              primaryGreen: Colors.green,
              cardBackground: _cardBackground(context),
              textPrimary: _textPrimary(context),
              greyText: _greyText(context),
              showSnackbar: _showSnackbar,
            ),
          ]
        ],
      ),
    );
  }
// Horizontal scrollable Meal Plans section (uses DietPlansCard as item)
  Widget _buildMealPlansSection(BuildContext context) {
    final textPrimary = _textPrimary(context);
    final greyText = _greyText(context);
    final cardBg = _cardBackground(context);

    // Temporarily create a small list of placeholders. Replace with real diet plan data when available.
    final mockMealPlans = List.generate(4, (i) => {
      'id': 'plan_$i',
      'title': 'Meal Plan ${i + 1}',
      'subtitle': 'Balanced meals — ${3 + i} meals/day',
    });

    const double sectionEdgePadding = 20.0; // parent padding for the whole section
    const double itemGap = 12.0; // gap between items
    const double minItemWidth = 280.0;
    const double maxItemWidth = 360.0;
    const double listHeight = 210.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Header row with title and View All
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meal Plans',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              GestureDetector(
                onTap: _navigateToDiet,
                child: Text(
                  'View All',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal list: list has no padding; spacing handled by per-item margins
          LayoutBuilder(builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.of(context).size.width;
            final double itemWidth = (availableWidth * 0.82).clamp(minItemWidth, maxItemWidth);

            return SizedBox(
              height: listHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: mockMealPlans.length,
                padding: EdgeInsets.zero, // important: parent Padding provides the outer inset
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final plan = mockMealPlans[index];
                  final bool isFirst = index == 0;
                  final bool isLast = index == mockMealPlans.length - 1;

                  return Container(
                    width: itemWidth,
                    margin: EdgeInsets.only(
                      left: isFirst ? 0 : itemGap / 2,
                      right: isLast ? 0 : itemGap / 2,
                    ),
                    // Ensure rounded corners/shadows don't reveal the underlying scaffold
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Material(
                        color: Colors.transparent,
                        child: DietPlansCard(
                          onTap: _navigateToDiet,
                          primaryGreen: Colors.green,
                          cardBackground: cardBg,
                          textPrimary: textPrimary,
                          greyText: greyText,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ],
    );
  }

  Widget _buildBottomTabBar(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).bottomAppBarTheme.color ?? _backgroundColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTabItem(
            context: context,
            icon: Iconsax.home,
            label: 'Home',
            isActive: true,
            onTap: () {},
          ),
          _buildTabItem(
            context: context,
            icon: Iconsax.weight,
            label: 'Workout',
            isActive: false,
            onTap: _navigateToWorkouts,
          ),
          _buildTabItem(
            context: context,
            icon: Iconsax.message_programming,
            label: 'Chat',
            isActive: false,
            onTap: _navigateToChat,
          ),
          _buildTabItem(
            context: context,
            icon: Iconsax.menu_board,
            label: 'Meal',
            isActive: false,
            onTap: _navigateToDiet,
          ),
          _buildTabItem(
            context: context,
            icon: Iconsax.user,
            label: 'Profile',
            isActive: false,
            onTap: _navigateToProfile,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? Colors.green : _greyText(context),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? Colors.green : _greyText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}