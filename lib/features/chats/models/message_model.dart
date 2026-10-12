import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, file, voice }
enum MessageStatus { sent, delivered, seen }

class MessageModel {
  final String id;
  final String senderId;
  final MessageType type;
  final String? text;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final String? replyToMessageId;
  final MessageStatus status;
  final List<String> seenBy;
  final bool isEdited;
  final bool isDeleted;
  final DateTime? createdAt;
  final Map<String, String> reactions;
  final bool isPinned;
  final List<String> starredBy;
  final bool isPending; // NOT stored in Firestore — set from snapshot metadata at read time

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.type,
    this.text,
    this.mediaUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.replyToMessageId,
    this.status = MessageStatus.sent,
    this.seenBy = const [],
    this.isEdited = false,
    this.isDeleted = false,
    this.createdAt,
    this.reactions = const {},
    this.isPinned = false,
    this.starredBy = const [],
    this.isPending = false,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      type: MessageType.values.firstWhere(
            (t) => t.name == (map['type'] as String? ?? 'text'),
        orElse: () => MessageType.text,
      ),
      text: map['text'] as String?,
      mediaUrl: map['mediaUrl'] as String?,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      durationSeconds: map['durationSeconds'] as int?,
      replyToMessageId: map['replyToMessageId'] as String?,
      status: MessageStatus.values.firstWhere(
            (s) => s.name == (map['status'] as String? ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      seenBy: List<String>.from(map['seenBy'] as List? ?? []),
      isEdited: map['isEdited'] as bool? ?? false,
      isDeleted: map['isDeleted'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      reactions: Map<String, String>.from(map['reactions'] as Map? ?? {}),
      isPinned: map['isPinned'] as bool? ?? false,
      starredBy: List<String>.from(map['starredBy'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'type': type.name,
      'text': text,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'durationSeconds': durationSeconds,
      'replyToMessageId': replyToMessageId,
      'status': status.name,
      'seenBy': seenBy,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  MessageModel copyWithPending(bool pending) => MessageModel(
    id: id,
    senderId: senderId,
    type: type,
    text: text,
    mediaUrl: mediaUrl,
    thumbnailUrl: thumbnailUrl,
    durationSeconds: durationSeconds,
    replyToMessageId: replyToMessageId,
    status: status,
    seenBy: seenBy,
    isEdited: isEdited,
    isDeleted: isDeleted,
    createdAt: createdAt,
    reactions: reactions,
    isPinned: isPinned,
    starredBy: starredBy,
    isPending: pending,
  );
}