import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final List<String> participantIds;
  final Map<String, Map<String, String>> participantsMeta;
  final String? lastMessageId;
  final String? lastMessageText;
  final String? lastMessageSenderId;
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCount;
  final DateTime? createdAt;
  final String type;
  final String? groupName;
  final String? groupPhotoUrl;
  final List<String> adminIds;

  const ConversationModel({
    required this.id,
    required this.participantIds,
    required this.participantsMeta,
    this.lastMessageId,
    this.lastMessageText,
    this.lastMessageSenderId,
    this.lastMessageTime,
    this.unreadCount = const {},
    this.createdAt,
    this.type = 'direct',
    this.groupName,
    this.groupPhotoUrl,
    this.adminIds = const [],
  });

  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    final rawMeta = map['participantsMeta'] as Map<String, dynamic>? ?? {};
    final meta = rawMeta.map(
          (uid, value) => MapEntry(uid, Map<String, String>.from(value as Map)),
    );
    final rawUnread = map['unreadCount'] as Map<String, dynamic>? ?? {};
    final unread = rawUnread.map((uid, value) => MapEntry(uid, value as int));

    return ConversationModel(
      id: id,
      participantIds: List<String>.from(map['participantIds'] as List? ?? []),
      participantsMeta: meta,
      lastMessageId: map['lastMessageId'] as String?,
      lastMessageText: map['lastMessageText'] as String?,
      lastMessageSenderId: map['lastMessageSenderId'] as String?,
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCount: unread,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      type: map['type'] as String? ?? 'direct',
      groupName: map['groupName'] as String?,
      groupPhotoUrl: map['groupPhotoUrl'] as String?,
      adminIds: List<String>.from(map['adminIds'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participantIds': participantIds,
      'participantsMeta': participantsMeta,
      'lastMessageId': lastMessageId,
      'lastMessageText': lastMessageText,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : FieldValue.serverTimestamp(),
      'unreadCount': unreadCount,
      'createdAt': FieldValue.serverTimestamp(),
      'type': type,
      'groupName': groupName,
      'groupPhotoUrl': groupPhotoUrl,
      'adminIds': adminIds,
    };
  }

  String otherUserId(String currentUid) =>
      participantIds.firstWhere((id) => id != currentUid, orElse: () => '');

  bool get isGroup => type == 'group';

  String displayName(String currentUid) {
    if (isGroup) return groupName ?? 'Group';
    return participantsMeta[otherUserId(currentUid)]?['name'] ?? 'Unknown';
  }

  String? displayPhoto(String currentUid) {
    if (isGroup) return groupPhotoUrl;
    return participantsMeta[otherUserId(currentUid)]?['photoUrl'];
  }
}