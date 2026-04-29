/// Public-facing profile of an Expenso user, used for friend resolution,
/// invite cards, and contact-match results.
class UserProfile {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final String? phoneHash;
  final String? emailHash;
  final String? bio;

  const UserProfile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.phoneHash,
    this.emailHash,
    this.bio,
  });

  String get initials {
    final n = (displayName ?? '').trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory UserProfile.fromSupabase(Map<String, dynamic> m) => UserProfile(
        id: m['id'].toString(),
        displayName: m['display_name']?.toString(),
        avatarUrl: m['avatar_url']?.toString(),
        phoneHash: m['phone_hash']?.toString(),
        emailHash: m['email_hash']?.toString(),
        bio: m['bio']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'phone_hash': phoneHash,
        'email_hash': emailHash,
        'bio': bio,
      };

  factory UserProfile.fromJson(Map<String, dynamic> m) =>
      UserProfile.fromSupabase(m);
}
