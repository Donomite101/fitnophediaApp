import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  final String id;
  final String name;
  final String email;
  final String status;
  final DateTime? joinDate;
  final DateTime? expiryDate;

  Member({
    required this.id,
    required this.name,
    required this.email,
    required this.status,
    this.joinDate,
    this.expiryDate,
  });

  factory Member.fromMap(String id, Map<String, dynamic> data) {
    return Member(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      status: data['status'] ?? 'pending',
      joinDate: (data['joinDate'] as Timestamp?)?.toDate(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'status': status,
      'joinDate': joinDate,
      'expiryDate': expiryDate,
    };
  }
}
