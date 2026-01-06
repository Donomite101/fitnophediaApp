import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -------------------------------------------------------------------------
  // LOGIN
  // -------------------------------------------------------------------------
  Future<User?> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userCredential.user!.uid);

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(code: e.code, message: e.message);
    } catch (e) {
      throw Exception('Login failed. Please try again.');
    }
  }

  // -------------------------------------------------------------------------
  // REGISTER (Gym Owner)
  // -------------------------------------------------------------------------
  Future<User?> register(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userCredential.user!.uid)
          .set({
        'email': email,
        'role': AppConstants.roleGymOwner,
        'onboardingCompleted': false,
        'approved': false,
        'subscriptionActive': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userId', userCredential.user!.uid);

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(code: e.code, message: e.message);
    } catch (e) {
      throw Exception('Registration failed. Please try again later.');
    }
  }

  // -------------------------------------------------------------------------
  // CURRENT USER
  // -------------------------------------------------------------------------
  User? getCurrentUser() => _auth.currentUser;

  String? getCurrentUserId() => _auth.currentUser?.uid;

  String? getCurrentUserEmail() => _auth.currentUser?.email;

  bool isLoggedIn() => _auth.currentUser != null;

  // -------------------------------------------------------------------------
  // GET USER DATA (Offline + Online Support)
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      // Try offline cache first
      DocumentSnapshot cachedDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get(const GetOptions(source: Source.cache));

      if (cachedDoc.exists) {
        return cachedDoc.data() as Map<String, dynamic>;
      }

      // Fallback to server (if online)
      DocumentSnapshot serverDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get(const GetOptions(source: Source.server));

      return serverDoc.data() as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // LOGOUT
  // -------------------------------------------------------------------------
  Future<void> logout() async {
    try {
      await _auth.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // CHECK IF USER EXISTS
  // -------------------------------------------------------------------------
  Future<bool> checkUserExists(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // GET USER BY EMAIL
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // UPDATE USER DATA
  // -------------------------------------------------------------------------
  Future<void> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update(data);
    } catch (e) {
      throw Exception('Failed to update user data.');
    }
  }

  // -------------------------------------------------------------------------
  // RESET PASSWORD
  // -------------------------------------------------------------------------
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(code: e.code, message: e.message);
    } catch (_) {
      throw Exception('Failed to send password reset email.');
    }
  }

  // -------------------------------------------------------------------------
  // EMAIL VERIFICATION
  // -------------------------------------------------------------------------
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } catch (_) {
      throw Exception('Failed to send verification email.');
    }
  }

  bool isEmailVerified() => _auth.currentUser?.emailVerified ?? false;
}
