import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../groups/screens/create_group_screen.dart';
import '../../users/models/user_model.dart';
import '../../users/repository/user_repository.dart';
import '../../users/screens/my_profile_screen.dart';
import '../../users/screens/search_users_screen.dart';
import '../cubit/chat_list_cubit.dart';
import '../repository/chat_repository.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  void _showNewChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_outlined),
                title: const Text('New Chat'),
                subtitle: const Text('Message one person'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchUsersScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('New Group'),
                subtitle: const Text('Message multiple people at once'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<AuthCubit>().state.user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatFlow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'My Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Find People',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchUsersScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewChatOptions(context),
        tooltip: 'New Chat or Group',
        child: const Icon(Icons.add_comment_outlined),
      ),
      body: BlocProvider(
        create: (_) => ChatListCubit(chatRepository: ChatRepository())..watch(currentUid),
        child: BlocBuilder<ChatListCubit, ChatListState>(
          builder: (context, state) {
            if (state.status == ChatListStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == ChatListStatus.error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Something went wrong loading your chats.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            context.read<ChatListCubit>().watch(currentUid),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final conversations = state.conversations;
            if (conversations.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No conversations yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start chatting with someone',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SearchUsersScreen()),
                        ),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('Find People'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final convo = conversations[index];
                final storedName = convo.displayName(currentUid);
                final storedPhoto = convo.displayPhoto(currentUid);
                final unread = convo.unreadCount[currentUid] ?? 0;
                final otherUid = convo.isGroup ? '' : convo.otherUserId(currentUid);

                // For 1:1 chats, prefer LIVE profile data over the
                // conversation's stored (denormalized) copy, since the
                // stored copy is only ever written once and goes stale
                // if the other person later changes their name/photo.
                return StreamBuilder<UserModel?>(
                  stream: convo.isGroup ? null : UserRepository().watchUser(otherUid),
                  builder: (context, snapshot) {
                    final liveUser = snapshot.data;
                    final displayName =
                    (!convo.isGroup && liveUser != null) ? liveUser.displayName : storedName;
                    final displayPhoto =
                    (!convo.isGroup && liveUser != null) ? liveUser.photoUrl : storedPhoto;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (displayPhoto != null && displayPhoto.isNotEmpty)
                            ? NetworkImage(displayPhoto)
                            : null,
                        child: (displayPhoto == null || displayPhoto.isEmpty)
                            ? (convo.isGroup
                            ? const Icon(Icons.group)
                            : Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?'))
                            : null,
                      ),
                      title: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        convo.lastMessageText ?? 'Say hello 👋',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: unread > 0
                          ? CircleAvatar(
                        radius: 11,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          '$unread',
                          style: const TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      )
                          : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            conversationId: convo.id,
                            otherUserId: otherUid,
                            otherUserName: displayName,
                            otherUserPhoto: displayPhoto,
                            isGroup: convo.isGroup,
                            groupParticipantIds: convo.isGroup
                                ? convo.participantIds.where((id) => id != currentUid).toList()
                                : null,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}