class Expense {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String? contact;
  final List<String> tags;
  final String wallet;
  final String? billId; // ID to group expenses involved in a single bill
  final String? billName; // Name of the bill (e.g. Merchant Name)

  // Multi-Currency Metadata (for cross-border transactions)
  final String? originalCurrency;  // ISO 4217 code (e.g. "EUR", "USD")
  final double? originalAmount;    // Amount in original foreign currency
  final double? exchangeRate;      // Exchange rate used at conversion time

  // Sync Metadata
  final bool isSynced; // True if saved to Supabase
  final bool isDeleted; // True if deleted locally but not yet on Supabase
  final DateTime updatedAt; // For conflict resolution

  Expense({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.contact,
    this.tags = const [],
    this.wallet = 'Cash',
    this.billId,
    this.billName,
    this.originalCurrency,
    this.originalAmount,
    this.exchangeRate,
    this.isSynced = false,
    this.isDeleted = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  // 1. From Local Storage (SharedPreferences JSON)
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      userId: json['userId'],
      title: json['title'],
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      category: json['category'],
      contact: json['contact'],
      tags: List<String>.from(json['tags'] ?? []),
      wallet: json['wallet'] ?? 'Cash',
      billId: json['billId'],
      billName: json['billName'],
      originalCurrency: json['originalCurrency'],
      originalAmount: (json['originalAmount'] as num?)?.toDouble(),
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble(),
      isSynced: json['isSynced'] ?? true,
      isDeleted: json['isDeleted'] ?? false,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  // 2. To Local Storage (SharedPreferences JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'contact': contact,
      'tags': tags,
      'wallet': wallet,
      'billId': billId,
      'billName': billName,
      'originalCurrency': originalCurrency,
      'originalAmount': originalAmount,
      'exchangeRate': exchangeRate,
      'isSynced': isSynced,
      'isDeleted': isDeleted,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // 3. To Supabase (Database JSON)
  Map<String, dynamic> toSupabase() {
    final map = {
      'id': id,
      'user_id': userId,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'contact': contact,
      'tags': tags,
      'wallet': wallet,
      // 'bill_id': billId, // Column missing in DB
      'updated_at': updatedAt.toIso8601String(),
    };
    
    // Only add bill_name if it exists, to be safer
    // if (billName != null) {
    //   map['bill_name'] = billName; // Column missing in DB
    // }
    
    return map;
  }

  // 4. From Supabase (Database JSON)
  factory Expense.fromSupabase(Map<String, dynamic> json) {
    return Expense(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      title: (json['title'] ?? '').toString(),
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'].toString()),
      category: (json['category'] ?? '').toString(),
      contact: json['contact']?.toString(),
      tags: json['tags'] != null ? List<String>.from(json['tags']) : <String>[],
      wallet: (json['wallet'] ?? 'Cash').toString(),
      billId: json['bill_id']?.toString(),
      billName: json['bill_name']?.toString(),
      originalCurrency: json['original_currency']?.toString(),
      originalAmount: (json['original_amount'] as num?)?.toDouble(),
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble(),
      isSynced: true,
      isDeleted: false,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
    );
  }

  // 5. CopyWith (Helper for updating flags)
  Expense copyWith({
    String? id,
    String? userId,
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    String? contact,
    List<String>? tags,
    String? wallet,
    String? billId,
    String? billName,
    String? originalCurrency,
    double? originalAmount,
    double? exchangeRate,
    bool? isSynced,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      contact: contact ?? this.contact,
      tags: tags ?? this.tags,
      wallet: wallet ?? this.wallet,
      billId: billId ?? this.billId,
      billName: billName ?? this.billName,
      originalCurrency: originalCurrency ?? this.originalCurrency,
      originalAmount: originalAmount ?? this.originalAmount,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
