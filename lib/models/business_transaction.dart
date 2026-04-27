/// Represents a single business transaction — revenue, expense, or inventory purchase.
/// Follows the exact same serialization pattern as [Expense] for consistency.
enum TransactionType { revenue, expense, inventoryPurchase }

class BusinessTransaction {
  final String id;
  final String userId;
  final TransactionType type;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String? note;
  final String? customerName;
  final String? itemName;
  final int? quantity;
  final double? unitPrice;

  // Sync Metadata
  final bool isSynced;
  final bool isDeleted;
  final DateTime updatedAt;

  BusinessTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.note,
    this.customerName,
    this.itemName,
    this.quantity,
    this.unitPrice,
    this.isSynced = false,
    this.isDeleted = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  // --- Type Helpers ---
  bool get isRevenue => type == TransactionType.revenue;
  bool get isExpense => type == TransactionType.expense;
  bool get isInventory => type == TransactionType.inventoryPurchase;

  static TransactionType _parseType(String? typeStr) {
    switch (typeStr) {
      case 'revenue':
        return TransactionType.revenue;
      case 'expense':
        return TransactionType.expense;
      case 'inventory_purchase':
      case 'inventoryPurchase':
        return TransactionType.inventoryPurchase;
      default:
        return TransactionType.expense;
    }
  }

  static String _typeToString(TransactionType type) {
    switch (type) {
      case TransactionType.revenue:
        return 'revenue';
      case TransactionType.expense:
        return 'expense';
      case TransactionType.inventoryPurchase:
        return 'inventory_purchase';
    }
  }

  // 1. From Local Storage (JSON)
  factory BusinessTransaction.fromJson(Map<String, dynamic> json) {
    return BusinessTransaction(
      id: json['id'],
      userId: json['userId'],
      type: _parseType(json['type']),
      title: json['title'],
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      category: json['category'] ?? '',
      note: json['note'],
      customerName: json['customerName'],
      itemName: json['itemName'],
      quantity: json['quantity'],
      unitPrice: (json['unitPrice'] as num?)?.toDouble(),
      isSynced: json['isSynced'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  // 2. To Local Storage (JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': _typeToString(type),
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'note': note,
      'customerName': customerName,
      'itemName': itemName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'isSynced': isSynced,
      'isDeleted': isDeleted,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // 3. To Supabase (snake_case)
  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'type': _typeToString(type),
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'note': note,
      'customer_name': customerName,
      'item_name': itemName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // 4. From Supabase (snake_case)
  factory BusinessTransaction.fromSupabase(Map<String, dynamic> json) {
    return BusinessTransaction(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      type: _parseType(json['type']),
      title: (json['title'] ?? '').toString(),
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'].toString()),
      category: (json['category'] ?? '').toString(),
      note: json['note']?.toString(),
      customerName: json['customer_name']?.toString(),
      itemName: json['item_name']?.toString(),
      quantity: json['quantity'] as int?,
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      isSynced: true,
      isDeleted: false,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
    );
  }

  // 5. CopyWith
  BusinessTransaction copyWith({
    String? id,
    String? userId,
    TransactionType? type,
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    String? note,
    String? customerName,
    String? itemName,
    int? quantity,
    double? unitPrice,
    bool? isSynced,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return BusinessTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      note: note ?? this.note,
      customerName: customerName ?? this.customerName,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
