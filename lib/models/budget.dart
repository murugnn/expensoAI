class Budget {
  final String id;
  final String userId;
  final double amount;
  final DateTime month;
  final DateTime createdAt;
  final DateTime updatedAt;

  Budget({
    required this.id,
    required this.userId,
    required this.amount,
    required this.month,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'month': DateTime(month.year, month.month, 1).toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Budget.fromSupabase(Map<String, dynamic> json) {
    return Budget(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      amount: (json['amount'] as num).toDouble(),
      month: DateTime.parse(json['month'].toString()),
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}
