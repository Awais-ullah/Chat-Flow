import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:video_compress/video_compress.dart';
import '../../../core/services/push_notification_api.dart';
import '../../../core/services/storage_service.dart';
import '../../users/repository/user_repository.dart';
import '../models/message_model.dart';
import '../repository/chat_repository.dart';

/// A locally-picked file that's currently uploading — rendered as a
/// placeholder bubble with a spinner while in flight, then removed once
/// the real message shows up via the Firestore stream.
class PendingUpload {
  final String id;
  final File file;
  final MessageType type;
  PendingUpload({required this.id, required this.file, required this.type});
}

class ChatCubit extends Cubit<List<MessageModel>> {
  final ChatRepository _chatRepository;
  final StorageService _storageService;
  final String conversationId;
  final String currentUid;
  final String otherUserId;
  final List<String> otherParticipantIds;
  StreamSubscription<List<MessageModel>>? _subscription;

  final PushNotificationApi _pushApi = PushNotificationApi();
  final UserRepository _userRepository = UserRepository();
  final ValueNotifier<List<PendingUpload>> pendingUploads =
  ValueNotifier<List<PendingUpload>>([]);

  ChatCubit({
    required ChatRepository chatRepository,
    required this.conversationId,
    required this.currentUid,
    required this.otherUserId,
    required this.otherParticipantIds,
    StorageService? storageService,
  })  : _chatRepository = chatRepository,
        _storageService = storageService ?? StorageService(),
        super([]) {
    _subscription = _chatRepository.watchMessages(conversationId).listen((messages) {
      emit(messages);
      // Re-run on every new snapshot (not just once at open) — otherwise
      // a message that arrives WHILE the chat is already open never gets
      // marked seen until the user leaves and re-enters the screen.
      _chatRepository.markAsSeen(conversationId: conversationId, currentUid: currentUid);
    });
  }

  Future<void> sendMessage({
    required String text,
    String? replyToMessageId,
  }) async {
    if (text.trim().isEmpty) return;
    final messageId = await _chatRepository.sendMessage(
      conversationId: conversationId,
      senderId: currentUid,
      otherParticipantIds: otherParticipantIds,
      text: text.trim(),
      replyToMessageId: replyToMessageId,
    );
    for (final uid in otherParticipantIds) {
      _notifyReceiver(receiverId: uid, body: text.trim(), messageId: messageId);
    }
  }

