import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../models/message_model.dart';
import '../repository/chat_repository.dart';

class StarredMessagesScreen extends StatelessWidget {
  const StarredMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthCubit>().state.user?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Starred Messages')),
      body: FutureBuilder<List<MessageModel>>(
        future: ChatRepository().getStarredMessages(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final messages = snapshot.data ?? [];
          if (messages.isEmpty) {
            return const Center(child: Text('No starred messages yet'));
          }
          return ListView.separated(
            itemCount: messages.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final message = messages[index];
              return ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: Text(
                  message.text ?? '📷 Photo',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  message.createdAt != null
                      ? DateFormat.yMMMd().add_Hm().format(message.createdAt!)
                      : '',
                ),
              );
            },
          );
        },
      ),
    );
  }
}