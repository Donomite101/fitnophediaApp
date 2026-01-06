import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GymDataService {
  static final GymDataService _instance = GymDataService._internal();
  factory GymDataService() => _instance;
  GymDataService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? gymStream;

  void initializeGymListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    gymStream = _firestore
        .collection('gyms')
        .where('ownerId', isEqualTo: user.uid)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.first);
  }
}
