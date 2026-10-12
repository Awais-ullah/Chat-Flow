import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// All direct Firestore calls related to user profiles live here.
class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  /// Called once, right after Firebase Auth registration succeeds.
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    final user = UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
    );
    await _usersRef.doc(uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  /// Real-time stream of a single user's profile (used for the current
  /// user's own profile screen, and for showing live online/last-seen
  /// status on other users' profiles).
  Stream<UserModel?> watchUser(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? bio,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    if (updates.isEmpty) return;
    await _usersRef.doc(uid).update(updates);
  }
  Future<void> saveFcmToken({required String uid, required String token}) async {
    await _usersRef.doc(uid).update({'fcmToken': token});
  }

  Future<void> setOnlineStatus({required String uid, required bool isOnline}) async {
    await _usersRef.doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Simple prefix search on displayName. Firestore doesn't support
  /// full-text search natively, so this uses a range query trick:
  /// it finds names that start with [query] (case-sensitive).
  /// Good enough for MVP; a dedicated search service (e.g. Algolia)
  /// would be needed for fuzzy/case-insensitive search later.
  Future<List<UserModel>> searchUsersByName(String query, {required String excludeUid}) async {
    if (query.trim().isEmpty) return [];
    final snapshot = await _usersRef
        .orderBy('displayName')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .where((user) => user.uid != excludeUid)
        .toList();
  }
}