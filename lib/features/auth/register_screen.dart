// lib/features/auth/register_screen.dart
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/auth_service.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../routes/app_routes.dart';
import '../../core/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isOwner = true; // Toggle between Owner & Member
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Theme colors
  static const Color _primaryGreen = Color(0xFF2ECC71);
  static const Color _primaryDark = Color(0xFF1E8E4D);
  static const Color _softBackground = Color(0xFFF6FFFA);
  static const Color _darkPrimaryGreen = Color(0xFF00E676);

  // ---------------------------
  // Error mapping helpers
  // ---------------------------
  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please login or use a different email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Contact support.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Registration failed. Please try again.';
    }
  }

  String _getFirestoreErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to access requested data.';
      case 'unavailable':
        return 'Service unavailable. Please check your connection and try again.';
      case 'deadline-exceeded':
        return 'Request timed out. Please try again.';
      default:
        return 'A server error occurred. Please try again.';
    }
  }

  // ---------------------------
  // Registration flows
  // ---------------------------

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (_isOwner) {
      await _registerOwner();
    } else {
      await _activateMember();
    }
  }

  Future<void> _registerOwner() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    if (password != confirm) {
      _showSnack('Passwords do not match', AppTheme.alertRed);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.register(
        _emailController.text.trim(),
        password,
      );

      if (user != null) {
        // Save quick flag locally (so splash/other flows can use it)
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userId', user.uid);
        } catch (_) {
          // Not fatal — proceed with navigation
        }

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
        return;
      } else {
        _showSnack('Registration failed. Please try again.', AppTheme.alertRed);
      }
    } on FirebaseAuthException catch (e) {
      final msg = _getAuthErrorMessage(e);
      _showSnack(msg, AppTheme.alertRed);
    } on SocketException {
      _showSnack('No internet connection. Please check your network.', AppTheme.alertRed);
    } on TimeoutException {
      _showSnack('Request timed out. Please try again.', AppTheme.alertRed);
    } catch (e, st) {
      debugPrint('Unexpected registration error: $e\n$st');
      _showSnack('Unable to register. Please try again.', AppTheme.alertRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Member activation: look up the member record and route to member set-password screen.
  /// Behaves robustly when offline or when Firestore returns errors.
  Future<void> _activateMember() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Enter a valid member email', AppTheme.alertRed);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Add a short timeout so the UI doesn't hang if Firestore is slow/offline.
      final query = FirebaseFirestore.instance
          .collectionGroup('members')
          .where('email', isEqualTo: email)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));

      final snapshot = await query;

      if (snapshot.docs.isEmpty) {
        _showSnack('No member found with this email. Ask your gym owner to invite you.', AppTheme.alertRed);
        return;
      }

      final memberDoc = snapshot.docs.first;
      final memberData = memberDoc.data();
      final gymId = memberDoc.reference.parent.parent?.id;

      final authUid = (memberData['authUid'] ?? '').toString();

      if (authUid.isEmpty) {
        // route to set password screen (keeps existing behavior)
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          AppRoutes.memberSetPassword,
          arguments: {
            'gymId': gymId,
            'memberId': memberDoc.id,
            'data': memberData,
          },
        );
        return;
      } else {
        // Member already active
        _showSnack('This member account is already active. Please sign in.', AppTheme.fitnessOrange);
        return;
      }
    } on FirebaseException catch (e) {
      debugPrint('Firestore member lookup error: ${e.code} / ${e.message}');
      final msg = _getFirestoreErrorMessage(e);
      _showSnack(msg, AppTheme.alertRed);
    } on SocketException {
      _showSnack('No internet connection. Please check your network and try again.', AppTheme.alertRed);
    } on TimeoutException {
      _showSnack('Server timeout. Please try again in a moment.', AppTheme.alertRed);
    } catch (e, st) {
      debugPrint('Unexpected member activation error: $e\n$st');
      _showSnack('An error occurred while checking member. Try again.', AppTheme.alertRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------
  // UI helpers
  // ---------------------------

  Color _currentPrimaryColor(BuildContext context) {
    final Brightness b = MediaQuery.of(context).platformBrightness;
    return b == Brightness.dark ? _darkPrimaryGreen : _primaryGreen;
  }

  Color _currentBackgroundColor(BuildContext context) {
    final Brightness b = MediaQuery.of(context).platformBrightness;
    return b == Brightness.dark ? Colors.black : _softBackground;
  }

  Widget _buildInputContainer({required Widget child, required BuildContext context}) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.12)),
      ),
      child: child,
    );
  }

  Widget _roleButton(String title, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? _primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------------------
  // Build
  // ---------------------------

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final primary = _currentPrimaryColor(context);
    final titleColor = isDark ? Colors.white : _primaryDark;
    final subtitleColor = isDark ? Colors.white60 : _primaryDark.withOpacity(0.8);
    final bg = _currentBackgroundColor(context);

    return Scaffold(
      backgroundColor: bg,
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(left: 28, right: 28, top: 20, bottom: bottomInset + 20),
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),

              // top logo (kept same as login)
              SizedBox(
                height: 45,
                child: Image.file(
                  File('/mnt/data/9e48f179-aa83-4111-852d-456e03255cd8.png'),
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),

              // small logo
              SizedBox(
                height: 130,
                child: Image.asset(
                  isDark ? 'assets/login_logo.png' : 'assets/loginblack_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                'Create Account',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: titleColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Join Fitnophedia today',
                style: GoogleFonts.poppins(fontSize: 13, color: subtitleColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildInputContainer(
                      context: context,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            _roleButton('Owner', _isOwner, () => setState(() => _isOwner = true)),
                            const SizedBox(width: 8),
                            _roleButton('Member', !_isOwner, () => setState(() => _isOwner = false)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildInputContainer(
                      context: context,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            Icon(Icons.email_outlined, color: isDark ? Colors.white54 : Colors.grey),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  final text = v?.trim() ?? '';
                                  if (text.isEmpty) return 'Required';
                                  if (!text.contains('@')) return 'Enter a valid email';
                                  return null;
                                },
                                style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black87),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                  hintText: 'Email',
                                  hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    if (_isOwner) ...[
                      _buildInputContainer(
                        context: context,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline, color: isDark ? Colors.white54 : Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  validator: (v) {
                                    final text = v?.trim() ?? '';
                                    if (text.isEmpty) return 'Required';
                                    if (text.length < 6) return 'Minimum 6 characters';
                                    return null;
                                  },
                                  style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black87),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                    hintText: 'Password',
                                    hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                child: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: isDark ? Colors.white54 : Colors.grey),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      _buildInputContainer(
                        context: context,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              Icon(Icons.lock_outline, color: isDark ? Colors.white54 : Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirm,
                                  validator: (v) {
                                    final text = v?.trim() ?? '';
                                    if (text.isEmpty) return 'Required';
                                    return null;
                                  },
                                  style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black87),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                    hintText: 'Confirm Password',
                                    hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                child: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: isDark ? Colors.white54 : Colors.grey),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          shadowColor: primary.withOpacity(0.35),
                        ),
                        child: Text(
                          _isOwner ? 'Create Account' : 'Activate Account',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.black : Colors.white),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Already have an account? ", style: GoogleFonts.poppins(color: subtitleColor)),
                        GestureDetector(
                          onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                          child: Text('Sign In', style: GoogleFonts.poppins(color: primary, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
