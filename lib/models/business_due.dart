/// Tracks money owed — either a customer owes the user (receivable)
/// or the user owes a supplier (payable).
enum DueDirection { receivable, payable }

class BusinessDue {
  final String id;
  final String userId;
  final String personName;
  final double amount;
  final DueDirection direction;
  final String? reason;
  final DateTime dueDate;
  final bool isPaid;
  final DateTime createdAt;

  // Sync Metadata
  final bool isSynced;
  final bool isDeleted;
  final DateTime updatedAt;

  BusinessDue({
    required this.id,
    required this.userId,
    required this.personName,
    required this.amount,
    required this.direction,
    this.reason,
    DateTime? dueDate,
    this.isPaid = false,
    DateTime? createdAt,
    this.isSynced = false,
    this.isDeleted = false,
    DateTime? updatedAt,
  })  : dueDate = dueDate ?? DateTime.now().add(const Duration(days: 7)),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isReceivable => direction == DueDirection.receivable;
  bool get isPayable => direction == DueDirection.payable;

  static DueDirection _parseDirection(String? dir) {
    return dir == 'payable' ? DueDirection.payable : DueDirection.receivable;
  }

  static String _directionToString(DueDirection d) {
    return d == DueDirection.payable ? 'payable' : 'receivable';
  }

  // 1. From Local Storage
  factory BusinessDue.fromJson(Map<String, dynamic> json) {
    return BusinessDue(
      id: json['id'],
      userId: json['userId'],
      personName: json['personName'] ?? '',
      amount: (json['amount'] as num).toDouble(),
      direction: _parseDirection(json['direction']),
      reason: json['reason'],
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      isPaid: json['isPaid'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      isSynced: json['isSynced'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  // 2. To Local Storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'personName': personName,
      'amount': amount,
      'direction': _directionToString(direction),
      'reason': reason,
      'dueDate': dueDate.toIso8601String(),
      'isPaid': isPaid,
      'createdAt': createdAt.toIso8601String(),
      'isSynced': isSynced,
      'isDeleted': isDeleted,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // 3. To Supabase
  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'person_name': personName,
      'amount': amount,
      'direction': _directionToString(direction),
      'reason': reason,
      'due_date': dueDate.toIso8601String(),
      'is_paid': isPaid,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // 4. From Supabase
  factory BusinessDue.fromSupabase(Map<String, dynamic> json) {
    return BusinessDue(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      personName: (json['person_name'] ?? '').toString(),
      amount: (json['amount'] as num).toDouble(),
      direction: _parseDirection(json['direction']),
      reason: json['reason']?.toString(),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'].toString())
          : null,
      isPaid: json['is_paid'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
      isSynced: true,
      isDeleted: false,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
    );
  }

  // 5. CopyWith
  BusinessDue copyWith({
    String? id,
    String? userId,
    String? personName,
    double? amount,
    DueDirection? direction,
    String? reason,
    DateTime? dueDate,
    bool? isPaid,
    DateTime? createdAt,
    bool? isSynced,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return BusinessDue(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      direction: direction ?? this.direction,
      reason: reason ?? this.reason,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
