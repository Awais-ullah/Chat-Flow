import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/conversation_model.dart';
import '../repository/chat_repository.dart';

enum ChatListStatus { loading, loaded, error }

class ChatListState extends Equatable {
  final ChatListStatus status;
  final List<ConversationModel> conversations;

  const ChatListState({
    this.status = ChatListStatus.loading,
    this.conversations = const [],
  });

  ChatListState copyWith({ChatListStatus? status, List<ConversationModel>? conversations}) {
    return ChatListState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
    );
  }

  @override
  List<Object?> get props => [status, conversations];
}

class ChatListCubit extends Cubit<ChatListState> {
  final ChatRepository _chatRepository;
  StreamSubscription<List<ConversationModel>>? _subscription;

  ChatListCubit({required ChatRepository chatRepository})
      : _chatRepository = chatRepository,
        super(const ChatListState());

  void watch(String uid) {
    _subscription?.cancel();
    _subscription = _chatRepository.watchConversations(uid).listen(
          (conversations) {
        emit(state.copyWith(status: ChatListStatus.loaded, conversations: conversations));
      },
      onError: (_) => emit(state.copyWith(status: ChatListStatus.error)),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}