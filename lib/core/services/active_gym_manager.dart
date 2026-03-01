import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActiveGymManager {
  static const String _key = 'active_gym_id';

  static Future<String?> getActiveGymId() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedGymId = prefs.getString(_key);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    if (storedGymId != null && storedGymId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('gyms').doc(storedGymId).get();
        if (doc.exists && doc.data()?['ownerId'] == user.uid) {
          return storedGymId;
        }
      } catch (e) {
        // Fallback
      }
    }

    // Default fallback to the first gym owned
    final gyms = await FirebaseFirestore.instance
        .collection('gyms')
        .where('ownerId', isEqualTo: user.uid)
        .limit(1)
        .get();
        
    if (gyms.docs.isNotEmpty) {
      await setActiveGymId(gyms.docs.first.id);
      return gyms.docs.first.id;
    }
    return null;
  }

  static Future<void> setActiveGymId(String gymId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, gymId);
  }
}
