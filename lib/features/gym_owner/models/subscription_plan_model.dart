// features/gym_owner/models/subscription_plan_model.dart
class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final int durationDays;
  final List<String> features;
  final String description;
  final bool isActive;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.durationDays,
    required this.features,
    this.description = '',
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'durationDays': durationDays,
      'features': features,
      'description': description,
      'isActive': isActive,
    };
  }

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map) {
    return SubscriptionPlan(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      durationDays: map['durationDays'] ?? 30,
      features: List<String>.from(map['features'] ?? []),
      description: map['description'] ?? '',
      isActive: map['isActive'] ?? true,
    );
  }
}