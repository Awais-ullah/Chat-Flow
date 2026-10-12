import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../users/cubit/user_cubit.dart';
import '../../users/models/user_model.dart';
import '../../users/repository/user_repository.dart';
import '../../chats/repository/chat_repository.dart';
import '../../chats/screens/chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _groupNameController = TextEditingController();
  final _searchController = TextEditingController();
  final _userRepository = UserRepository();

  List<UserModel> _searchResults = [];
  final Map<String, UserModel> _selectedMembers = {};
  bool _isSearching = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final currentUid = context.read<AuthCubit>().state.user?.uid;
    if (currentUid == null || query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await _userRepository.searchUsersByName(query, excludeUid: currentUid);
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _toggleMember(UserModel user) {
    setState(() {
      if (_selectedMembers.containsKey(user.uid)) {
        _selectedMembers.remove(user.uid);
      } else {
        _selectedMembers[user.uid] = user;
      }
    });
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }
    if (_selectedMembers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 other members')),
      );
      return;
    }

    final currentUid = context.read<AuthCubit>().state.user?.uid;
    final currentProfile = context.read<UserCubit>().state.profile;
    if (currentUid == null || currentProfile == null) return;

    setState(() => _isCreating = true);

    final membersMeta = <String, Map<String, String>>{
      currentUid: {
        'name': currentProfile.displayName,
        'photoUrl': currentProfile.photoUrl ?? '',
      },
    };
    for (final user in _selectedMembers.values) {
      membersMeta[user.uid] = {
        'name': user.displayName,
        'photoUrl': user.photoUrl ?? '',
      };
    }

    try {
      final conversation = await ChatRepository().createGroup(
        groupName: groupName,
        creatorUid: currentUid,
        membersMeta: membersMeta,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversation.id,
              otherUserId: '',
              otherUserName: groupName,
              otherUserPhoto: null,
              isGroup: true,
              groupParticipantIds: _selectedMembers.keys.toList(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Group'),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createGroup,
            child: _isCreating
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Create'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            if (_selectedMembers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedMembers.values.map((user) {
                    return Chip(
                      label: Text(user.displayName),
                      onDeleted: () => _toggleMember(user),
                    );
                  }).toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search people to add',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _search,
              ),
            ),
            if (_isSearching) const LinearProgressIndicator(),
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  final isSelected = _selectedMembers.containsKey(user.uid);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (_) => _toggleMember(user),
                    secondary: CircleAvatar(
                      backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                          ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text(user.displayName),
                    subtitle: Text(user.email),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}