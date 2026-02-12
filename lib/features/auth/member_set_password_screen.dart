// lib/features/member/MemberSetPasswordScreen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_theme.dart';
import '../../routes/app_routes.dart';

class MemberSetPasswordScreen extends StatefulWidget {
  /// Expecting a map with keys:
  /// {
  ///   'data': <member doc data map>,
  ///   'gymId': '<gymId>',
  ///   'memberId': '<memberId>'
  /// }
  final Map<String, dynamic> memberRecord;

  const MemberSetPasswordScreen({Key? key, required this.memberRecord})
      : super(key: key);

  @override
  State<MemberSetPasswordScreen> createState() =>
      _MemberSetPasswordScreenState();
}

class _MemberSetPasswordScreenState extends State<MemberSetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  // -----------------------
  // Error mapping helpers
  // -----------------------
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in instead.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'Choose a stronger password (minimum 6 characters).';
      case 'operation-not-allowed':
        return 'Account creation is disabled. Contact support.';
      case 'network-request-failed':
        return 'No internet connection. Please try again when online.';
      default:
        return 'Could not create account. Please try again.';
    }
  }

  String _mapFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'unavailable':
        return 'Service temporarily unavailable. Try again later.';
      case 'deadline-exceeded':
        return 'Request timed out. Please try again.';
      default:
        return 'A server error occurred. Please try again.';
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  // -----------------------
  // Core flow
  // -----------------------
  Future<void> _createAccount() async {
    final record = widget.memberRecord;
    final data = (record['data'] ?? {}) as Map<String, dynamic>;
    final email = (data['email'] ?? '').toString();
    final name = (data['name'] ?? '').toString();
    final gymId = record['gymId']?.toString();
    final memberId = record['memberId']?.toString();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (email.isEmpty || gymId == null || memberId == null) {
      _showSnack('Invalid member data. Please go back and try again.', AppTheme.alertRed);
      return;
    }

    if (password.isEmpty || confirm.isEmpty) {
      _showSnack('Please fill all fields.', AppTheme.alertRed);
      return;
    }
    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters.', AppTheme.alertRed);
      return;
    }
    if (password != confirm) {
      _showSnack('Passwords do not match.', AppTheme.alertRed);
      return;
    }

    setState(() => _isLoading = true);

    final memberDocRef = FirebaseFirestore.instance
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(memberId);

    try {
      // Check existing activation (fast, with short timeout)
      final memberSnap = await memberDocRef
          .get()
          .timeout(const Duration(seconds: 6), onTimeout: () => throw TimeoutException('Member check timed out'));

      final existingAuthUid = (memberSnap.data()?['authUid'] ?? '').toString();
      if (memberSnap.exists && existingAuthUid.isNotEmpty) {
        _showSnack('Account already activated. Please log in.', AppTheme.fitnessOrange);
        return;
      }

      // Create Firebase Auth user (wrap in timeout to fail fast on network issues)
      UserCredential cred;
      try {
        cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password)
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        throw SocketException('Network timeout');
      }

      final user = cred.user;
      if (user == null) throw Exception('User creation failed');

      // Update member doc with authUid and status — best-effort server timestamp
      await memberDocRef.update({
        'authUid': user.uid,
        'status': 'active',
        'activatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 6));

      // Create central users collection entry (overwrite or set)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': email,
        'name': name,
        'role': 'member',
        'gymId': gymId,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 6));

      // Cache data for auto-login
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('role', 'member');
        await prefs.setString('gymId', gymId);
        await prefs.setString('memberId', memberId);
        await prefs.setString('userEmail', email);
        await prefs.setString('userName', name);
      } catch (e) {
        debugPrint('Error caching member data: $e');
      }

      // Re-fetch member from server to read subscription status (best-effort)
      bool hasSub = false;
      try {
        final updated = await memberDocRef.get(const GetOptions(source: Source.server)).timeout(const Duration(seconds: 6));
        hasSub = (updated.data()?['hasOngoingSubscription'] ?? false) == true;
      } catch (_) {
        // ignore — fall back to false
      }

      // Success — show dialog then route
      if (!mounted) return;
      await _showSuccessDialog(hasSub, gymId, memberId, email, name);
    } on FirebaseAuthException catch (e) {
      final msg = _mapAuthError(e);
      debugPrint('Auth error creating member user: ${e.code} - ${e.message}');
      _showSnack(msg, AppTheme.alertRed);
    } on FirebaseException catch (e) {
      final msg = _mapFirestoreError(e);
      debugPrint('Firestore error in member activation: ${e.code} - ${e.message}');
      _showSnack(msg, AppTheme.alertRed);
    } on SocketException {
      _showSnack('Network error. Please check your connection and try again.', AppTheme.alertRed);
    } on TimeoutException {
      _showSnack('Request timed out. Please check your network and try again.', AppTheme.alertRed);
    } catch (e, st) {
      debugPrint('Unexpected error in MemberSetPassword: $e\n$st');
      _showSnack('Something went wrong. Please try again.', AppTheme.alertRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -----------------------
  // Success UI & routing
  // -----------------------
  Future<void> _showSuccessDialog(
      bool hasSub, String gymId, String memberId, String email, String name) async {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 70),
            const SizedBox(height: 20),
            Text(
              "Account Activated!",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Your Fitnophedia member account has been activated successfully.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 25),
            const SizedBox(height: 10),
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            const SizedBox(height: 10),
            Text(
              "Redirecting...",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          ]),
        ),
      ),
    );

    // Delay briefly to show success UX then navigate (ensure still mounted)
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    Navigator.pop(context); // close dialog

    // Navigate to profile setup (clear stack)
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.memberProfileSetup,
          (route) => false,
      arguments: {
        'gymId': gymId,
        'memberId': memberId,
        'email': email,
        'name': name,
        'hasOngoingSubscription': hasSub,
      },
    );
  }

  // -----------------------
  // Build
  // -----------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = widget.memberRecord;
    final member = (record['data'] ?? {}) as Map<String, dynamic>;
    final name = (member['name'] ?? 'Member').toString();
    final email = (member['email'] ?? '').toString();

    if (record['gymId'] == null || record['memberId'] == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'Invalid member data. Please go back and try again.',
              style: TextStyle(color: AppTheme.alertRed, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Activate Your Account',
          style: TextStyle(
            color: theme.appBarTheme.foregroundColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.appBarTheme.foregroundColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                height: 180,
                child: Image.asset(
                  'assets/set_password.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.lock_outline_rounded, color: AppTheme.primaryGreen, size: 60),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome, $name',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(email.isNotEmpty ? 'Email: $email' : 'No email found', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 14)),
              const SizedBox(height: 12),
              Text('Create your password to activate your Fitnophedia account.', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontSize: 15)),
              const SizedBox(height: 30),

              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.lock, color: AppTheme.primaryGreen),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: theme.cardColor,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscure,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryGreen),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: theme.cardColor,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Activate Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Back to Login', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600, fontSize: 15))),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
