import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../models/user_model.dart';
import '../repository/user_repository.dart';
import 'user_profile_screen.dart';

/// Lets the current user search for other registered users by name.
class SearchUsersScreen extends StatefulWidget {
  /// When true, tapping a result returns that user via Navigator.pop
  /// instead of opening their profile — used for the "Forward to..." flow.
  final bool selectMode;

  const SearchUsersScreen({super.key, this.selectMode = false});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final _controller = TextEditingController();
  final _userRepository = UserRepository();

  List<UserModel> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final currentUid = context.read<AuthCubit>().state.user?.uid;
    if (currentUid == null) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final results = await _userRepository.searchUsersByName(query, excludeUid: currentUid);

    if (!mounted) return;
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by name...',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_controller.text),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasSearched) {
      return const Center(child: Text('Search for someone to start chatting'));
    }
    if (_results.isEmpty) {
      return const Center(child: Text('No users found'));
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = _results[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null ? Text(user.displayName[0].toUpperCase()) : null,
          ),
          title: Text(user.displayName),
          subtitle: Text(user.email),
          onTap: () {
            if (widget.selectMode) {
              Navigator.of(context).pop(user);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)),
              );
            }
          },

        );
      },
    );
  }
}