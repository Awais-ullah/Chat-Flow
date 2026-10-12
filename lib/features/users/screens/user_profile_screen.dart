import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../chats/repository/chat_repository.dart';
import '../../chats/screens/chat_screen.dart';
import '../cubit/user_cubit.dart';
import '../models/user_model.dart';
import '../repository/user_repository.dart';


/// Shows another user's profile and allows starting a chat.
class UserProfileScreen extends StatelessWidget {
  final UserModel user;

  const UserProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(user.displayName)),
      body: StreamBuilder<UserModel?>(
        // Live stream so online/last-seen status updates in real time
        // while this screen is open.
        stream: UserRepository().watchUser(user.uid),
        initialData: user,
        builder: (context, snapshot) {
          final liveUser = snapshot.data ?? user;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage:
                    liveUser.photoUrl != null ? NetworkImage(liveUser.photoUrl!) : null,
                    child: liveUser.photoUrl == null
                        ? Text(
                      liveUser.displayName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 32),
                    )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(liveUser.displayName, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    liveUser.isActuallyOnline
                        ? 'Online'
                        : liveUser.lastSeen != null
                        ? 'Last seen recently'
                        : '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (liveUser.bio != null && liveUser.bio!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('About', style: Theme.of(context).textTheme.labelLarge),
                    ),
                    const SizedBox(height: 4),
                    Text(liveUser.bio!),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _startConversation(context, liveUser),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _startConversation(BuildContext context, UserModel otherUser) async {
    final authState = context.read<AuthCubit>().state;
    final currentUid = authState.user?.uid;
    if (currentUid == null) return;

    // Try the cached profile first (fast path). If it isn't ready yet
    // (e.g. right after login, before UserCubit's stream has emitted),
    // fall back to fetching it directly instead of silently giving up.
    var currentProfile = context.read<UserCubit>().state.profile;
    currentProfile ??= await UserRepository().getUser(currentUid);

    if (currentProfile == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load your profile. Please try again.')),
        );
      }
      return;
    }

    try {
      final conversation = await ChatRepository().getOrCreateDirectConversation(
        currentUid: currentUid,
        currentName: currentProfile.displayName,
        currentPhotoUrl: currentProfile.photoUrl,
        otherUid: otherUser.uid,
        otherName: otherUser.displayName,
        otherPhotoUrl: otherUser.photoUrl,
      );

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversation.id,
              otherUserId: otherUser.uid,
              otherUserName: otherUser.displayName,
              otherUserPhoto: otherUser.photoUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start chat: $e')),
        );
      }
    }
  }
}