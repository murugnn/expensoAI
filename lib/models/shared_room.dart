import 'package:flutter/material.dart';

/// A shared finance room — friends-split, roommate budget, trip wallet, etc.
/// Mirrors the [BusinessTransaction] / [BusinessDue] serialization pattern.
enum SharedRoomType { flatmates, trip, couple, friends, team, custom }

class SharedRoom {
  final String id;
  final String ownerId;
  final String roomName;
  final String roomCode;
  final SharedRoomType roomType;
  final String currency;
  final String? imageUrl;
  final DateTime createdAt;

  // Sync metadata
  final bool isSynced;
  final bool isDeleted;
  final DateTime updatedAt;

  SharedRoom({
    required this.id,
    required this.ownerId,
    required this.roomName,
    required this.roomCode,
    this.roomType = SharedRoomType.custom,
    this.currency = 'INR',
    this.imageUrl,
    DateTime? createdAt,
    this.isSynced = false,
    this.isDeleted = false,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static SharedRoomType _parseType(String? t) {
    switch (t) {
      case 'flatmates':
        return SharedRoomType.flatmates;
      case 'trip':
        return SharedRoomType.trip;
      case 'couple':
        return SharedRoomType.couple;
      case 'friends':
        return SharedRoomType.friends;
      case 'team':
        return SharedRoomType.team;
      default:
        return SharedRoomType.custom;
    }
  }

  static String typeToString(SharedRoomType t) => t.name;

  String get typeLabel {
    switch (roomType) {
      case SharedRoomType.flatmates:
        return 'Flatmates';
      case SharedRoomType.trip:
        return 'Trip';
      case SharedRoomType.couple:
        return 'Couple';
      case SharedRoomType.friends:
        return 'Friends';
      case SharedRoomType.team:
        return 'Team';
      case SharedRoomType.custom:
        return 'Custom';
    }
  }

  IconData get typeIcon {
    switch (roomType) {
      case SharedRoomType.flatmates:
        return Icons.home_work_rounded;
      case SharedRoomType.trip:
        return Icons.flight_takeoff_rounded;
      case SharedRoomType.couple:
        return Icons.favorite_rounded;
      case SharedRoomType.friends:
        return Icons.handshake_rounded;
      case SharedRoomType.team:
        return Icons.groups_rounded;
      case SharedRoomType.custom:
        return Icons.category_rounded;
    }
  }

  // 1. From Local
  factory SharedRoom.fromJson(Map<String, dynamic> json) => SharedRoom(
        id: json['id'],
        ownerId: json['ownerId'],
        roomName: json['roomName'] ?? '',
        roomCode: json['roomCode'] ?? '',
        roomType: _parseType(json['roomType']),
        currency: json['currency'] ?? 'INR',
        imageUrl: json['imageUrl'],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : null,
        isSynced: json['isSynced'] ?? false,
        isDeleted: json['isDeleted'] ?? false,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : null,
      );

  // 2. To Local
  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'roomName': roomName,
        'roomCode': roomCode,
        'roomType': typeToString(roomType),
        'currency': currency,
        'imageUrl': imageUrl,
        'createdAt': createdAt.toIso8601String(),
        'isSynced': isSynced,
        'isDeleted': isDeleted,
        'updatedAt': updatedAt.toIso8601String(),
      };

  // 3. To Supabase
  Map<String, dynamic> toSupabase() => {
        'id': id,
        'owner_id': ownerId,
        'room_name': roomName,
        'room_code': roomCode,
        'room_type': typeToString(roomType),
        'currency': currency,
        'image_url': imageUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  // 4. From Supabase
  factory SharedRoom.fromSupabase(Map<String, dynamic> json) => SharedRoom(
        id: json['id'].toString(),
        ownerId: json['owner_id'].toString(),
        roomName: (json['room_name'] ?? '').toString(),
        roomCode: (json['room_code'] ?? '').toString(),
        roomType: _parseType(json['room_type']?.toString()),
        currency: (json['currency'] ?? 'INR').toString(),
        imageUrl: json['image_url']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'].toString())
            : null,
        isSynced: true,
        isDeleted: false,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'].toString())
            : null,
      );

  SharedRoom copyWith({
    String? id,
    String? ownerId,
    String? roomName,
    String? roomCode,
    SharedRoomType? roomType,
    String? currency,
    String? imageUrl,
    DateTime? createdAt,
    bool? isSynced,
    bool? isDeleted,
    DateTime? updatedAt,
  }) =>
      SharedRoom(
        id: id ?? this.id,
        ownerId: ownerId ?? this.ownerId,
        roomName: roomName ?? this.roomName,
        roomCode: roomCode ?? this.roomCode,
        roomType: roomType ?? this.roomType,
        currency: currency ?? this.currency,
        imageUrl: imageUrl ?? this.imageUrl,
        createdAt: createdAt ?? this.createdAt,
        isSynced: isSynced ?? this.isSynced,
        isDeleted: isDeleted ?? this.isDeleted,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
