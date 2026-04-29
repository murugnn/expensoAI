/// A money transfer between two members of a [SharedRoom].
///
/// Settlements move through a two-step approval flow:
///   1. A debtor proposes a payment → status='pending'
///   2. The creditor (toUser) accepts or rejects via approveSettlement /
///      rejectSettlement → status flips to 'completed' or 'cancelled'
///
/// A creditor can also self-record cash they received, in which case the
/// row is created directly with status='completed'.
class SharedSettlement {
  final String id;
  final String roomId;
  final String fromUser;
  final String toUser;
  final double amount;
  final String status; // 'pending' | 'completed' | 'cancelled'
  final String? note;
  final DateTime createdAt;

  /// User who proposed this settlement. When equal to [toUser], the row
  /// is treated as a creditor-side acknowledgement and starts 'completed'.
  final String? requestedBy;

  /// When the creditor approved or rejected. Null while pending.
  final DateTime? decidedAt;

  /// Optional reason supplied on rejection (or note on approval).
  final String? decisionNote;

  // Sync metadata
  final bool isSynced;
  final bool isDeleted;

  SharedSettlement({
    required this.id,
    required this.roomId,
    required this.fromUser,
    required this.toUser,
    required this.amount,
    this.status = 'pending',
    this.note,
    DateTime? createdAt,
    this.requestedBy,
    this.decidedAt,
    this.decisionNote,
    this.isSynced = false,
    this.isDeleted = false,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SharedSettlement.fromJson(Map<String, dynamic> json) =>
      SharedSettlement(
        id: json['id'],
        roomId: json['roomId'],
        fromUser: json['fromUser'],
        toUser: json['toUser'],
        amount: (json['amount'] as num).toDouble(),
        status: json['status'] ?? 'pending',
        note: json['note'],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
        requestedBy: json['requestedBy'],
        decidedAt: json['decidedAt'] != null
            ? DateTime.parse(json['decidedAt'])
            : null,
        decisionNote: json['decisionNote'],
        isSynced: json['isSynced'] ?? false,
        isDeleted: json['isDeleted'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'fromUser': fromUser,
        'toUser': toUser,
        'amount': amount,
        'status': status,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
        'requestedBy': requestedBy,
        'decidedAt': decidedAt?.toIso8601String(),
        'decisionNote': decisionNote,
        'isSynced': isSynced,
        'isDeleted': isDeleted,
      };

  Map<String, dynamic> toSupabase() => {
        'id': id,
        'room_id': roomId,
        'from_user': fromUser,
        'to_user': toUser,
        'amount': amount,
        'status': status,
        'note': note,
        'requested_by': requestedBy,
        'decided_at': decidedAt?.toIso8601String(),
        'decision_note': decisionNote,
      };

  factory SharedSettlement.fromSupabase(Map<String, dynamic> json) =>
      SharedSettlement(
        id: json['id'].toString(),
        roomId: json['room_id'].toString(),
        fromUser: json['from_user'].toString(),
        toUser: json['to_user'].toString(),
        amount: (json['amount'] as num).toDouble(),
        status: (json['status'] ?? 'pending').toString(),
        note: json['note']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'].toString())
            : null,
        requestedBy: json['requested_by']?.toString(),
        decidedAt: json['decided_at'] != null
            ? DateTime.parse(json['decided_at'].toString())
            : null,
        decisionNote: json['decision_note']?.toString(),
        isSynced: true,
      );

  SharedSettlement copyWith({
    String? id,
    String? roomId,
    String? fromUser,
    String? toUser,
    double? amount,
    String? status,
    String? note,
    DateTime? createdAt,
    String? requestedBy,
    DateTime? decidedAt,
    String? decisionNote,
    bool? isSynced,
    bool? isDeleted,
  }) =>
      SharedSettlement(
        id: id ?? this.id,
        roomId: roomId ?? this.roomId,
        fromUser: fromUser ?? this.fromUser,
        toUser: toUser ?? this.toUser,
        amount: amount ?? this.amount,
        status: status ?? this.status,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
        requestedBy: requestedBy ?? this.requestedBy,
        decidedAt: decidedAt ?? this.decidedAt,
        decisionNote: decisionNote ?? this.decisionNote,
        isSynced: isSynced ?? this.isSynced,
        isDeleted: isDeleted ?? this.isDeleted,
      );
}

/// Net balance row computed locally — positive = room owes the user,
/// negative = the user owes the room.
class RoomBalance {
  final String userId;
  final String? displayName;
  final double net; // positive = should receive, negative = owes
  const RoomBalance({
    required this.userId,
    this.displayName,
    required this.net,
  });
}

/// A "X pays Y ₹Z" suggestion produced by the settlement optimizer.
class SettlementTransfer {
  final String fromUserId;
  final String toUserId;
  final String? fromName;
  final String? toName;
  final double amount;
  const SettlementTransfer({
    required this.fromUserId,
    required this.toUserId,
    this.fromName,
    this.toName,
    required this.amount,
  });
}
