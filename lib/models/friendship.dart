/// A confirmed friendship between two users. Stored symmetrically as
/// (user_a < user_b) on the server; this model normalizes that into
/// "me" vs "the other side" for ergonomic UI use.
class Friendship {
  final String otherUserId;
  final DateTime createdAt;

  const Friendship({
    required this.otherUserId,
    required this.createdAt,
  });

  factory Friendship.fromSupabase(
    Map<String, dynamic> m, {
    required String myId,
  }) {
    final a = m['user_a'].toString();
    final b = m['user_b'].toString();
    final other = a == myId ? b : a;
    return Friendship(
      otherUserId: other,
      createdAt: DateTime.parse(m['created_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'other_user_id': otherUserId,
        'created_at': createdAt.toIso8601String(),
      };

  factory Friendship.fromJson(Map<String, dynamic> m) => Friendship(
        otherUserId: m['other_user_id'].toString(),
        createdAt: DateTime.parse(m['created_at'].toString()),
      );
}
