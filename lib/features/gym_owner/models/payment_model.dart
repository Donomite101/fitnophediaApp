// features/gym_owner/models/payment_model.dart
class Payment {
  final String id;
  final String memberId;
  final String memberName;
  final String subscriptionPlan;
  final double amount;
  final DateTime paymentDate;
  final DateTime dueDate;
  final String status; // 'paid', 'pending', 'overdue'
  final String paymentMethod; // 'card', 'cash', 'paypal'
  final String? transactionId;

  Payment({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.subscriptionPlan,
    required this.amount,
    required this.paymentDate,
    required this.dueDate,
    required this.status,
    required this.paymentMethod,
    this.transactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'memberId': memberId,
      'memberName': memberName,
      'subscriptionPlan': subscriptionPlan,
      'amount': amount,
      'paymentDate': paymentDate.millisecondsSinceEpoch,
      'dueDate': dueDate.millisecondsSinceEpoch,
      'status': status,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] ?? '',
      memberId: map['memberId'] ?? '',
      memberName: map['memberName'] ?? '',
      subscriptionPlan: map['subscriptionPlan'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paymentDate: DateTime.fromMillisecondsSinceEpoch(map['paymentDate']),
      dueDate: DateTime.fromMillisecondsSinceEpoch(map['dueDate']),
      status: map['status'] ?? 'pending',
      paymentMethod: map['paymentMethod'] ?? '',
      transactionId: map['transactionId'],
    );
  }
}

class RevenueStats {
  final double totalRevenue;
  final double monthlyRevenue;
  final double pendingPayments;
  final int paidMembers;
  final int pendingMembers;

  RevenueStats({
    required this.totalRevenue,
    required this.monthlyRevenue,
    required this.pendingPayments,
    required this.paidMembers,
    required this.pendingMembers,
  });
}