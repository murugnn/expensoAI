class Contact {
  final String id;
  final String userId;
  final String name;
  final String? phone;
  final String? email;

  Contact({
    required this.id,
    required this.userId,
    required this.name,
    this.phone,
    this.email,
  });

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      name: map['name'].toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
    );
  }
}
