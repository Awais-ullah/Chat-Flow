import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../users/models/user_model.dart';
import '../../users/repository/user_repository.dart';

class AddMembersScreen extends StatefulWidget {
  final List<String> existingMemberIds;

  const AddMembersScreen({super.key, required this.existingMemberIds});

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final _searchController = TextEditingController();
  final _userRepository = UserRepository();
  List<UserModel> _searchResults = [];
  final Map<String, UserModel> _selected = {};
  bool _isSearching = false;

  @override
  void dispose() {
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
      _searchResults = results.where((u) => !widget.existingMemberIds.contains(u.uid)).toList();
      _isSearching = false;
    });
  }

  void _toggle(UserModel user) {
    setState(() {
      if (_selected.containsKey(user.uid)) {
        _selected.remove(user.uid);
      } else {
        _selected[user.uid] = user;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Members'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(_selected.values.toList()),
            child: const Text('Add'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                  final isSelected = _selected.containsKey(user.uid);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (_) => _toggle(user),
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