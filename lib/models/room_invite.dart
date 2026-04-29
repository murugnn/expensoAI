enum RoomInviteStatus { pending, accepted, declined, cancelled, expired }

RoomInviteStatus _riStatusFrom(String s) {
  switch (s) {
    case 'accepted':
      return RoomInviteStatus.accepted;
    case 'declined':
      return RoomInviteStatus.declined;
    case 'cancelled':
      return RoomInviteStatus.cancelled;
    case 'expired':
      return RoomInviteStatus.expired;
    default:
      return RoomInviteStatus.pending;
  }
}

class RoomInvite {
  final String id;
  final String roomId;
  final String fromUser;
  final String toUser;
  final RoomInviteStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const RoomInvite({
    required this.id,
    required this.roomId,
    required this.fromUser,
    required this.toUser,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory RoomInvite.fromSupabase(Map<String, dynamic> m) => RoomInvite(
        id: m['id'].toString(),
        roomId: m['room_id'].toString(),
        fromUser: m['from_user'].toString(),
        toUser: m['to_user'].toString(),
        status: _riStatusFrom(m['status'].toString()),
        createdAt: DateTime.parse(m['created_at'].toString()),
        respondedAt: m['responded_at'] == null
            ? null
            : DateTime.parse(m['responded_at'].toString()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'from_user': fromUser,
        'to_user': toUser,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'responded_at': respondedAt?.toIso8601String(),
      };

  factory RoomInvite.fromJson(Map<String, dynamic> m) =>
      RoomInvite.fromSupabase(m);
}
