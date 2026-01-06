import 'package:flutter/material.dart';

enum BadgeType {
  streak,           // Based on current streak
  longestStreak,    // Based on longest streak
  totalWorkouts,    // Based on total workouts
  weeklyWorkouts,   // Based on weekly workouts
  monthAttendance,  // Based on monthly attendance
}

class BadgeCriteria {
  final BadgeType type;
  final int threshold;
  final String? subType;

  BadgeCriteria({
    required this.type,
    required this.threshold,
    this.subType,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'threshold': threshold,
      'subType': subType,
    };
  }

  factory BadgeCriteria.fromMap(Map<String, dynamic> map) {
    return BadgeCriteria(
      type: BadgeType.values.firstWhere(
            (e) => e.name == map['type'],
        orElse: () => BadgeType.streak,
      ),
      threshold: map['threshold'] ?? 0,
      subType: map['subType'],
    );
  }
}

class BadgeModel {
  final String icon;
  final String title;
  final String description;
  final Color color;
  bool unlocked;
  final String category;
  final bool isNew;
  final DateTime? unlockedAt;

  // Achievement criteria
  final BadgeCriteria criteria;

  BadgeModel({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.unlocked,
    required this.category,
    required this.criteria,
    this.isNew = false,
    this.unlockedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'icon': icon,
      'title': title,
      'description': description,
      'color': color.value,
      'unlocked': unlocked,
      'category': category,
      'isNew': isNew,
      'unlockedAt': unlockedAt?.toIso8601String(),
      'criteria': criteria.toMap(),
    };
  }

  factory BadgeModel.fromMap(Map<String, dynamic> map) {
    return BadgeModel(
      icon: map['icon'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      color: Color(map['color'] ?? 0xFF000000),
      unlocked: map['unlocked'] ?? false,
      category: map['category'] ?? 'Featured',
      isNew: map['isNew'] ?? false,
      unlockedAt: map['unlockedAt'] != null ? DateTime.parse(map['unlockedAt']) : null,
      criteria: BadgeCriteria.fromMap(Map<String, dynamic>.from(map['criteria'] ?? {})),
    );
  }

  BadgeModel copyWith({
    String? icon,
    String? title,
    String? description,
    Color? color,
    bool? unlocked,
    String? category,
    bool? isNew,
    DateTime? unlockedAt,
    BadgeCriteria? criteria,
  }) {
    return BadgeModel(
      icon: icon ?? this.icon,
      title: title ?? this.title,
      description: description ?? this.description,
      color: color ?? this.color,
      unlocked: unlocked ?? this.unlocked,
      category: category ?? this.category,
      isNew: isNew ?? this.isNew,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      criteria: criteria ?? this.criteria,
    );
  }
}