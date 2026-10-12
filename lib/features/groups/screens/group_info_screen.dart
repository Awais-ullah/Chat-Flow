import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../chats/models/conversation_model.dart';
import '../../chats/repository/chat_repository.dart';
import '../../chats/screens/chat_list_screen.dart';
import '../../users/models/user_model.dart';
import 'add_members_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String conversationId;

  const GroupInfoScreen({super.key, required this.conversationId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _chatRepository = ChatRepository();

  Future<void> _editGroupName(BuildContext context, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Group name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _chatRepository.updateGroupInfo(
        conversationId: widget.conversationId,
        groupName: result,
      );
    }
  }

  Future<void> _addMembers(BuildContext context, ConversationModel conversation) async {
    final picked = await Navigator.of(context).push<List<UserModel>>(
      MaterialPageRoute(
        builder: (_) => AddMembersScreen(existingMemberIds: conversation.participantIds),
      ),
    );
    if (picked == null || picked.isEmpty) return;

    final membersMeta = <String, Map<String, String>>{
      for (final user in picked)
        user.uid: {'name': user.displayName, 'photoUrl': user.photoUrl ?? ''},
    };
    await _chatRepository.addGroupMembers(
      conversationId: widget.conversationId,
      newMembersMeta: membersMeta,
    );
  }

  void _showMemberOptions(
      BuildContext context, {
        required String memberUid,
        required String memberName,
        required bool memberIsAdmin,
      }) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!memberIsAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Make admin'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _chatRepository.makeGroupAdmin(
                      conversationId: widget.conversationId,
                      uid: memberUid,
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
                title: Text('Remove $memberName', style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _chatRepository.removeGroupMember(
                    conversationId: widget.conversationId,
                    uid: memberUid,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _leaveGroup(BuildContext context, String currentUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text('You will no longer receive messages from this group.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _chatRepository.removeGroupMember(
        conversationId: widget.conversationId,
        uid: currentUid,
      );
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ChatListScreen()),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<AuthCubit>().state.user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Group Info')),
      body: StreamBuilder<ConversationModel>(
        stream: _chatRepository.watchConversation(widget.conversationId),
        builder: (context, snapshot) {
          final conversation = snapshot.data;
          if (conversation == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final isCurrentUserAdmin = conversation.adminIds.contains(currentUid);

          return SafeArea(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: (conversation.groupPhotoUrl != null &&
                            conversation.groupPhotoUrl!.isNotEmpty)
                            ? NetworkImage(conversation.groupPhotoUrl!)
                            : null,
                        child: (conversation.groupPhotoUrl == null ||
                            conversation.groupPhotoUrl!.isEmpty)
                            ? const Icon(Icons.group, size: 40)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            conversation.groupName ?? 'Group',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (isCurrentUserAdmin)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () =>
                                  _editGroupName(context, conversation.groupName ?? ''),
                            ),
                        ],
                      ),
                      Text(
                        '${conversation.participantIds.length} members',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (isCurrentUserAdmin)
                  ListTile(
                    leading: const Icon(Icons.person_add_outlined),
                    title: const Text('Add members'),
                    onTap: () => _addMembers(context, conversation),
                  ),
                ...conversation.participantIds.map((uid) {
                  final meta = conversation.participantsMeta[uid];
                  final name = meta?['name'] ?? 'Unknown';
                  final photo = meta?['photoUrl'];
                  final isAdmin = conversation.adminIds.contains(uid);
                  final isSelf = uid == currentUid;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                      (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
                      child: (photo == null || photo.isEmpty)
                          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text(isSelf ? '$name (You)' : name),
                    subtitle: isAdmin ? const Text('Admin') : null,
                    onTap: (isCurrentUserAdmin && !isSelf)
                        ? () => _showMemberOptions(
                      context,
                      memberUid: uid,
                      memberName: name,
                      memberIsAdmin: isAdmin,
                    )
                        : null,
                  );
                }),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text('Leave group', style: TextStyle(color: Colors.red)),
                  onTap: () => _leaveGroup(context, currentUid),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}