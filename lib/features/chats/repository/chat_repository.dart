import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conversationsRef =>
      _firestore.collection('conversations');

  String directConversationId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<ConversationModel> getOrCreateDirectConversation({
    required String currentUid,
    required String currentName,
    required String? currentPhotoUrl,
    required String otherUid,
    required String otherName,
    required String? otherPhotoUrl,
  }) async {
    final id = directConversationId(currentUid, otherUid);
    final docRef = _conversationsRef.doc(id);

    DocumentSnapshot<Map<String, dynamic>>? doc;
    try {
      doc = await docRef.get();
    } catch (_) {
      doc = null;
    }

    if (doc != null && doc.exists) {
      return ConversationModel.fromMap(doc.data()!, doc.id);
    }

    final conversation = ConversationModel(
      id: id,
      participantIds: [currentUid, otherUid],
      participantsMeta: {
        currentUid: {'name': currentName, 'photoUrl': currentPhotoUrl ?? ''},
        otherUid: {'name': otherName, 'photoUrl': otherPhotoUrl ?? ''},
      },
      unreadCount: {currentUid: 0, otherUid: 0},
    );
    await docRef.set(conversation.toMap());
    return conversation;
  }

  Stream<List<ConversationModel>> watchConversations(String uid) {
    return _conversationsRef
        .where('participantIds', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ConversationModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  Stream<ConversationModel> watchConversation(String conversationId) {
    return _conversationsRef.doc(conversationId).snapshots().map(
          (doc) => ConversationModel.fromMap(doc.data() ?? {}, doc.id),
    );
  }

  Stream<List<MessageModel>> watchMessages(String conversationId) {
    return _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
    // includeMetadataChanges exposes hasPendingWrites — whether a
    // message is only sitting in the local offline cache (e.g. sent
    // with no internet) vs genuinely confirmed by the server.
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.docs.map((doc) {
      final model = MessageModel.fromMap(doc.data(), doc.id);
      return model.copyWithPending(doc.metadata.hasPendingWrites);
    }).toList());
  }

  Future<String> sendMessage({
    required String conversationId,
    required String senderId,
    required List<String> otherParticipantIds,
    required String text,
    String? replyToMessageId,
  }) async {
    final conversationRef = _conversationsRef.doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc();

    final message = MessageModel(
      id: messageRef.id,
      senderId: senderId,
      type: MessageType.text,
      text: text,
      replyToMessageId: replyToMessageId,
    );

    final updates = <String, dynamic>{
      'lastMessageId': messageRef.id,
      'lastMessageText': text,
      'lastMessageSenderId': senderId,
      'lastMessageTime': FieldValue.serverTimestamp(),
    };
    for (final uid in otherParticipantIds) {
      updates['unreadCount.$uid'] = FieldValue.increment(1);
    }

    final batch = _firestore.batch();
    batch.set(messageRef, message.toMap());
    batch.update(conversationRef, updates);
    await batch.commit();
    return messageRef.id;
  }

  Future<String> sendImageMessage({
    required String conversationId,
    required String senderId,
    required List<String> otherParticipantIds,
    required String imageUrl,
  }) async {
    final conversationRef = _conversationsRef.doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc();

    final message = MessageModel(
      id: messageRef.id,
      senderId: senderId,
      type: MessageType.image,
      mediaUrl: imageUrl,
    );

    final updates = <String, dynamic>{
      'lastMessageId': messageRef.id,
      'lastMessageText': '📷 Photo',
      'lastMessageSenderId': senderId,
      'lastMessageTime': FieldValue.serverTimestamp(),
    };
    for (final uid in otherParticipantIds) {
      updates['unreadCount.$uid'] = FieldValue.increment(1);
    }

    final batch = _firestore.batch();
    batch.set(messageRef, message.toMap());
    batch.update(conversationRef, updates);
    await batch.commit();
    return messageRef.id;
  }

  Future<String> sendVideoMessage({
    required String conversationId,
    required String senderId,
    required List<String> otherParticipantIds,
    required String videoUrl,
    String? thumbnailUrl,
  }) async {
    final conversationRef = _conversationsRef.doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc();

    final message = MessageModel(
      id: messageRef.id,
      senderId: senderId,
      type: MessageType.video,
      mediaUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
    );

    final updates = <String, dynamic>{
      'lastMessageId': messageRef.id,
      'lastMessageText': '🎥 Video',
      'lastMessageSenderId': senderId,
      'lastMessageTime': FieldValue.serverTimestamp(),
    };
    for (final uid in otherParticipantIds) {
      updates['unreadCount.$uid'] = FieldValue.increment(1);
    }

    final batch = _firestore.batch();
    batch.set(messageRef, message.toMap());
    batch.update(conversationRef, updates);
    await batch.commit();
    return messageRef.id;
  }

  Future<String> sendVoiceMessage({
    required String conversationId,
    required String senderId,
    required List<String> otherParticipantIds,
    required String audioUrl,
    required int durationSeconds,
  }) async {
    final conversationRef = _conversationsRef.doc(conversationId);
    final messageRef = conversationRef.collection('messages').doc();

    final message = MessageModel(
      id: messageRef.id,
      senderId: senderId,
      type: MessageType.voice,
      mediaUrl: audioUrl,
      durationSeconds: durationSeconds,
    );

    final updates = <String, dynamic>{
      'lastMessageId': messageRef.id,
      'lastMessageText': '🎤 Voice message',
      'lastMessageSenderId': senderId,
      'lastMessageTime': FieldValue.serverTimestamp(),
    };
    for (final uid in otherParticipantIds) {
      updates['unreadCount.$uid'] = FieldValue.increment(1);
    }

    final batch = _firestore.batch();
    batch.set(messageRef, message.toMap());
    batch.update(conversationRef, updates);
    await batch.commit();
    return messageRef.id;
  }

  Future<void> markAsSeen({
    required String conversationId,
    required String currentUid,
  }) async {
    final messagesRef = _conversationsRef.doc(conversationId).collection('messages');
    final fromOthers = await messagesRef.where('senderId', isNotEqualTo: currentUid).get();
    final unseen = fromOthers.docs.where((doc) => doc.data()['status'] != 'seen').toList();

    if (unseen.isEmpty) {
      await _conversationsRef.doc(conversationId).update({
        'unreadCount.$currentUid': 0,
      });
      return;
    }

    final batch = _firestore.batch();
    for (final doc in unseen) {
      batch.update(doc.reference, {
        'status': 'seen',
        'seenBy': FieldValue.arrayUnion([currentUid]),
      });
    }
    batch.update(_conversationsRef.doc(conversationId), {
      'unreadCount.$currentUid': 0,
    });
    await batch.commit();
  }
  /// Marks a specific message as delivered — only if it's currently
  /// still "sent" (never downgrades a message that's already "seen").
  Future<void> markMessageDelivered({
    required String conversationId,
    required String messageId,
  }) async {
    final messageRef =
    _conversationsRef.doc(conversationId).collection('messages').doc(messageId);
    final doc = await messageRef.get();
    if (!doc.exists) return;
    if (doc.data()?['status'] == 'sent') {
      await messageRef.update({'status': 'delivered'});
    }
  }

  Future<void> setTyping({
    required String conversationId,
    required String uid,
    required bool isTyping,
  }) async {
    await _conversationsRef
        .doc(conversationId)
        .collection('typingStatus')
        .doc(uid)
        .set({'isTyping': isTyping, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Stream<bool> watchOtherUserTyping({
    required String conversationId,
    required String otherUid,
  }) {
    return _conversationsRef
        .doc(conversationId)
        .collection('typingStatus')
        .doc(otherUid)
        .snapshots()
        .map((doc) => doc.data()?['isTyping'] as bool? ?? false);
  }

  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newText,
  }) async {
    await _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'text': newText, 'isEdited': true});
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'isDeleted': true, 'text': null, 'mediaUrl': null});
  }

  Future<MessageModel?> getMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final doc = await _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .get();
    if (!doc.exists) return null;
    return MessageModel.fromMap(doc.data()!, doc.id);
  }

  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String uid,
    required String emoji,
  }) async {
    final messageRef =
    _conversationsRef.doc(conversationId).collection('messages').doc(messageId);
    final doc = await messageRef.get();
    if (!doc.exists) return;

    final reactions = Map<String, dynamic>.from(doc.data()?['reactions'] as Map? ?? {});
    if (reactions[uid] == emoji) {
      reactions.remove(uid);
    } else {
      reactions[uid] = emoji;
    }
    await messageRef.update({'reactions': reactions});
  }

  Future<List<MessageModel>> searchMessages({
    required String conversationId,
    required String query,
  }) async {
    if (query.trim().isEmpty) return [];
    final snapshot = await _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();

    final lowerQuery = query.trim().toLowerCase();
    return snapshot.docs
        .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
        .where((m) => !m.isDeleted && (m.text?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }

  Future<void> pinMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final messagesRef = _conversationsRef.doc(conversationId).collection('messages');
    final currentlyPinned = await messagesRef.where('isPinned', isEqualTo: true).get();

    final batch = _firestore.batch();
    for (final doc in currentlyPinned.docs) {
      batch.update(doc.reference, {'isPinned': false});
    }
    batch.update(messagesRef.doc(messageId), {'isPinned': true});
    await batch.commit();
  }

  Future<void> unpinMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'isPinned': false});
  }

  Stream<MessageModel?> watchPinnedMessage(String conversationId) {
    return _conversationsRef
        .doc(conversationId)
        .collection('messages')
        .where('isPinned', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
        ? null
        : MessageModel.fromMap(snap.docs.first.data(), snap.docs.first.id));
  }

  Future<void> toggleStar({
    required String conversationId,
    required String messageId,
    required String uid,
  }) async {
    final messageRef =
    _conversationsRef.doc(conversationId).collection('messages').doc(messageId);
    final doc = await messageRef.get();
    if (!doc.exists) return;

    final starredBy = List<String>.from(doc.data()?['starredBy'] as List? ?? []);
    if (starredBy.contains(uid)) {
      starredBy.remove(uid);
    } else {
      starredBy.add(uid);
    }
    await messageRef.update({'starredBy': starredBy});
  }

  Future<List<MessageModel>> getStarredMessages(String uid) async {
    final snapshot = await _firestore
        .collectionGroup('messages')
        .where('starredBy', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => MessageModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<ConversationModel> createGroup({
    required String groupName,
    required String creatorUid,
    required Map<String, Map<String, String>> membersMeta,
  }) async {
    final docRef = _conversationsRef.doc();
    final unreadCount = <String, int>{};
    for (final uid in membersMeta.keys) {
      unreadCount[uid] = 0;
    }

    final conversation = ConversationModel(
      id: docRef.id,
      participantIds: membersMeta.keys.toList(),
      participantsMeta: membersMeta,
      unreadCount: unreadCount,
      type: 'group',
      groupName: groupName,
      adminIds: [creatorUid],
    );
    await docRef.set(conversation.toMap());
    return conversation;
  }

  Future<void> addGroupMembers({
    required String conversationId,
    required Map<String, Map<String, String>> newMembersMeta,
  }) async {
    final updates = <String, dynamic>{};
    for (final entry in newMembersMeta.entries) {
      updates['participantsMeta.${entry.key}'] = entry.value;
      updates['unreadCount.${entry.key}'] = 0;
    }
    updates['participantIds'] = FieldValue.arrayUnion(newMembersMeta.keys.toList());
    await _conversationsRef.doc(conversationId).update(updates);
  }

  Future<void> removeGroupMember({
    required String conversationId,
    required String uid,
  }) async {
    await _conversationsRef.doc(conversationId).update({
      'participantIds': FieldValue.arrayRemove([uid]),
      'adminIds': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> makeGroupAdmin({
    required String conversationId,
    required String uid,
  }) async {
    await _conversationsRef.doc(conversationId).update({
      'adminIds': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> updateGroupInfo({
    required String conversationId,
    String? groupName,
    String? groupPhotoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (groupName != null) updates['groupName'] = groupName;
    if (groupPhotoUrl != null) updates['groupPhotoUrl'] = groupPhotoUrl;
    if (updates.isEmpty) return;
    await _conversationsRef.doc(conversationId).update(updates);
  }
}