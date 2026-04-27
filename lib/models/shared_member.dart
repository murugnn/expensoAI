/// A member of a [SharedRoom].
class SharedMember {
  final String id;
  final String roomId;
  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final String role; // 'owner' | 'member'
  final DateTime joinedAt;

  const SharedMember({
    required this.id,
    required this.roomId,
    required this.userId,
    this.displayName,
    this.avatarUrl,
    this.role = 'member',
    required this.joinedAt,
  });

  bool get isOwner => role == 'owner';

  factory SharedMember.fromJson(Map<String, dynamic> json) => SharedMember(
        id: json['id'],
        roomId: json['roomId'],
        userId: json['userId'],
        displayName: json['displayName'],
        avatarUrl: json['avatarUrl'],
        role: json['role'] ?? 'member',
        joinedAt: json['joinedAt'] != null
            ? DateTime.parse(json['joinedAt'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'userId': userId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'role': role,
        'joinedAt': joinedAt.toIso8601String(),
      };

  Map<String, dynamic> toSupabase() => {
        'id': id,
        'room_id': roomId,
        'user_id': userId,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'role': role,
        'joined_at': joinedAt.toIso8601String(),
      };

  factory SharedMember.fromSupabase(Map<String, dynamic> json) => SharedMember(
        id: json['id'].toString(),
        roomId: json['room_id'].toString(),
        userId: json['user_id'].toString(),
        displayName: json['display_name']?.toString(),
        avatarUrl: json['avatar_url']?.toString(),
        role: (json['role'] ?? 'member').toString(),
        joinedAt: json['joined_at'] != null
            ? DateTime.parse(json['joined_at'].toString())
            : DateTime.now(),
      );

  SharedMember copyWith({
    String? id,
    String? roomId,
    String? userId,
    String? displayName,
    String? avatarUrl,
    String? role,
    DateTime? joinedAt,
  }) =>
      SharedMember(
        id: id ?? this.id,
        roomId: roomId ?? this.roomId,
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role ?? this.role,
        joinedAt: joinedAt ?? this.joinedAt,
      );
}
