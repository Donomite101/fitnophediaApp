import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../auth/login_screen.dart';
import 'app_subscription/gym_owner_subscription_screen.dart';
import 'member_management/member_management_screen.dart';
import 'notifications/notifications_screen.dart';
import 'staff_management/staff_screen.dart';
import 'payment_management/payment_management_screen.dart';
import 'profile/profile_settings_screen.dart';
import 'notices/notices_screen.dart';
import 'classes/classes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';

class GymOwnerDashboard extends StatefulWidget {
  const GymOwnerDashboard({Key? key}) : super(key: key);

  @override
  State<GymOwnerDashboard> createState() => _GymOwnerDashboardState();
}

class _GymOwnerDashboardState extends State<GymOwnerDashboard> {
  int _currentIndex = 0;
  bool _checkingSubscription = true;
  bool _loadingDashboard = true;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _gymStream;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // FCM and Notifications
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  String? _fcmToken;

  // Subscription status
  String _subscriptionStatus = 'active';
  DateTime? _expiryDate;
  int _daysUntilExpiry = 0;
  bool _showExpiryWarning = false;

  // Dashboard stats
  int _memberCount = 0;
  int _activeSubscriptions = 0;
  double _totalRevenue = 0.0;
  int _expiringSoonCount = 0;
  int _dailyVisits = 0;
  int _activeTrainers = 0;
  int _adviserMembers = 0;
  int _totalClasses = 0;

  // Search and Filter
  TextEditingController _searchController = TextEditingController();
  String _selectedSort = 'Expired Soon';
  List<String> _sortOptions = ['Expired Soon', 'Recently Added', 'Name A-Z', 'Status'];

  // Members data
  List<Map<String, dynamic>> _allMembers = [];
  List<Map<String, dynamic>> _displayedMembers = [];
  List<Map<String, dynamic>> _personalTrainers = [];
  List<Map<String, dynamic>> _recentActivities = [];
  List<Map<String, dynamic>> _recentPayments = [];
  List<Map<String, dynamic>> _recentNotices = [];
  List<Map<String, dynamic>> _upcomingClasses = [];

  // Gym / Owner Info
  String _gymName = 'FitZone Gym';
  String _ownerEmail = '';
  String? _profileImage;
  String _gymId = 'rEaNbAEyo1luXVZydMQ3';

  @override
  void initState() {
    super.initState();
    _optimisticLoad();
    _initializeFCM();
    _initializeSubscriptionListener();
    _initializeGymStream();
    _loadDashboardData();
    _searchController.addListener(_filterMembers);
  }

  Future<void> _optimisticLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool('subscriptionActive') ?? false;
      final lastVerify = prefs.getInt('lastSubVerify') ?? 0;
      
      // Trust if verified within last 2 hours
      final isRecent = (DateTime.now().millisecondsSinceEpoch - lastVerify) < 7200000;

      if (isActive && isRecent) {
        if (mounted) {
          setState(() {
            _checkingSubscription = false;
            // Optionally load other cached info if we were to add more keys
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> _initializeFCM() async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('User granted permission: ${settings.authorizationStatus}');

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $_fcmToken');

      // Save token to Firestore
      if (_fcmToken != null) {
        await _saveFCMTokenToFirestore(_fcmToken!);
      }

      // Handle token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        _saveFCMTokenToFirestore(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle when app is in background but opened
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // Handle initial message when app is opened from terminated state
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }

    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidInitializationSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitializationSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) {
        // Handle notification tap
        _handleNotificationTap(notificationResponse.payload);
      },
    );

    // Configure Android notification channel
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'gym_owner_channel',
        'Gym Owner Notifications',
        description: 'Notifications for gym owners',
        importance: Importance.max,
        playSound: true,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveFCMTokenToFirestore(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('FCM token saved to Firestore');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received foreground message: ${message.messageId}');

    // Show local notification
    _showLocalNotification(message);

    // Update UI if needed (e.g., refresh notifications badge)
    setState(() {});
  }

  /// Handle background messages
  void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('Handling background message: ${message.messageId}');

    // Navigate to appropriate screen based on message data
    _handleNotificationNavigation(message.data);
  }

