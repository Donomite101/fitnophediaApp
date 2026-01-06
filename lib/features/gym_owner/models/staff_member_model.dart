import 'package:cloud_firestore/cloud_firestore.dart';

class StaffMember {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String status;
  String? photoUrl;

  // Employment details
  double? salary;
  Timestamp? joinDate;           // ← Timestamp, not DateTime
  Timestamp? leaveDate;
  List<String> workingDays;
  String? shiftTiming;

  // Trainer-specific
  String? specialization;
  int assignedMembersCount;
  List<String> certifications;

  // Permissions
  List<String> permissions;

  // Leave & attendance
  int totalLeaveDays;
  int usedLeaveDays;
  Timestamp? lastAttendanceDate;

  // Performance
  double? performanceRating;
  int totalSessionsConducted;

  // Notes & timestamps
  String? notes;
  Timestamp? createdAt;
  Timestamp? updatedAt;

  StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    this.photoUrl,
    this.salary,
    this.joinDate,
    this.leaveDate,
    this.workingDays = const [],
    this.shiftTiming,
    this.specialization,
    this.assignedMembersCount = 0,
    this.certifications = const [],
    this.permissions = const [],
    this.totalLeaveDays = 15,
    this.usedLeaveDays = 0,
    this.lastAttendanceDate,
    this.performanceRating,
    this.totalSessionsConducted = 0,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  // --- From Firestore ---
  factory StaffMember.fromFirestore(String id, Map<String, dynamic> data) {
    return StaffMember(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'staff',
      status: data['status'] ?? 'active',
      photoUrl: data['photoUrl'],
      salary: (data['salary'] as num?)?.toDouble(),
      joinDate: data['joinDate'] as Timestamp?,
      leaveDate: data['leaveDate'] as Timestamp?,
      workingDays: List<String>.from(data['workingDays'] ?? []),
      shiftTiming: data['shiftTiming'],
      specialization: data['specialization'],
      assignedMembersCount: data['assignedMembersCount'] ?? 0,
      certifications: List<String>.from(data['certifications'] ?? []),
      permissions: List<String>.from(data['permissions'] ?? []),
      totalLeaveDays: data['totalLeaveDays'] ?? 15,
      usedLeaveDays: data['usedLeaveDays'] ?? 0,
      lastAttendanceDate: data['lastAttendanceDate'] as Timestamp?,
      performanceRating: (data['performanceRating'] as num?)?.toDouble(),
      totalSessionsConducted: data['totalSessionsConducted'] ?? 0,
      notes: data['notes'],
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  // --- To Firestore ---
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'status': status,
      'photoUrl': photoUrl,
      'salary': salary,
      'joinDate': joinDate,
      'leaveDate': leaveDate,
      'workingDays': workingDays,
      'shiftTiming': shiftTiming,
      'specialization': specialization,
      'assignedMembersCount': assignedMembersCount,
      'certifications': certifications,
      'permissions': permissions,
      'totalLeaveDays': totalLeaveDays,
      'usedLeaveDays': usedLeaveDays,
      'lastAttendanceDate': lastAttendanceDate,
      'performanceRating': performanceRating,
      'totalSessionsConducted': totalSessionsConducted,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Helper: formatted join date (safe to use in UI)
  String get formattedJoinDate {
    if (joinDate == null) return 'Not set';
    final date = joinDate!.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  // You can add more formatters if needed
  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '—';
    final d = timestamp.toDate();
    return '${d.day}/${d.month}/${d.year}';
  }

  // copyWith stays the same (just change DateTime → Timestamp)
  StaffMember copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? status,
    String? photoUrl,
    double? salary,
    Timestamp? joinDate,
    Timestamp? leaveDate,
    List<String>? workingDays,
    String? shiftTiming,
    String? specialization,
    int? assignedMembersCount,
    List<String>? certifications,
    List<String>? permissions,
    int? totalLeaveDays,
    int? usedLeaveDays,
    Timestamp? lastAttendanceDate,
    double? performanceRating,
    int? totalSessionsConducted,
    String? notes,
  }) {
    return StaffMember(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      photoUrl: photoUrl ?? this.photoUrl,
      salary: salary ?? this.salary,
      joinDate: joinDate ?? this.joinDate,
      leaveDate: leaveDate ?? this.leaveDate,
      workingDays: workingDays ?? this.workingDays,
      shiftTiming: shiftTiming ?? this.shiftTiming,
      specialization: specialization ?? this.specialization,
      assignedMembersCount: assignedMembersCount ?? this.assignedMembersCount,
      certifications: certifications ?? this.certifications,
      permissions: permissions ?? this.permissions,
      totalLeaveDays: totalLeaveDays ?? this.totalLeaveDays,
      usedLeaveDays: usedLeaveDays ?? this.usedLeaveDays,
      lastAttendanceDate: lastAttendanceDate ?? this.lastAttendanceDate,
      performanceRating: performanceRating ?? this.performanceRating,
      totalSessionsConducted: totalSessionsConducted ?? this.totalSessionsConducted,
      notes: notes ?? this.notes,
    );
  }
}