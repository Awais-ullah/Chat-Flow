import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../../core/services/storage_service.dart';
import '../../chats/screens/starred_messages_screen.dart';
import '../cubit/user_cubit.dart';
import '../cubit/user_state.dart';
import '../repository/user_repository.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final _storageService = StorageService();
  final _userRepository = UserRepository();
  bool _isUploading = false;

  Future<void> _pickAndUploadAvatar() async {
    final uid = context.read<AuthCubit>().state.user?.uid;
    if (uid == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return; // user cancelled

    setState(() => _isUploading = true);
    try {
      final url = await _storageService.uploadAvatar(uid: uid, file: File(picked.path));
      await _userRepository.updateProfile(uid: uid, photoUrl: url);
      // UserCubit's live watchProfile stream will pick up the new photoUrl automatically.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: BlocBuilder<UserCubit, UserState>(
        builder: (context, state) {
          final profile = state.profile;
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        // Cache-busting: appending the current time as a
                        // dummy query parameter makes Flutter treat this
                        // as a "new" URL whenever the photo changes, even
                        // though the underlying Supabase file path is
                        // reused (upsert). Without this, Flutter's image
                        // cache keeps showing the OLD photo until the
                        // app is fully restarted.
                        backgroundImage:
                        (profile.photoUrl != null && profile.photoUrl!.isNotEmpty)
                            ? NetworkImage(
                            '${profile.photoUrl!}?t=${DateTime.now().millisecondsSinceEpoch}')
                            : null,
                        child: (profile.photoUrl == null || profile.photoUrl!.isEmpty)
                            ? Text(
                          profile.displayName.isNotEmpty
                              ? profile.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 40),
                        )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _isUploading ? null : _pickAndUploadAvatar,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: _isUploading
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(profile.displayName, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(profile.email, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  ListTile(
                    leading: const Icon(Icons.star_border),
                    title: const Text('Starred Messages'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StarredMessagesScreen()),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}