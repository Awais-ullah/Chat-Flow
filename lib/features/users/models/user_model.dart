import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a ChatFlow user's Firestore profile document.
/// Lives at: users/{uid}
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? bio;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final String? fcmToken;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.bio,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
    this.fcmToken
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Unknown',
      photoUrl: map['photoUrl'] as String?,
      bio: map['bio'] as String?,
      isOnline: map['isOnline'] as bool? ?? false,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      fcmToken: map['fcmToken'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  /// True online status, accounting for the possibility that isOnline
  /// was never correctly flipped to false (e.g. app killed abruptly).
  /// If lastSeen is more than 45 seconds old, treat the user as
  /// offline regardless of what the raw isOnline flag says.
  bool get isActuallyOnline {
    if (!isOnline) return false;
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen!).inSeconds < 45;
  }

  UserModel copyWith({
    String? displayName,
    String? photoUrl,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
    );
  }
}