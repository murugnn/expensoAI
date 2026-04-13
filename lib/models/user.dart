class User {
  final String id;
  final String name;
  final String email;

  /// Local avatar image path (asset path) or remote URL.
  /// Stored locally because this project currently has no backend connected.
  final String? avatar;
  final DateTime createdAt;
  final DateTime updatedAt;

  final int coins;
  final String? referralCode;
  final String? referredBy;
  final bool referralClaimed;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    required this.createdAt,
    required this.updatedAt,
    this.coins = 0,
    this.referralCode,
    this.referredBy,
    this.referralClaimed = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatar': avatar,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'coins': coins,
    'referralCode': referralCode,
    'referredBy': referredBy,
    'referralClaimed': referralClaimed,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    avatar: json['avatar'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    coins: json['coins'] as int? ?? 0,
    referralCode: json['referralCode'] as String?,
    referredBy: json['referredBy'] as String?,
    referralClaimed: json['referralClaimed'] as bool? ?? false,
  );

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? avatar,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? coins,
    String? referralCode,
    String? referredBy,
    bool? referralClaimed,
  }) => User(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    avatar: avatar ?? this.avatar,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    coins: coins ?? this.coins,
    referralCode: referralCode ?? this.referralCode,
    referredBy: referredBy ?? this.referredBy,
    referralClaimed: referralClaimed ?? this.referralClaimed,
  );
}
