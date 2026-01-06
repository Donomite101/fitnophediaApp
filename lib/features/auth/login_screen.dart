// lib/features/auth/login_screen.dart
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscure = true;

  // Green theme (fitness influenced)
  static const Color lightPrimaryGreen = Color(0xFF2ECC71); // friendly fitness green
  static const Color darkPrimaryGreen = Color(0xFF00E676); // bright green for dark mode

  // ---------------------------------------------------------------------------
  // ERROR MAPPING HELPERS
  // ---------------------------------------------------------------------------

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      default:
        return 'Unable to sign in. Please try again.';
    }
  }

  String _getFirestoreErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to access this account.';
      case 'unavailable':
        return 'Server is unavailable. Please check your internet and try again.';
      case 'deadline-exceeded':
        return 'Request took too long. Please try again.';
      default:
        return 'Could not load your account details. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------------------

  Future<void> _login() async {
    // keep logic unchanged, but guard against null form
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnack('Please fill required fields', AppTheme.alertRed);
      return;
    }

    // Hide keyboard for a cleaner UX
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.login(email, password);

      if (user == null) {
        _showSnack('Login failed. Please try again.', AppTheme.alertRed);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('uid', user.uid);

      // User profile / member lookup (kept same logic, better error handling)
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 5));

        if (userDoc.exists) {
          _redirectUser(userDoc.data()!);
          return;
        }

        final memberSnapshot = await FirebaseFirestore.instance
            .collectionGroup('members')
            .where('email', isEqualTo: email)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 5));

        if (memberSnapshot.docs.isNotEmpty) {
          final doc = memberSnapshot.docs.first;
          final gymId = doc.reference.parent.parent?.id;
          _redirectMember(gymId, doc.id, doc.data());
        } else {
          _showSnack('User not found. Please contact support.', AppTheme.alertRed);
        }
      } on FirebaseException catch (e) {
        debugPrint('Firestore login flow error: ${e.code} / ${e.message}');
        final msg = _getFirestoreErrorMessage(e);
        _showSnack(msg, AppTheme.alertRed);
      } on SocketException {
        _showSnack('No internet connection. Please check your network.', AppTheme.alertRed);
      } on TimeoutException {
        _showSnack('Unable to contact server. Please try again.', AppTheme.alertRed);
      }
    } on FirebaseAuthException catch (e) {
      final msg = _getAuthErrorMessage(e);
      _showSnack(msg, AppTheme.alertRed);
    } on SocketException {
      _showSnack('No internet connection. Please check your network.', AppTheme.alertRed);
    } on TimeoutException {
      _showSnack('Request timed out. Please try again.', AppTheme.alertRed);
    } catch (e, st) {
      debugPrint('Login unexpected error: $e\n$st');
      _showSnack('Something went wrong. Please try again.', AppTheme.alertRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // REDIRECT BASED ON ROLE (UNCHANGED LOGIC)
  // ---------------------------------------------------------------------------

  void _redirectUser(Map<String, dynamic> data) async {
    if (!mounted) return;

    final role = data['role'] ?? '';
    switch (role) {
      case 'superadmin':
        Navigator.pushReplacementNamed(context, AppRoutes.superAdminDashboard);
        break;

      case 'gym_owner':
        final o = data['onboardingCompleted'] ?? false;
        final a = data['approved'] ?? false;

        // Check subscription status and expiration
        bool s = data['subscriptionActive'] ?? false;

        // If subscription is marked as active, check if it's actually expired
        if (s) {
          final subscriptionEndDate = data['subscriptionEndDate'] as Timestamp?;
          if (subscriptionEndDate != null) {
            final now = DateTime.now();
            final endDate = subscriptionEndDate.toDate();

            // If subscription has expired, update it to false
            if (now.isAfter(endDate)) {
              s = false;

              // Update in Firestore (best effort)
              try {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  // Update user document
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .update({'subscriptionActive': false});

                  // Find and update gym document
                  final gymSnap = await FirebaseFirestore.instance
                      .collection('gyms')
                      .where('ownerId', isEqualTo: uid)
                      .limit(1)
                      .get();

                  if (gymSnap.docs.isNotEmpty) {
                    await FirebaseFirestore.instance
                        .collection('gyms')
                        .doc(gymSnap.docs.first.id)
                        .update({'subscriptionActive': false});
                  }

                  // Update app_subscriptions
                  await FirebaseFirestore.instance
                      .collection('app_subscriptions')
                      .doc(uid)
                      .update({'status': 'expired'});
                }
              } catch (e, st) {
                debugPrint('Error updating subscription status: $e\n$st');
              }
            }
          }
        }

        if (!o) {
          Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
        } else if (!a) {
          Navigator.pushReplacementNamed(context, AppRoutes.approvalWaiting);
        } else if (!s) {
          Navigator.pushReplacementNamed(context, AppRoutes.subscriptionPlans);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.gymOwnerDashboard);
        }
        break;

      case 'member':
        Navigator.pushReplacementNamed(context, AppRoutes.memberDashboard);
        break;

      default:
        _showSnack('Unknown role. Please contact support.', AppTheme.alertRed);
    }
  }

  // put inside _LoginScreenState

  Future<void> _redirectMember(
      String? gymId, String memberId, Map<String, dynamic> data) async {
    // 1) Basic flags
    final hasProfile = data['profileCompleted'] == true;
    bool hasSubscription = (data['hasOngoingSubscription'] ?? false) == true;

    // 2) Try to extract subscription plan info (for prefill)
    final planName = (data['subscriptionPlan'] as String?) ??
        (data['planName'] as String?) ??
        null;
    final subscriptionPrice = (data['subscriptionPrice'] is num)
        ? (data['subscriptionPrice'] as num).toDouble()
        : (data['subscriptionPrice'] != null
        ? double.tryParse('${data['subscriptionPrice']}')
        : null);

    // 3) Parse subscriptionEndDate (supports Timestamp, String, DateTime)
    DateTime? subscriptionEnd;
    final rawEnd = data['subscriptionEndDate'];
    try {
      if (rawEnd != null) {
        if (rawEnd is Timestamp) {
          subscriptionEnd = rawEnd.toDate();
        } else if (rawEnd is DateTime) {
          subscriptionEnd = rawEnd;
        } else if (rawEnd is String) {
          subscriptionEnd = DateTime.tryParse(rawEnd);
        }
      }
    } catch (e) {
      subscriptionEnd = null;
    }

    final now = DateTime.now();
    final isExpired = subscriptionEnd != null && now.isAfter(subscriptionEnd);

    // If subscription is expired but member still flagged as active, update Firestore (best-effort)
    if (isExpired && hasSubscription && gymId != null) {
      hasSubscription = false;
      try {
        await FirebaseFirestore.instance
            .collection('gyms')
            .doc(gymId)
            .collection('members')
            .doc(memberId)
            .update({
          'hasOngoingSubscription': false,
          'subscriptionStatus': 'expired',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e, st) {
        debugPrint('Warning: failed to mark member expired: $e\n$st');
        // Not fatal — still proceed with redirect logic
      }
    }

    // Build common args passed to member screens
    final baseArgs = {
      'gymId': gymId,
      'memberId': memberId,
      'memberEmail': data['email'] ?? '',
      'memberName': data['name'] ?? data['memberName'] ?? '',
    };

    // 4) If profile incomplete -> profile setup (highest priority)
    if (!hasProfile) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.memberProfileSetup,
        arguments: baseArgs,
      );
      return;
    }

    // 5) If expired -> go to subscription with optional prefill
    if (isExpired) {
      final argsWithPrefill = Map<String, dynamic>.from(baseArgs);
      if (planName != null) argsWithPrefill['prefillPlanName'] = planName;
      if (subscriptionPrice != null) {
        argsWithPrefill['prefillPrice'] = subscriptionPrice;
      }
      argsWithPrefill['expired'] = true;

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.memberSubscription,
        arguments: argsWithPrefill,
      );
      return;
    }

    // 6) If no active subscription -> subscription screen
    if (!hasSubscription) {
      if (!mounted) return;
      final argsWithPrefill = Map<String, dynamic>.from(baseArgs);
      if (planName != null) argsWithPrefill['prefillPlanName'] = planName;
      if (subscriptionPrice != null) {
        argsWithPrefill['prefillPrice'] = subscriptionPrice;
      }
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.memberSubscription,
        arguments: argsWithPrefill,
      );
      return;
    }

    // 7) All good -> dashboard
    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.memberDashboard,
      arguments: baseArgs,
    );
  }

  Future<bool> _showSubscriptionExpiredDialog(
      DateTime? expiry, {
        String? planName,
        double? price,
      }) async {
    if (!mounted) return false;

    final formattedExpiry =
    expiry != null ? DateFormat.yMMMMd().add_jm().format(expiry) : null;
    final priceText =
    (price != null) ? '• Price: ₹${price.toStringAsFixed(0)}\n' : '';
    final planText = (planName != null) ? '• Plan: $planName\n' : '';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Subscription Expired'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your subscription has expired.'),
              const SizedBox(height: 8),
              if (formattedExpiry != null)
                Text(
                  'Expired on: $formattedExpiry',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (formattedExpiry == null) const SizedBox.shrink(),
              const SizedBox(height: 10),
              if (planName != null || price != null)
                Text(
                  'Details:\n$planText$priceText',
                  style: const TextStyle(color: Colors.black87),
                ),
              const SizedBox(height: 8),
              const Text(
                  'Please renew to continue accessing member features.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Renew now'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS
  // ---------------------------------------------------------------------------

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Reset Password',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'email@example.com',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
              BorderSide(color: _currentPrimaryColor(context), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentPrimaryColor(context),
            ),
            onPressed: () async {
              final email = ctrl.text.trim();
              if (!email.contains('@')) {
                _showSnack('Enter a valid email address.', AppTheme.alertRed);
                return;
              }
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                Navigator.pop(context);
                _showSnack(
                  'Password reset link sent to your email.',
                  _currentPrimaryColor(context),
                );
              } on FirebaseAuthException catch (e) {
                final msg = _getAuthErrorMessage(e);
                _showSnack(msg, AppTheme.alertRed);
              } on SocketException {
                _showSnack(
                    'No internet connection. Please check your network.',
                    AppTheme.alertRed);
              } catch (e, st) {
                debugPrint('Reset password error: $e\n$st');
                _showSnack(
                    'Unable to send reset link. Please try again.',
                    AppTheme.alertRed);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  // helper to pick primary green depending on system theme
  static Color _currentPrimaryColor(BuildContext context) {
    final Brightness b = MediaQuery.of(context).platformBrightness;
    return b == Brightness.dark ? darkPrimaryGreen : lightPrimaryGreen;
  }

  // helper to pick background color
  static Color _currentBackgroundColor(BuildContext context) {
    final Brightness b = MediaQuery.of(context).platformBrightness;
    return b == Brightness.dark ? Colors.black : Colors.white;
  }

  // input container styling — subtle in both modes
  Widget _buildInputContainer({
    required Widget child,
    required BuildContext context,
  }) {
    final isDark =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.6)
                : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.grey.withOpacity(0.12),
        ),
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final waveHeight = size.height * 0.25; // currently unused, kept for future
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? darkPrimaryGreen : lightPrimaryGreen;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[700];
    final bg = _currentBackgroundColor(context);

    return Scaffold(
      backgroundColor: bg,
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 28,
            right: 28,
            top: 20,
            bottom: bottomInset + 20,
          ),
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),

              // big top logo (uploaded file)
              // Logo section
              SizedBox(
                height: 170,
                child: Image.asset(
                  isDark
                      ? 'assets/login_logo.png'
                      : 'assets/loginblack_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                'Login to Your Account',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue managing your gym',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: subtitleColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),

              // FORM START
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email field container
                    _buildInputContainer(
                      context: context,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  if (value.isEmpty) {
                                    return 'Required';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Enter valid email';
                                  }
                                  return null;
                                },
                                style: GoogleFonts.poppins(
                                  color: textColor,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  hintText: 'Email',
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey.shade500,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Password field container
                    _buildInputContainer(
                      context: context,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: _obscure,
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  if (value.isEmpty) {
                                    return 'Required';
                                  }
                                  if (value.length < 6) {
                                    return 'Minimum 6 characters';
                                  }
                                  return null;
                                },
                                style: GoogleFonts.poppins(
                                  color: textColor,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                  const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  hintText: 'Password',
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey.shade500,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _obscure = !_obscure),
                              child: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Remember + Forgot row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (v) => setState(
                                      () => _rememberMe = v ?? false),
                              activeColor: primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Remember me',
                              style: GoogleFonts.poppins(
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.poppins(
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Sign in button — big rounded green
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          shadowColor:
                          primary.withOpacity(0.35),
                        ),
                        child: Text(
                          'Sign in',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Sign up text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: GoogleFonts.poppins(
                            color: subtitleColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.register,
                          ),
                          child: Text(
                            'Sign up',
                            style: GoogleFonts.poppins(
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ), // FORM END
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// kept clipper for reuse (unused)
class _GreenWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.60);
    path.cubicTo(
      size.width * 0.15,
      size.height * 0.90,
      size.width * 0.35,
      size.height * 0.50,
      size.width * 0.55,
      size.height * 0.60,
    );
    path.cubicTo(
      size.width * 0.75,
      size.height * 0.70,
      size.width * 0.9,
      size.height * 0.90,
      size.width,
      size.height * 0.78,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_) => false;
}
