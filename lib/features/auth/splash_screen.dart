// lib/features/auth/splash_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lottie/lottie.dart';
import '../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  late StreamSubscription connectivitySub;

  final Completer<void> _splashCompleter = Completer<void>();

  @override
  void initState() {
    super.initState();
    _startVisualSequence();
    _runStartupFlow();
  }

  void _startVisualSequence() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!_splashCompleter.isCompleted) _splashCompleter.complete();
    });
  }

  Future<void> _runStartupFlow() async {
    await Future.delayed(const Duration(milliseconds: 300));

    final prefs = await SharedPreferences.getInstance();
    final localLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final user = _auth.currentUser;

    if (!localLoggedIn || user == null) {
      await _awaitSplashThenNavigate(_goToLogin);
      return;
    }

    final isOnline = await _checkOnline();

    if (!isOnline) {
      await _awaitSplashThenNavigate(() => _openCachedDestination(prefs));
      _listenForConnectivityAndSync();
      return;
    }

    try {
      final refreshedData =
      await _fetchUserDocServer(user.uid, timeoutMs: 1500);

      if (refreshedData != null) {
        await _cacheMinimalUserData(refreshedData, prefs);

        final role = refreshedData['role'];

        if (role == 'member') {
          final email = refreshedData['email'];
          final memberData =
          await _fetchMemberRecord(email, timeoutMs: 1500);

          if (memberData != null) {
            await _cacheMemberData(memberData, prefs);
          }
        }

        await _awaitSplashThenNavigate(() => _openCachedDestination(prefs));
      } else {
        await _awaitSplashThenNavigate(() => _openCachedDestination(prefs));
      }
    } catch (_) {
      await _awaitSplashThenNavigate(() => _openCachedDestination(prefs));
    } finally {
      _listenForConnectivityAndSync();
    }
  }

  Future<void> _awaitSplashThenNavigate(Function navAction) async {
    try {
      await _splashCompleter.future.timeout(const Duration(seconds: 3));
    } catch (_) {}
    navAction();
  }

  Future<bool> _checkOnline() async {
    try {
      final conn = await Connectivity().checkConnectivity();
      if (conn == ConnectivityResult.none) return false;

      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(milliseconds: 800));
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _fetchUserDocServer(
      String uid, {
        int timeoutMs = 1500,
      }) async {
    try {
      final future = _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      final snap = await future.timeout(Duration(milliseconds: timeoutMs));
      if (snap.exists) return snap.data()!;
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchMemberRecord(
      String? email, {
        int timeoutMs = 1500,
      }) async {
    if (email == null || email.isEmpty) return null;
    try {
      final future = _firestore
          .collectionGroup('members')
          .where('email', isEqualTo: email)
          .limit(1)
          .get(const GetOptions(source: Source.server));

      final snap = await future.timeout(Duration(milliseconds: timeoutMs));
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        return {
          ...doc.data(),
          '_memberId': doc.id,
          '_gymId': doc.reference.parent.parent?.id ?? '',
        };
      }
    } catch (_) {}
    return null;
  }

  Future<void> _cacheMinimalUserData(
      Map<String, dynamic> data, SharedPreferences prefs) async {
    await prefs.setString('role', data['role'] ?? '');
    await prefs.setBool(
        'onboardingCompleted', data['onboardingCompleted'] == true);
    await prefs.setBool('approved', data['approved'] == true);
    await prefs.setBool(
        'subscriptionActive', data['subscriptionActive'] == true);
    await prefs.setInt('lastSubVerify', DateTime.now().millisecondsSinceEpoch);

    if (data['email'] != null) {
      await prefs.setString('userEmail', data['email']);
    }
  }

  Future<void> _cacheMemberData(
      Map<String, dynamic> data, SharedPreferences prefs) async {
    await prefs.setString('memberId', data['_memberId']);
    await prefs.setString('gymId', data['_gymId']);
    await prefs.setBool('profileCompleted', data['profileCompleted'] == true);
    await prefs.setBool(
        'hasOngoingSubscription', data['hasOngoingSubscription'] == true);
    await prefs.setInt('lastMemberVerify', DateTime.now().millisecondsSinceEpoch);

    if (data['email'] != null) await prefs.setString('userEmail', data['email']);
    if (data['name'] != null) await prefs.setString('userName', data['name']);
  }

  void _openCachedDestination(SharedPreferences prefs) {
    final role = prefs.getString('role') ?? '';

    switch (role) {
      case 'superadmin':
        Navigator.pushReplacementNamed(context, AppRoutes.superAdminDashboard);
        break;

      case 'gym_owner':
        final onboarding = prefs.getBool('onboardingCompleted') ?? true;
        final approved = prefs.getBool('approved') ?? true;
        final active = prefs.getBool('subscriptionActive') ?? true;

        if (!onboarding) {
          Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
        } else if (!approved) {
          Navigator.pushReplacementNamed(context, AppRoutes.approvalWaiting);
        } else if (!active) {
          Navigator.pushReplacementNamed(context, AppRoutes.subscriptionPlans);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.gymOwnerDashboard);
        }
        break;

      case 'member':
        final hasProfile = prefs.containsKey('profileCompleted')
            ? prefs.getBool('profileCompleted')!
            : true;

        final hasSub = prefs.containsKey('hasOngoingSubscription')
            ? prefs.getBool('hasOngoingSubscription')!
            : true;

        final memberId = prefs.getString('memberId') ?? '';
        final gymId = prefs.getString('gymId') ?? '';
        final email = prefs.getString('userEmail') ?? '';
        final name = prefs.getString('userName') ?? '';

        if (!hasProfile) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.memberProfileSetup,
            arguments: {
              'gymId': gymId,
              'memberId': memberId,
              'memberEmail': email,
              'memberName': name,
            },
          );
        } else if (!hasSub) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.memberSubscription,
            arguments: {
              'gymId': gymId,
              'memberId': memberId,
              'memberEmail': email,
              'memberName': name,
            },
          );
        } else {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.memberDashboard,
            arguments: {
              'gymId': gymId,
              'memberId': memberId,
              'memberEmail': email,
              'memberName': name,
            },
          );
        }
        break;

      default:
        _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  void _listenForConnectivityAndSync() {
    connectivitySub =
        Connectivity().onConnectivityChanged.listen((status) async {
          if (status != ConnectivityResult.none) {
            await _backgroundSync();
            connectivitySub.cancel();
          }
        });

    _backgroundSync();
  }

  Future<void> _backgroundSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));

      if (snap.exists) {
        await _cacheMinimalUserData(snap.data()!, prefs);
      }

      final role = prefs.getString('role');
      if (role == 'member') {
        final email = prefs.getString('userEmail');
        final memberData = await _fetchMemberRecord(email, timeoutMs: 5000);
        if (memberData != null) {
          await _cacheMemberData(memberData, prefs);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      connectivitySub.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Force black background to match native splash
    final backgroundColor = Colors.black;



    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SizedBox(
          key: const ValueKey('lottie'),
          width: 220,
          height: 220,
          child: Lottie.asset(
            'assets/animations/Burn calories.json',
            fit: BoxFit.contain,
            repeat: true,
          ),
        ),
      ),
    );
  }
}
