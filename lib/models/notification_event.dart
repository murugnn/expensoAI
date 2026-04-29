/// Durable record of a notification. Rendered in the in-app inbox and used
/// as the event source for local + (later) push delivery.
class NotificationEvent {
  /// Stable type tags. The string lives in `type` on the server.
  static const typeFriendRequest = 'friend_request';
  static const typeFriendAccepted = 'friend_accepted';
  static const typeRoomInvite = 'room_invite';
  static const typeRoomInviteAccepted = 'room_invite_accepted';
  static const typeSharedExpenseAdded = 'shared_expense_added';
  static const typeSettleOwed = 'settle_owed';
  static const typeSettlementReceived = 'settlement_received';
  static const typeSettlementReminder = 'settlement_reminder';
  static const typeRoomRenamed = 'room_renamed';

  // Two-step settlement approval flow.
  static const typeSettlementPending = 'settlement_pending';
  static const typeSettlementApproved = 'settlement_approved';
  static const typeSettlementRejected = 'settlement_rejected';

  final String id;
  final String userId;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic> payload;
  final bool delivered;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationEvent({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    this.body,
    this.payload = const {},
    this.delivered = false,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory NotificationEvent.fromSupabase(Map<String, dynamic> m) {
    final raw = m['payload'];
    final Map<String, dynamic> parsed;
    if (raw is Map) {
      parsed = Map<String, dynamic>.from(raw);
    } else {
      parsed = const {};
    }
    return NotificationEvent(
      id: m['id'].toString(),
      userId: m['user_id'].toString(),
      type: m['type'].toString(),
      title: m['title'].toString(),
      body: m['body']?.toString(),
      payload: parsed,
      delivered: m['delivered'] == true,
      readAt: m['read_at'] == null
          ? null
          : DateTime.parse(m['read_at'].toString()),
      createdAt: DateTime.parse(m['created_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'payload': payload,
        'delivered': delivered,
        'read_at': readAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory NotificationEvent.fromJson(Map<String, dynamic> m) =>
      NotificationEvent.fromSupabase(m);

  NotificationEvent copyWith({bool? delivered, DateTime? readAt}) {
    return NotificationEvent(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      payload: payload,
      delivered: delivered ?? this.delivered,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}
