import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../users/cubit/user_cubit.dart';
import '../../users/cubit/user_state.dart';
import '../../users/screens/search_users_screen.dart';

/// Temporary placeholder — replaced with the real bottom-nav shell
/// (Chats / Contacts / Profile / Settings) in a later phase.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChatFlow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchUsersScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlocBuilder<UserCubit, UserState>(
              builder: (context, state) {
                final name = state.profile?.displayName ?? '...';
                return Text('Welcome, $name 🎉', style: Theme.of(context).textTheme.titleMedium);
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<AuthCubit>().logout(),
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}