class Subscription {
  final String id;
  final String userId;
  final String name;
  final double amount;
  final String billingCycle; // 'Monthly', 'Yearly', 'Weekly'
  final DateTime nextBillDate;
  final String category;
  final String wallet;
  final bool autoAdd; // If true, automatically generates expense
  final DateTime createdAt;

  Subscription({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.billingCycle,
    required this.nextBillDate,
    required this.category,
    this.wallet = 'Cash',
    this.autoAdd = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      name: map['name'].toString(),
      amount: (map['amount'] as num).toDouble(),
      billingCycle: map['billing_cycle'].toString(),
      nextBillDate: DateTime.parse(map['next_bill_date'].toString()),
      category: map['category'].toString(),
      wallet: map['wallet']?.toString() ?? 'Cash',
      autoAdd: map['auto_add'] ?? true,
      createdAt: DateTime.parse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'user_id': userId,
      'name': name,
      'amount': amount,
      'billing_cycle': billingCycle,
      'next_bill_date': nextBillDate.toIso8601String(),
      'category': category,
      'wallet': wallet,
      'auto_add': autoAdd,
    };
  }

  Subscription copyWith({
    String? id,
    String? userId,
    String? name,
    double? amount,
    String? billingCycle,
    DateTime? nextBillDate,
    String? category,
    String? wallet,
    bool? autoAdd,
    DateTime? createdAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      billingCycle: billingCycle ?? this.billingCycle,
      nextBillDate: nextBillDate ?? this.nextBillDate,
      category: category ?? this.category,
      wallet: wallet ?? this.wallet,
      autoAdd: autoAdd ?? this.autoAdd,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