  /// Handle notification tap
  void _handleNotificationTap(String? payload) {
    if (payload != null) {
      try {
        final data = Map<String, String>.from(payload.split('&').fold({}, (map, element) {
          final keyValue = element.split('=');
          if (keyValue.length == 2) {
            map[keyValue[0]] = keyValue[1];
          }
          return map;
        }));

        _handleNotificationNavigation(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Navigate based on notification data
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type']?.toString();

    switch (type) {
      case 'new_member':
        setState(() => _currentIndex = 1); // Members screen
        break;
      case 'payment_received':
        setState(() => _currentIndex = 3); // Payments screen
        break;
      case 'class_reminder':
        setState(() => _currentIndex = 4); // Classes screen
        break;
      case 'new_notice':
        setState(() => _currentIndex = 5); // Notices screen
        break;
      case 'staff_alert':
        setState(() => _currentIndex = 2); // Staff screen
        break;
      default:
      // Default to notifications screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    final apple = message.notification?.apple;

    if (notification != null) {
      AndroidNotificationDetails androidPlatformChannelSpecifics =
      const AndroidNotificationDetails(
        'gym_owner_channel',
        'Gym Owner Notifications',
        channelDescription: 'Notifications for gym owners',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );

      DarwinNotificationDetails iosPlatformChannelSpecifics =
      const DarwinNotificationDetails();

      NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        notification.title,
        notification.body,
        platformChannelSpecifics,
        payload: message.data.entries
            .map((e) => '${e.key}=${e.value}')
            .join('&'),
      );
    }
  }

  /// Filter members based on search query
  void _filterMembers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _displayedMembers = _allMembers.take(5).toList();
      } else {
        _displayedMembers = _allMembers.where((member) {
          final name = member['name']?.toString().toLowerCase() ?? '';
          final email = member['email']?.toString().toLowerCase() ?? '';
          final phone = member['phone']?.toString().toLowerCase() ?? '';
          return name.contains(query) || email.contains(query) || phone.contains(query);
        }).take(5).toList();
      }
    });
  }

  /// Sort members based on selected criteria
  void _sortMembers() {
    setState(() {
      switch (_selectedSort) {
        case 'Expired Soon':
          _allMembers.sort((a, b) {
            final dateA = _parseDate(a['expiredDate']);
            final dateB = _parseDate(b['expiredDate']);
            return dateA.compareTo(dateB);
          });
          break;
        case 'Recently Added':
          _allMembers.sort((a, b) => b['addedDate'].compareTo(a['addedDate']));
          break;
        case 'Name A-Z':
          _allMembers.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
          break;
        case 'Status':
          _allMembers.sort((a, b) => (a['status'] ?? '').compareTo(b['status'] ?? ''));
          break;
      }
      _filterMembers();
    });
  }

  DateTime _parseDate(String dateString) {
    try {
      final parts = dateString.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse('20${parts[2]}');
        return DateTime(year, month, day);
      }
    } catch (e) {
      debugPrint('Error parsing date: $e');
    }
    return DateTime(2100);
  }

  /// Initialize real-time gym listener
  void _initializeGymStream() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final gyms = await _firestore
          .collection('gyms')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (gyms.docs.isNotEmpty) {
        _gymStream = _firestore
            .collection('gyms')
            .doc(gyms.docs.first.id)
            .snapshots();

        _gymStream!.listen((snapshot) {
          final data = snapshot.data();
          if (mounted) {
            setState(() {
              _gymName = data?['businessName'] ?? 'FitZone Gym';
              _profileImage = data?['logoUrl'];
              _gymId = gyms.docs.first.id;
            });
          }
        });
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        if (mounted) {
          setState(() {
            _ownerEmail = data['email'] ?? user.email ?? '';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _ownerEmail = user.email ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing gym stream: $e');
    }
  }

  /// Simplified Subscription Validation - ONE TIME CHECK
  /// REAL-TIME SUBSCRIPTION LISTENER — THIS FIXES EVERYTHING
  void _initializeSubscriptionListener() {
    final user = _auth.currentUser;
    if (user == null) {
      _redirectToLogin();
      return;
    }

    // Listen to subscription changes in REAL-TIME
    _firestore
        .collection('app_subscriptions')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || snapshot.data() == null) {
        _redirectToSubscription();
        return;
      }

      final data = snapshot.data()!;
      final status = (data['status'] ?? 'inactive').toString().toLowerCase();
      final expiryTimestamp = data['expiryDate'];
      DateTime? expiryDate;

      if (expiryTimestamp is Timestamp) {
        expiryDate = expiryTimestamp.toDate();
      }

      final isValid = status == 'active' &&
          expiryDate != null &&
          expiryDate.isAfter(DateTime.now());

      if (!isValid) {
        _redirectToSubscription();
        return;
      }

      // Update UI if still valid
      final daysLeft = expiryDate.difference(DateTime.now()).inDays;

      if (mounted) {
        setState(() {
          _subscriptionStatus = status;
          _expiryDate = expiryDate;
          _daysUntilExpiry = daysLeft;
          _showExpiryWarning = daysLeft <= 7 && daysLeft > 0;
          _checkingSubscription = false;
        });
      }
    }, onError: (error) {
      debugPrint('Subscription listener error: $error');
      if (mounted) {
        setState(() => _checkingSubscription = false);
      }
    });
  }

  void _redirectToSubscription() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GymOwnerSubscriptionScreen()),
      );
    });
  }

  void _redirectToLogin() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  /// Refresh dashboard data
  Future<void> _refreshDashboard() async {
    setState(() {
      _loadingDashboard = true;
    });
    await _loadDashboardData();
  }

  /// Load Dashboard Stats from Firestore
  Future<void> _loadDashboardData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final gyms = await _firestore
          .collection('gyms')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (gyms.docs.isEmpty) {
        debugPrint("No gym found for owner ${user.uid}");
        _loadSampleData();
        if (mounted) {
          setState(() => _loadingDashboard = false);
        }
        return;
      }

      final gymId = gyms.docs.first.id;
      _gymId = gymId;
      await _loadRealData(gymId);
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
      _loadSampleData();
    }

    if (mounted) {
      setState(() => _loadingDashboard = false);
    }
  }

  /// Format revenue for display
  String get formattedRevenue {
    if (_totalRevenue == 0) return '₹0';

    if (_totalRevenue < 1000) {
      return '₹${_totalRevenue.toStringAsFixed(0)}';
    } else if (_totalRevenue < 100000) {
      return '₹${(_totalRevenue / 1000).toStringAsFixed(1)}K';
    } else if (_totalRevenue < 10000000) {
      return '₹${(_totalRevenue / 100000).toStringAsFixed(1)}L';
    } else {
      return '₹${(_totalRevenue / 10000000).toStringAsFixed(1)}Cr';
    }
  }

  Future<void> _loadRealData(String gymId) async {
    try {
      // Load members data - ONLY COUNT ACTIVE MEMBERS
      final membersSnapshot = await _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .get();

      int totalMembers = 0;
      int activeCount = 0;
      int expiringSoon = 0;
      double totalRevenue = 0.0;
      List<Map<String, dynamic>> allMembers = [];

      final now = DateTime.now();
      final sevenDaysLater = now.add(const Duration(days: 7));

      for (final doc in membersSnapshot.docs) {
        final data = doc.data();
        final status = (data['subscriptionStatus'] ?? data['status'] ?? '').toString().toLowerCase();

        // Only count and process ACTIVE members for revenue and display
        if (status == 'active') {
          totalMembers++; // Only count active members
          activeCount++;

          final planEnd = data['subscriptionEndDate'] ?? data['planEndDate'] ?? data['endDate'];
          DateTime? planEndDate;
          if (planEnd is Timestamp) planEndDate = planEnd.toDate();

          if (planEndDate != null &&
              planEndDate.isAfter(now) &&
              planEndDate.isBefore(sevenDaysLater)) {
            expiringSoon++;
          }

          // Add subscription price for active members only - FIXED CALCULATION
          final subscriptionPrice = (data['subscriptionPrice'] ?? data['price'] ?? 0).toDouble();
          totalRevenue += subscriptionPrice;

          debugPrint('Active Member: ${data['name']}, Price: $subscriptionPrice'); // Debug log

          allMembers.add({
            'name': data['name'] ?? data['fullName'] ?? 'Unknown Member',
            'email': data['email'] ?? '',
            'expiredDate': planEndDate != null ?
            '${planEndDate.day.toString().padLeft(2, '0')}/${planEndDate.month.toString().padLeft(2, '0')}/${planEndDate.year.toString().substring(2)}' : 'N/A',
            'age': data['age']?.toString() ?? 'N/A',
            'status': 'Active',
            'phone': data['phone'] ?? data['phoneNumber'] ?? 'N/A',
            'lastVisited': 'Recently',
            'addedDate': data['createdAt'] ?? data['joinedDate'] ?? Timestamp.now(),
          });
        }
      }

      // Sort by expiry date
      allMembers.sort((a, b) {
        final dateA = _parseDate(a['expiredDate']);
        final dateB = _parseDate(b['expiredDate']);
        return dateA.compareTo(dateB);
      });

      // Load staff data
      final staffSnapshot = await _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('staff')
          .where('role', isEqualTo: 'trainer')
          .get();

      List<Map<String, dynamic>> trainers = [];
      for (final doc in staffSnapshot.docs) {
        final data = doc.data();
        trainers.add({
          'name': data['name'] ?? data['fullName'] ?? 'Unknown Trainer',
          'role': data['role'] ?? 'Personal Trainer',
          'clients': '${(data['clientsCount'] ?? data['totalClients'] ?? 0).toString()}+',
          'experience': '${(data['experienceYears'] ?? data['experience'] ?? 0).toString()}+ Years',
          'specialty': data['specialty'] ?? data['expertise'] ?? 'Fitness Training',
          'image': data['profileImage'] ?? data['imageUrl'] ?? '',
        });
      }

      // Load ACTIVE plans data and add to revenue
      final plansSnapshot = await _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('plans')
          .get();

      double plansRevenue = 0.0;
      int activePlans = 0;
      for (final doc in plansSnapshot.docs) {
        final data = doc.data();
        final planStatus = (data['status'] ?? '').toString().toLowerCase();
        if (planStatus == 'active') {
          activePlans++;
          final planPrice = (data['price'] ?? data['monthlyPrice'] ?? 0).toDouble();
          plansRevenue += planPrice;
          debugPrint('Active Plan: ${data['name']}, Price: $planPrice'); // Debug log
        }
      }

      // Load notices
      final noticesSnapshot = await _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('notices')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      List<Map<String, dynamic>> notices = [];
      for (final doc in noticesSnapshot.docs) {
        final data = doc.data();
        notices.add({
          'title': data['title'] ?? 'New Notice',
          'message': data['message'] ?? data['content'] ?? '',
          'date': _formatDate(data['createdAt'] ?? data['date']),
        });
      }

      // Load classes
      final classesSnapshot = await _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('classes')
          .where('date', isGreaterThan: Timestamp.now())
          .orderBy('date')
          .limit(5)
          .get();

      List<Map<String, dynamic>> upcomingClasses = [];
      for (final doc in classesSnapshot.docs) {
        final data = doc.data();
        upcomingClasses.add({
          'name': data['className'] ?? data['name'] ?? 'Fitness Class',
          'time': _formatTime(data['date'] ?? data['time']),
          'trainer': data['trainerName'] ?? data['instructor'] ?? 'Trainer',
          'capacity': data['capacity'] ?? data['maxParticipants'] ?? 0,
        });
      }

      // Debug logs to check calculation
      debugPrint('Total Active Members: $totalMembers');
      debugPrint('Members Revenue: $totalRevenue');
      debugPrint('Plans Revenue: $plansRevenue');
      debugPrint('Total Revenue: ${totalRevenue + plansRevenue}');

      if (mounted) {
        setState(() {
          _memberCount = totalMembers; // Now only active members
          _activeSubscriptions = activeCount; // Same as totalMembers since we only count active
          _expiringSoonCount = expiringSoon;
          _totalRevenue = totalRevenue + plansRevenue; // Active members + active plans revenue
          _activeTrainers = trainers.length;
          _adviserMembers = (totalMembers * 0.3).round();
          _dailyVisits = (totalMembers * 0.6).round();
          _totalClasses = upcomingClasses.length;

          _personalTrainers = trainers;
          _allMembers = allMembers;
          _displayedMembers = allMembers.take(5).toList();
          _recentNotices = notices;
          _upcomingClasses = upcomingClasses;
        });
      }
    } catch (e) {
      debugPrint('Error loading real data: $e');
      _loadSampleData();
    }
  }
  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Recently';
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Soon';
  }

  /// Load sample data as fallback
  void _loadSampleData() {
    _personalTrainers = [
      {
        'name': 'King Zarips',
        'role': 'Personal Trainer',
        'clients': '3+',
        'experience': '2+ Years',
        'specialty': 'Learning Mountain',
        'image': '',
      },
      {
        'name': 'Larry Rops',
        'role': 'Personal Trainer',
        'clients': '2+',
        'experience': '1+ Years',
        'specialty': 'Weight Power',
        'image': '',
      },
    ];

    _allMembers = [
      {
        'name': 'Bessie Cooper',
        'email': 'bessiecooper@gmail.com',
        'expiredDate': '08/05/24',
        'age': '24',
        'status': 'Active',
        'phone': '207 555-0119',
        'lastVisited': 'Yesterday',
        'addedDate': Timestamp.now(),
      },
      {
        'name': 'Eleanor Pena',
        'email': 'eleanor.pena@cloud.com',
        'expiredDate': '10/05/24',
        'age': '24',
        'status': 'Active',
        'phone': '290 902-4829',
        'lastVisited': 'Today',
        'addedDate': Timestamp.now(),
      },
    ];

    _displayedMembers = _allMembers.take(5).toList();
    _recentNotices = [
      {
        'title': 'Welcome to Dashboard',
        'message': 'Start managing your gym efficiently.',
        'date': 'Now',
      },
    ];
    _upcomingClasses = [
      {
        'name': 'Morning Yoga',
        'time': '07:00',
        'trainer': 'King Zarips',
        'capacity': 15,
      },
    ];
  }

  /// Logout
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final adjustedTheme = isDark ? theme : theme.copyWith(
      scaffoldBackgroundColor: Colors.grey[50],
      cardColor: Colors.white,
      textTheme: theme.textTheme.copyWith(
        bodyLarge: theme.textTheme.bodyLarge?.copyWith(
          fontFamily: 'SF Pro',
        ),
        bodyMedium: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'SF Pro',
        ),
        titleLarge: theme.textTheme.titleLarge?.copyWith(
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w600,
        ),
        titleMedium: theme.textTheme.titleMedium?.copyWith(
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w600,
        ),
        titleSmall: theme.textTheme.titleSmall?.copyWith(
          fontFamily: 'SF Pro',
        ),
      ),
    );

    if (_checkingSubscription || _loadingDashboard) {
      return Scaffold(
        backgroundColor: adjustedTheme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading Your Gym Dashboard...',
                style: TextStyle(
                  color: adjustedTheme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'SF Pro',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Theme(
      data: adjustedTheme,
      child: Scaffold(
        backgroundColor: adjustedTheme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final showWarning = _showExpiryWarning && _daysUntilExpiry > 0;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: showWarning ? availableWidth * 0.6 : availableWidth,
                    ),
                    child: Text(
                      _gymName.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 18,
                        color: adjustedTheme.appBarTheme.foregroundColor,
                        fontFamily: 'SF Pro',
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (showWarning) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: availableWidth * 0.3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_daysUntilExpiry days',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          backgroundColor: adjustedTheme.appBarTheme.backgroundColor,
          foregroundColor: adjustedTheme.appBarTheme.foregroundColor,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: adjustedTheme.appBarTheme.foregroundColor),
          actions: [
            // NOTIFICATION BELL WITH LIVE UNREAD BADGE
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('gymId', isEqualTo: _gymId)
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                final int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        unreadCount > 0 ? Icons.notifications_active : Icons.notifications_none,
                        size: 26,
                        color: unreadCount > 0
                            ? AppTheme.primaryGreen
                            : adjustedTheme.appBarTheme.foregroundColor,
                      ),
                      tooltip: 'Notifications',
                      onPressed: () => _showNotifications(context),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.alertRed,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
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
                );
              },
            ),

            // REFRESH BUTTON
            IconButton(
              icon: const Icon(Icons.refresh, size: 26),
              tooltip: 'Refresh',
              onPressed: _refreshDashboard,
            ),

            const SizedBox(width: 8),
          ],
        ),
        drawer: Drawer(child: _buildSidebar(adjustedTheme)),
        body: RefreshIndicator(
          onRefresh: _refreshDashboard,
          child: _buildMainContent(adjustedTheme),
        ),
      ),
    );
  }

  /// Show notifications dialog
  void _showNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  /// Sidebar - REMOVED CASH APPROVALS
  Widget _buildSidebar(ThemeData theme) {
    return Container(
      width: 280,
      color: theme.cardColor,
      child: Column(
        children: [
          const SizedBox(height: 60),
          CircleAvatar(
            radius: 40,
            backgroundImage: _profileImage != null && _profileImage!.isNotEmpty
                ? NetworkImage(_profileImage!)
                : null,
            backgroundColor: Colors.grey[800],
            child: _profileImage == null || _profileImage!.isEmpty
                ? Icon(Icons.fitness_center,
                color: theme.colorScheme.onSurface, size: 40)
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _gymName,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              fontFamily: 'SF Pro',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _ownerEmail,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontSize: 12,
              fontFamily: 'SF Pro',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // Navigation Items - REMOVED CASH APPROVALS
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(Icons.dashboard, 'Dashboard', 0, theme),
                _buildNavItem(Icons.people_alt, 'Members', 1, theme),
                _buildNavItem(Icons.badge, 'Staff', 2, theme),
                _buildNavItem(Icons.payment, 'Payments', 3, theme),
                _buildNavItem(Icons.calendar_today, 'Classes', 4, theme),
                _buildNavItem(Icons.announcement, 'Notices', 5, theme),
                _buildNavItem(Icons.settings, 'Profile & Settings', 6, theme),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(color: theme.colorScheme.onSurface.withOpacity(0.3)),
                ),

                // Quick Stats
                _buildQuickStats(theme),
              ],
            ),
          ),

          // Logout
          Container(
            padding: const EdgeInsets.all(20),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.alertRed, size: 24),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: AppTheme.alertRed,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  fontFamily: 'SF Pro',
                ),
              ),
              onTap: _logout,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.alertRed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Stats',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'SF Pro',
            ),
          ),
          const SizedBox(height: 12),
          _buildStatItem('Active Members', _memberCount.toString(),
              Icons.people, theme),
          _buildStatItem('Revenue', formattedRevenue,
              Icons.attach_money, theme),
          _buildStatItem('Trainers', _activeTrainers.toString(),
              Icons.fitness_center, theme),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon,
              color: theme.colorScheme.onSurface.withOpacity(0.7), size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                  fontFamily: 'SF Pro'),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'SF Pro',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      IconData icon, String title, int index, ThemeData theme) {
    final isSelected = _currentIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? Colors.white
              : theme.colorScheme.onSurface.withOpacity(0.7),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurface.withOpacity(0.7),
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontFamily: 'SF Pro',
          ),
        ),
        onTap: () {
          setState(() => _currentIndex = index);
          Navigator.pop(context);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        dense: true,
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme) {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardScreen(theme);
      case 1:
        return const MemberManagementScreen();
      case 2:
        return const StaffManagementScreen();
      case 3:
        return const PaymentManagementScreen();
      case 4:
        return const ClassesScreen();
      case 5:
        return const NoticesScreen();
      case 6:
        return const ProfileSettingsScreen();
      default:
        return _buildDashboardScreen(theme);
    }
  }

  /// Dashboard Screen
  Widget _buildDashboardScreen(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(theme),
          const SizedBox(height: 30),
          _buildStatsSection(theme),
          const SizedBox(height: 30),
          _buildPersonalTrainersSection(theme),
          const SizedBox(height: 30),
          _buildAllMembersSection(theme),
          const SizedBox(height: 30),
          _buildNoticesSection(theme),
          const SizedBox(height: 30),
          _buildClassesSection(theme),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage your Fitness business',
          style: TextStyle(
            color: theme.colorScheme.onBackground,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'SF Pro',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${DateTime.now().day} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}, ${_getFormattedTime()}',
          style: TextStyle(
            color: theme.colorScheme.onBackground.withOpacity(0.6),
            fontSize: 14,
            fontFamily: 'SF Pro',
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Revenue',
                value: _loadingDashboard ? '...' : formattedRevenue,
                subtitle: 'Total Earnings',
                theme: theme,
                icon: Icons.monetization_on,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Members',
                value: _memberCount.toString(),
                subtitle: 'Active Members',
                theme: theme,
                icon: Icons.group,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Visited',
                value: _dailyVisits.toString(),
                subtitle: 'Daily Average',
                theme: theme,
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Trainer',
                value: _activeTrainers.toString(),
                subtitle: 'Active Trainers',
                theme: theme,
                icon: Icons.fitness_center,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required ThemeData theme,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.colorScheme.onBackground.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'SF Pro',
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onBackground,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'SF Pro',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: theme.colorScheme.onBackground.withOpacity(0.6),
              fontSize: 12,
              fontFamily: 'SF Pro',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalTrainersSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Trainer',
            style: TextStyle(
              color: theme.colorScheme.onBackground,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'SF Pro',
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: _personalTrainers.map((trainer) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: AppTheme.primaryGreen,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trainer['name'],
                            style: TextStyle(
                              color: theme.colorScheme.onBackground,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            trainer['role'],
                            style: TextStyle(
                              color: theme.colorScheme.onBackground.withOpacity(0.7),
                              fontSize: 14,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildTrainerStat(trainer['clients'], 'Clients', theme),
                              const SizedBox(width: 16),
                              _buildTrainerStat(trainer['experience'], 'Years', theme),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            trainer['specialty'],
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerStat(String value, String label, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: theme.colorScheme.onBackground,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'SF Pro',
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onBackground.withOpacity(0.6),
            fontSize: 12,
            fontFamily: 'SF Pro',
          ),
        ),
      ],
    );
  }

  Widget _buildAllMembersSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Members (Expiring Soon)',
                      style: TextStyle(
                        color: theme.colorScheme.onBackground,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 150,
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withOpacity(0.2),
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search members...',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onBackground.withOpacity(0.5),
                                fontSize: 14,
                                fontFamily: 'SF Pro',
                              ),
                              border: InputBorder.none,
                              icon: Icon(Icons.search,
                                  size: 16,
                                  color: theme.colorScheme.onBackground.withOpacity(0.5)),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withOpacity(0.2),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSort,
                              icon: Icon(Icons.arrow_drop_down,
                                  size: 16,
                                  color: theme.colorScheme.onBackground),
                              items: _sortOptions.map((String option) {
                                return DropdownMenuItem<String>(
                                  value: option,
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'SF Pro',
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedSort = newValue!;
                                  _sortMembers();
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Members (Expiring Soon)',
                      style: TextStyle(
                        color: theme.colorScheme.onBackground,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.onSurface.withOpacity(0.2),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.onBackground.withOpacity(0.5),
                                  fontSize: 14,
                                  fontFamily: 'SF Pro',
                                ),
                                border: InputBorder.none,
                                icon: Icon(Icons.search,
                                    size: 16,
                                    color: theme.colorScheme.onBackground.withOpacity(0.5)),
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'SF Pro',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.onSurface.withOpacity(0.2),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSort,
                              icon: Icon(Icons.arrow_drop_down,
                                  size: 16,
                                  color: theme.colorScheme.onBackground),
                              items: _sortOptions.map((String option) {
                                return DropdownMenuItem<String>(
                                  value: option,
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'SF Pro',
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedSort = newValue!;
                                  _sortMembers();
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),

          if (_allMembers.length > 5)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Showing ${_displayedMembers.length} of ${_allMembers.length} members',
                    style: TextStyle(
                      color: theme.colorScheme.onBackground.withOpacity(0.6),
                      fontSize: 12,
                      fontFamily: 'SF Pro',
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _currentIndex = 1);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text(
                      'Show All Members',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                ],
              ),
            ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 80,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 200,
                          child: Text(
                            'MEMBER NAME',
                            style: TextStyle(
                              color: theme.colorScheme.onBackground.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'EXPIRED DATE',
                            style: TextStyle(
                              color: theme.colorScheme.onBackground.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            'AGE',
                            style: TextStyle(
                              color: theme.colorScheme.onBackground.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            'STATUS',
                            style: TextStyle(
                              color: theme.colorScheme.onBackground.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            'TEL',
                            style: TextStyle(
                              color: theme.colorScheme.onBackground.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Last Visited',
                            style: TextStyle(
                              color: theme.colorScheme.onBackground.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_displayedMembers.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: theme.colorScheme.onBackground.withOpacity(0.3),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No active members found',
                            style: TextStyle(
                              color: theme.colorScheme.onBackground.withOpacity(0.5),
                              fontSize: 14,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: _displayedMembers.map((member) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 200,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member['name'],
                                      style: TextStyle(
                                        color: theme.colorScheme.onBackground,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'SF Pro',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      member['email'],
                                      style: TextStyle(
                                        color: theme.colorScheme.onBackground.withOpacity(0.6),
                                        fontSize: 12,
                                        fontFamily: 'SF Pro',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  member['expiredDate'],
                                  style: TextStyle(
                                    color: theme.colorScheme.onBackground,
                                    fontSize: 14,
                                    fontFamily: 'SF Pro',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  member['age'],
                                  style: TextStyle(
                                    color: theme.colorScheme.onBackground,
                                    fontSize: 14,
                                    fontFamily: 'SF Pro',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.fitnessgreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Active',
                                    style: TextStyle(
                                      color: AppTheme.fitnessgreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'SF Pro',
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: Text(
                                  member['phone'],
                                  style: TextStyle(
                                    color: theme.colorScheme.onBackground,
                                    fontSize: 14,
                                    fontFamily: 'SF Pro',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  member['lastVisited'],
                                  style: TextStyle(
                                    color: theme.colorScheme.onBackground,
                                    fontSize: 14,
                                    fontFamily: 'SF Pro',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticesSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.announcement, color: AppTheme.primaryGreen, size: 24),
              const SizedBox(width: 12),
              Text(
                'Recent Notices',
                style: TextStyle(
                  color: theme.colorScheme.onBackground,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SF Pro',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_recentNotices.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.announcement_outlined,
                    color: theme.colorScheme.onBackground.withOpacity(0.3),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recent notices',
                    style: TextStyle(
                      color: theme.colorScheme.onBackground.withOpacity(0.5),
                      fontSize: 14,
                      fontFamily: 'SF Pro',
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _recentNotices.map((notice) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notice['title'],
                              style: TextStyle(
                                color: theme.colorScheme.onBackground,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'SF Pro',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notice['message'],
                              style: TextStyle(
                                color: theme.colorScheme.onBackground.withOpacity(0.6),
                                fontSize: 12,
                                fontFamily: 'SF Pro',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        notice['date'],
                        style: TextStyle(
                          color: theme.colorScheme.onBackground.withOpacity(0.5),
                          fontSize: 12,
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildClassesSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: AppTheme.primaryGreen, size: 24),
              const SizedBox(width: 12),
              Text(
                'Upcoming Classes',
                style: TextStyle(
                  color: theme.colorScheme.onBackground,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SF Pro',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_upcomingClasses.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.fitness_center,
                    color: theme.colorScheme.onBackground.withOpacity(0.3),
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No upcoming classes',
                    style: TextStyle(
                      color: theme.colorScheme.onBackground.withOpacity(0.5),
                      fontSize: 14,
                      fontFamily: 'SF Pro',
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _upcomingClasses.map((classItem) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fitness_center,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              classItem['name'],
                              style: TextStyle(
                                color: theme.colorScheme.onBackground,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'SF Pro',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${classItem['time']} • ${classItem['trainer']}',
                              style: TextStyle(
                                color: theme.colorScheme.onBackground.withOpacity(0.6),
                                fontSize: 14,
                                fontFamily: 'SF Pro',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.fitnessgreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${classItem['capacity']} spots',
                          style: TextStyle(
                            color: AppTheme.fitnessgreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'SF Pro',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // Helper methods
  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _getFormattedTime() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final period = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour > 12 ? hour - 12 : hour;
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}$period';
  }
}