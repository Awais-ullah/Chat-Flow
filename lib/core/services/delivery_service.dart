import 'dart:async';
import '../../features/chats/models/conversation_model.dart';
import '../../features/chats/repository/chat_repository.dart';

/// Runs for the ENTIRE time the user is logged in (not just while a
/// specific chat is open) — watches all of the user's conversations,
/// and the instant a new incoming message shows up, marks it
/// "delivered". This means delivered status updates as soon as the
/// recipient's device is online and connected, regardless of which
/// screen they're currently looking at.
class DeliveryManager {
  DeliveryManager._();
  static final DeliveryManager instance = DeliveryManager._();

  final ChatRepository _chatRepository = ChatRepository();
  StreamSubscription<List<ConversationModel>>? _subscription;
  String? _currentUid;
  final Set<String> _alreadyHandled = {}; // avoids redundant writes per messageId

  void start(String uid) {
    stop();
    _currentUid = uid;
    _subscription = _chatRepository.watchConversations(uid).listen((conversations) {
      for (final convo in conversations) {
        final lastMessageId = convo.lastMessageId;
        final lastSenderId = convo.lastMessageSenderId;
        if (lastMessageId == null || lastSenderId == null) continue;
        if (lastSenderId == uid) continue; // don't mark our own messages
        if (_alreadyHandled.contains(lastMessageId)) continue;

        _alreadyHandled.add(lastMessageId);
        _chatRepository.markMessageDelivered(
          conversationId: convo.id,
          messageId: lastMessageId,
        );
      }
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _currentUid = null;
    _alreadyHandled.clear();
  }
}