enum FriendRequestStatus { pending, accepted, declined, cancelled }

FriendRequestStatus _statusFrom(String s) {
  switch (s) {
    case 'accepted':
      return FriendRequestStatus.accepted;
    case 'declined':
      return FriendRequestStatus.declined;
    case 'cancelled':
      return FriendRequestStatus.cancelled;
    default:
      return FriendRequestStatus.pending;
  }
}

String _statusTo(FriendRequestStatus s) => s.name;

/// Represents one row of `friend_requests`. Direction is decided at the call
/// site — provider tags each request as inbound or outbound for the UI.
class FriendRequest {
  final String id;
  final String fromUser;
  final String toUser;
  final FriendRequestStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const FriendRequest({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.status,
    this.message,
    required this.createdAt,
    this.respondedAt,
  });

  bool isIncomingFor(String userId) => toUser == userId;
  bool isOutgoingFor(String userId) => fromUser == userId;

  factory FriendRequest.fromSupabase(Map<String, dynamic> m) => FriendRequest(
        id: m['id'].toString(),
        fromUser: m['from_user'].toString(),
        toUser: m['to_user'].toString(),
        status: _statusFrom(m['status'].toString()),
        message: m['message']?.toString(),
        createdAt: DateTime.parse(m['created_at'].toString()),
        respondedAt: m['responded_at'] == null
            ? null
            : DateTime.parse(m['responded_at'].toString()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'from_user': fromUser,
        'to_user': toUser,
        'status': _statusTo(status),
        'message': message,
        'created_at': createdAt.toIso8601String(),
        'responded_at': respondedAt?.toIso8601String(),
      };

  factory FriendRequest.fromJson(Map<String, dynamic> m) =>
      FriendRequest.fromSupabase(m);
}
