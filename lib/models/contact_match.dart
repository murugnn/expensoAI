/// One row from `contact_matches` — a phone-contact owned by the current user.
/// `matchedUserId` is non-null when the contact is on Expenso.
class ContactMatch {
  final String id;
  final String displayName;
  final String? phoneHash;
  final String? emailHash;
  final String? matchedUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Original (un-hashed) phone number, kept locally for share-sheet flows.
  /// Never uploaded.
  final String? localPhone;

  /// Original (un-hashed) email, kept locally for share-sheet flows.
  /// Never uploaded.
  final String? localEmail;

  const ContactMatch({
    required this.id,
    required this.displayName,
    this.phoneHash,
    this.emailHash,
    this.matchedUserId,
    required this.createdAt,
    required this.updatedAt,
    this.localPhone,
    this.localEmail,
  });

  bool get isOnExpenso => matchedUserId != null;

  String get initials {
    final n = displayName.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  ContactMatch copyWith({
    String? matchedUserId,
    String? localPhone,
    String? localEmail,
    String? displayName,
    DateTime? updatedAt,
  }) {
    return ContactMatch(
      id: id,
      displayName: displayName ?? this.displayName,
      phoneHash: phoneHash,
      emailHash: emailHash,
      matchedUserId: matchedUserId ?? this.matchedUserId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      localPhone: localPhone ?? this.localPhone,
      localEmail: localEmail ?? this.localEmail,
    );
  }

  factory ContactMatch.fromSupabase(Map<String, dynamic> m) => ContactMatch(
        id: m['id'].toString(),
        displayName: m['display_name']?.toString() ?? '',
        phoneHash: m['phone_hash']?.toString(),
        emailHash: m['email_hash']?.toString(),
        matchedUserId: m['matched_user_id']?.toString(),
        createdAt: DateTime.parse(m['created_at'].toString()),
        updatedAt: DateTime.parse(m['updated_at'].toString()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'phone_hash': phoneHash,
        'email_hash': emailHash,
        'matched_user_id': matchedUserId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'local_phone': localPhone,
        'local_email': localEmail,
      };

  factory ContactMatch.fromJson(Map<String, dynamic> m) => ContactMatch(
        id: m['id'].toString(),
        displayName: m['display_name']?.toString() ?? '',
        phoneHash: m['phone_hash']?.toString(),
        emailHash: m['email_hash']?.toString(),
        matchedUserId: m['matched_user_id']?.toString(),
        createdAt: DateTime.parse(m['created_at'].toString()),
        updatedAt: DateTime.parse(m['updated_at'].toString()),
        localPhone: m['local_phone']?.toString(),
        localEmail: m['local_email']?.toString(),
      );
}
