// lib/core/notifications/firestore_listener.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'package:flutter/foundation.dart';

class FirestoreListener {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _noticesSub;
  StreamSubscription<QuerySnapshot>? _globalChallengesSub;
  StreamSubscription<QuerySnapshot>? _memberNotificationsSub;

  /// Start listening to gym notices and global challenges for this member.
  /// Call this after you know gymId & memberId (e.g., on login).
  Future<void> startForMember({required String gymId, required String memberId}) async {
    try {
      // Listen to gym notices (new notices)
      _noticesSub = _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('notices')
          .where('expiryDate', isGreaterThanOrEqualTo: Timestamp.now())
          .snapshots()
          .listen((snap) {
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() ?? {};
            final title = data['title']?.toString() ?? 'Notice';
            final message = data['message']?.toString() ?? '';
            NotificationService.showLocal(title: title, body: message, payload: '{"type":"notice","id":"${change.doc.id}"}');
          }
        }
      });

      // Listen to global challenges
      _globalChallengesSub = _firestore
          .collection('global_challenges')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen((snap) {
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final d = change.doc.data() ?? {};
            final title = d['title']?.toString() ?? 'Challenge';
            final desc = d['description']?.toString() ?? '';
            NotificationService.showLocal(title: 'New Challenge: $title', body: desc, payload: '{"type":"challenge","id":"${change.doc.id}"}');
          }
        }
      });

      // Optionally listen to member notifications collection (FCM style)
      _memberNotificationsSub = _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(memberId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snap) {
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() ?? {};
            final title = data['title']?.toString() ?? 'Notification';
            final body = data['message']?.toString() ?? '';
            NotificationService.showLocal(title: title, body: body, payload: '{"type":"member_notif","id":"${change.doc.id}"}');
          }
        }
      });
    } catch (e) {
      debugPrint('startForMember error: $e');
    }
  }

  Future<void> stop() async {
    await _noticesSub?.cancel();
    await _globalChallengesSub?.cancel();
    await _memberNotificationsSub?.cancel();
  }
}