  Future<void> sendImage({required File imageFile}) async {
    final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    pendingUploads.value = [
      ...pendingUploads.value,
      PendingUpload(id: tempMessageId, file: imageFile, type: MessageType.image),
    ];
    try {
      final imageUrl = await _storageService.uploadChatMedia(
        conversationId: conversationId,
        messageId: tempMessageId,
        file: imageFile,
      );
      final messageId = await _chatRepository.sendImageMessage(
        conversationId: conversationId,
        senderId: currentUid,
        otherParticipantIds: otherParticipantIds,
        imageUrl: imageUrl,
      );
      for (final uid in otherParticipantIds) {
        _notifyReceiver(receiverId: uid, body: '📷 Photo', messageId: messageId);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Image send failed: $e');
      rethrow;
    } finally {
      pendingUploads.value =
          pendingUploads.value.where((p) => p.id != tempMessageId).toList();
    }
  }

  Future<void> sendVideo({required File videoFile}) async {
    final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    pendingUploads.value = [
      ...pendingUploads.value,
      PendingUpload(id: tempMessageId, file: videoFile, type: MessageType.video),
    ];
    try {
      // Re-encode to H.264 before upload. Some phones record video in
      // HEVC/H.265, which not every device can play back — this
      // conversion guarantees the video plays on ANY phone, and also
      // shrinks the file size along the way.
      File uploadFile = videoFile;
      try {
        final info = await VideoCompress.compressVideo(
          videoFile.path,
          quality: VideoQuality.MediumQuality,
          includeAudio: true,
        );
        if (info?.file != null) {
          uploadFile = info!.file!;
        }
      } catch (e) {
        // ignore: avoid_print
        print('Video compression failed, sending original file: $e');
        // Falls back to the original file rather than blocking the send
        // entirely — worse compatibility odds, but not a hard failure.
      }

      final videoUrl = await _storageService.uploadChatMedia(
        conversationId: conversationId,
        messageId: tempMessageId,
        file: uploadFile,
      );

      // Generate a real preview frame from the video so the chat bubble
      // shows an actual thumbnail instead of a plain black box. If this
      // fails for any reason, the video still sends — thumbnailUrl just
      // stays null and the bubble falls back to black (handled in the UI).
      String? thumbnailUrl;
      try {
        final thumbBytes = await VideoThumbnail.thumbnailData(
          video: uploadFile.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 400,
          quality: 60,
        );
        if (thumbBytes != null) {
          final dir = await getTemporaryDirectory();
          final thumbFile = File('${dir.path}/thumb_$tempMessageId.jpg');
          await thumbFile.writeAsBytes(thumbBytes);
          thumbnailUrl = await _storageService.uploadChatMedia(
            conversationId: conversationId,
            messageId: '${tempMessageId}_thumb',
            file: thumbFile,
          );
        }
      } catch (e) {
        // ignore: avoid_print
        print('Video thumbnail generation failed (non-blocking): $e');
      }

      final messageId = await _chatRepository.sendVideoMessage(
        conversationId: conversationId,
        senderId: currentUid,
        otherParticipantIds: otherParticipantIds,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
      );
      for (final uid in otherParticipantIds) {
        _notifyReceiver(receiverId: uid, body: '🎥 Video', messageId: messageId);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Video send failed: $e');
      rethrow;
    } finally {
      pendingUploads.value =
          pendingUploads.value.where((p) => p.id != tempMessageId).toList();
    }
  }

  Future<void> sendVoice({required File audioFile, required int durationSeconds}) async {
    final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    pendingUploads.value = [
      ...pendingUploads.value,
      PendingUpload(id: tempMessageId, file: audioFile, type: MessageType.voice),
    ];
    try {
      final audioUrl = await _storageService.uploadChatMedia(
        conversationId: conversationId,
        messageId: tempMessageId,
        file: audioFile,
      );
      final messageId = await _chatRepository.sendVoiceMessage(
        conversationId: conversationId,
        senderId: currentUid,
        otherParticipantIds: otherParticipantIds,
        audioUrl: audioUrl,
        durationSeconds: durationSeconds,
      );
      for (final uid in otherParticipantIds) {
        _notifyReceiver(receiverId: uid, body: '🎤 Voice message', messageId: messageId);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Voice send failed: $e');
      rethrow;
    } finally {
      pendingUploads.value =
          pendingUploads.value.where((p) => p.id != tempMessageId).toList();
    }
  }

  Future<void> editMessage({required String messageId, required String newText}) async {
    if (newText.trim().isEmpty) return;
    await _chatRepository.editMessage(
      conversationId: conversationId,
      messageId: messageId,
      newText: newText.trim(),
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _chatRepository.deleteMessage(conversationId: conversationId, messageId: messageId);
  }

  Future<MessageModel?> getMessage(String messageId) {
    return _chatRepository.getMessage(conversationId: conversationId, messageId: messageId);
  }

  Future<void> toggleReaction({required String messageId, required String emoji}) async {
    await _chatRepository.toggleReaction(
      conversationId: conversationId,
      messageId: messageId,
      uid: currentUid,
      emoji: emoji,
    );
  }

  Future<List<MessageModel>> searchMessages(String query) {
    return _chatRepository.searchMessages(conversationId: conversationId, query: query);
  }

  Future<void> pinMessage(String messageId) {
    return _chatRepository.pinMessage(conversationId: conversationId, messageId: messageId);
  }

  Future<void> unpinMessage(String messageId) {
    return _chatRepository.unpinMessage(conversationId: conversationId, messageId: messageId);
  }

  Stream<MessageModel?> watchPinnedMessage() {
    return _chatRepository.watchPinnedMessage(conversationId);
  }

  Future<void> toggleStar(String messageId) {
    return _chatRepository.toggleStar(
      conversationId: conversationId,
      messageId: messageId,
      uid: currentUid,
    );
  }

  void updateTypingStatus(bool isTyping) {
    _chatRepository.setTyping(
      conversationId: conversationId,
      uid: currentUid,
      isTyping: isTyping,
    );
  }

  Stream<bool> watchOtherUserTyping() {
    return _chatRepository.watchOtherUserTyping(
      conversationId: conversationId,
      otherUid: otherUserId,
    );
  }

  Future<void> _notifyReceiver({
    required String receiverId,
    required String body,
    required String messageId,
  }) async {
    final receiver = await _userRepository.getUser(receiverId);
    final sender = await _userRepository.getUser(currentUid);
    if (receiver?.fcmToken == null) return;

    await _pushApi.sendPush(
      receiverToken: receiver!.fcmToken!,
      title: sender?.displayName ?? 'New message',
      body: body,
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  @override
  Future<void> close() {
    updateTypingStatus(false);
    _subscription?.cancel();
    pendingUploads.dispose();
    return super.close();
  }
}