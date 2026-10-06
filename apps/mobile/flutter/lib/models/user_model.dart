import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 2)
class UserModel extends HiveObject {
  @HiveField(0)
  final String uid;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String username;
  @HiveField(3)
  final String email;
  @HiveField(4)
  final String bio;
  @HiveField(5)
  final int? age;
  @HiveField(6)
  final String gender; // 'Male' | 'Female' | 'Non-binary' | 'Prefer not to say'
  @HiveField(7)
  final DateTime createdAt;
  @HiveField(8)
  final bool isOnline;
  @HiveField(9)
  final DateTime? lastSeen;
  @HiveField(10)
  final String status; // 'Online' | 'Away' | 'Busy' | 'Invisible'
  @HiveField(11)
  final String photoUrl; // Profile picture URL
  @HiveField(12)
  final String lastSeenVisibility;
  @HiveField(13)
  final String profilePhotoVisibility;
  @HiveField(14)
  final bool readReceipts;

  UserModel({
    required this.uid,
    required this.name,
    required this.username,
    required this.email,
    required this.bio,
    this.age,
    this.gender = '',
    required this.createdAt,
    this.isOnline = false,
    this.lastSeen,
    this.status = 'Online',
    this.photoUrl = '',
    this.lastSeenVisibility = 'everyone',
    this.profilePhotoVisibility = 'everyone',
    this.readReceipts = true,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: d['name'] ?? '',
      username: d['username'] ?? '',
      email: d['email'] ?? '',
      bio: d['bio'] ?? '',
      age: d['age'] as int?,
      gender: d['gender'] ?? '',
      isOnline: d['isOnline'] ?? false,
      lastSeen: (d['lastSeen'] as Timestamp?)?.toDate(),
      status: d['status'] ?? 'Online',
      photoUrl: d['photoUrl'] ?? '',
      lastSeenVisibility: d['lastSeenVisibility'] ?? 'everyone',
      profilePhotoVisibility: d['profilePhotoVisibility'] ?? 'everyone',
      readReceipts: d['readReceipts'] ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'username': username,
        'email': email,
        'bio': bio,
        'age': age,
        'gender': gender,
        'isOnline': isOnline,
        'status': status,
        'photoUrl': photoUrl,
        'lastSeenVisibility': lastSeenVisibility,
        'profilePhotoVisibility': profilePhotoVisibility,
        'readReceipts': readReceipts,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  UserModel copyWith({
    String? name,
    String? username,
    String? bio,
    int? age,
    String? gender,
    String? photoUrl,
    String? status,
    bool? isOnline,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email,
      bio: bio ?? this.bio,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt,
      lastSeen: lastSeen,
    );
  }

  // ── Helpers for UI ────────────────────────────────────────────────────────
  
  Color get avatarColor {
    final colors = [
      const Color(0xFF7C6FF7),
      const Color(0xFFEC4899),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
    ];
    // Use hashCode of uid to pick a consistent color
    return colors[uid.hashCode.abs() % colors.length];
  }

  String get initials {
    if (name.trim().isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
