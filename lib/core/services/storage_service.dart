import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// All direct Supabase Storage calls live here — keeps Supabase-specific
/// code out of the UI and out of the Firestore-facing repositories.
class StorageService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Uploads a profile picture and returns its public URL.
  /// [uid] is used to name the file so re-uploading always replaces
  /// the same file instead of piling up unused old ones.
  Future<String> uploadAvatar({required String uid, required File file}) async {
    final fileExt = file.path.split('.').last;
    final filePath = '$uid/profile.$fileExt';

    await _client.storage.from('avatars').upload(
      filePath,
      file,
      fileOptions: const FileOptions(upsert: true), // upsert = overwrite if it already exists
    );

    return _client.storage.from('avatars').getPublicUrl(filePath);
  }

  /// Uploads a chat media file (image/video/file) and returns its URL.
  /// [conversationId] and [messageId] keep files organized and unique.
  Future<String> uploadChatMedia({
    required String conversationId,
    required String messageId,
    required File file,
  }) async {
    final fileExt = file.path.split('.').last;
    final filePath = '$conversationId/$messageId.$fileExt';

    await _client.storage.from('chat-media').upload(filePath, file);

    // chat-media is a private bucket, so instead of a permanent public URL,
    // we create a signed URL — a link that works for a limited time.
    // 604800 seconds = 7 days. We'll refresh these as needed later.
    return await _client.storage.from('chat-media').createSignedUrl(filePath, 604800);
  }
}