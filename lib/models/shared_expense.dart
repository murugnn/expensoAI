/// A bill / transaction recorded inside a [SharedRoom].
enum SharedSplitType { equal, custom, percentage }

class SharedExpenseSplit {
  final String id;
  final String expenseId;
  final String userId;
  final double owedAmount;
  final bool isSettled;

  const SharedExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.owedAmount,
    this.isSettled = false,
  });

  factory SharedExpenseSplit.fromJson(Map<String, dynamic> json) =>
      SharedExpenseSplit(
        id: json['id'],
        expenseId: json['expenseId'],
        userId: json['userId'],
        owedAmount: (json['owedAmount'] as num).toDouble(),
        isSettled: json['isSettled'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'expenseId': expenseId,
        'userId': userId,
        'owedAmount': owedAmount,
        'isSettled': isSettled,
      };

  Map<String, dynamic> toSupabase() => {
        'id': id,
        'expense_id': expenseId,
        'user_id': userId,
        'owed_amount': owedAmount,
        'is_settled': isSettled,
      };

  factory SharedExpenseSplit.fromSupabase(Map<String, dynamic> json) =>
      SharedExpenseSplit(
        id: json['id'].toString(),
        expenseId: json['expense_id'].toString(),
        userId: json['user_id'].toString(),
        owedAmount: (json['owed_amount'] as num).toDouble(),
        isSettled: json['is_settled'] ?? false,
      );

  SharedExpenseSplit copyWith({
    String? id,
    String? expenseId,
    String? userId,
    double? owedAmount,
    bool? isSettled,
  }) =>
      SharedExpenseSplit(
        id: id ?? this.id,
        expenseId: expenseId ?? this.expenseId,
        userId: userId ?? this.userId,
        owedAmount: owedAmount ?? this.owedAmount,
        isSettled: isSettled ?? this.isSettled,
      );
}

class SharedExpense {
  final String id;
  final String roomId;
  final String paidBy;
  final String title;
  final double amount;
  final String? category;
  final String? note;
  final SharedSplitType splitType;
  final DateTime expenseDate;
  final DateTime createdAt;
  final List<SharedExpenseSplit> splits;

  // Sync metadata
  final bool isSynced;
  final bool isDeleted;
  final DateTime updatedAt;

  SharedExpense({
    required this.id,
    required this.roomId,
    required this.paidBy,
    required this.title,
    required this.amount,
    this.category,
    this.note,
    this.splitType = SharedSplitType.equal,
    DateTime? expenseDate,
    DateTime? createdAt,
    this.splits = const [],
    this.isSynced = false,
    this.isDeleted = false,
    DateTime? updatedAt,
  })  : expenseDate = expenseDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static SharedSplitType _parseSplit(String? s) {
    switch (s) {
      case 'custom':
        return SharedSplitType.custom;
      case 'percentage':
        return SharedSplitType.percentage;
      default:
        return SharedSplitType.equal;
    }
  }

  static String splitToString(SharedSplitType s) => s.name;

  factory SharedExpense.fromJson(Map<String, dynamic> json) => SharedExpense(
        id: json['id'],
        roomId: json['roomId'],
        paidBy: json['paidBy'],
        title: json['title'] ?? '',
        amount: (json['amount'] as num).toDouble(),
        category: json['category'],
        note: json['note'],
        splitType: _parseSplit(json['splitType']),
        expenseDate: json['expenseDate'] != null
            ? DateTime.parse(json['expenseDate'])
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
        splits: (json['splits'] as List<dynamic>? ?? [])
            .map((e) => SharedExpenseSplit.fromJson(e))
            .toList(),
        isSynced: json['isSynced'] ?? false,
        isDeleted: json['isDeleted'] ?? false,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'paidBy': paidBy,
        'title': title,
        'amount': amount,
        'category': category,
        'note': note,
        'splitType': splitToString(splitType),
        'expenseDate': expenseDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'splits': splits.map((s) => s.toJson()).toList(),
        'isSynced': isSynced,
        'isDeleted': isDeleted,
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Supabase serialization for the parent row only — splits are inserted
  /// into the [shared_expense_splits] table separately.
  Map<String, dynamic> toSupabase() => {
        'id': id,
        'room_id': roomId,
        'paid_by': paidBy,
        'title': title,
        'amount': amount,
        'category': category,
        'note': note,
        'split_type': splitToString(splitType),
        'expense_date': expenseDate.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory SharedExpense.fromSupabase(
    Map<String, dynamic> json, {
    List<SharedExpenseSplit> splits = const [],
  }) =>
      SharedExpense(
        id: json['id'].toString(),
        roomId: json['room_id'].toString(),
        paidBy: json['paid_by'].toString(),
        title: (json['title'] ?? '').toString(),
        amount: (json['amount'] as num).toDouble(),
        category: json['category']?.toString(),
        note: json['note']?.toString(),
        splitType: _parseSplit(json['split_type']?.toString()),
        expenseDate: json['expense_date'] != null
            ? DateTime.parse(json['expense_date'].toString())
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'].toString())
            : null,
        splits: splits,
        isSynced: true,
        isDeleted: false,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'].toString())
            : null,
      );

  SharedExpense copyWith({
    String? id,
    String? roomId,
    String? paidBy,
    String? title,
    double? amount,
    String? category,
    String? note,
    SharedSplitType? splitType,
    DateTime? expenseDate,
    DateTime? createdAt,
    List<SharedExpenseSplit>? splits,
    bool? isSynced,
    bool? isDeleted,
    DateTime? updatedAt,
  }) =>
      SharedExpense(
        id: id ?? this.id,
        roomId: roomId ?? this.roomId,
        paidBy: paidBy ?? this.paidBy,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        note: note ?? this.note,
        splitType: splitType ?? this.splitType,
        expenseDate: expenseDate ?? this.expenseDate,
        createdAt: createdAt ?? this.createdAt,
        splits: splits ?? this.splits,
        isSynced: isSynced ?? this.isSynced,
        isDeleted: isDeleted ?? this.isDeleted,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
