import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../groups/screens/group_info_screen.dart';
import '../../users/cubit/user_cubit.dart';
import '../../users/models/user_model.dart' as user_model;
import '../../users/repository/user_repository.dart';
import '../../users/screens/search_users_screen.dart';
import '../cubit/chat_cubit.dart';
import '../models/message_model.dart';
import '../repository/chat_repository.dart';
import 'video_player_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final bool isGroup;
  final List<String>? groupParticipantIds;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    this.isGroup = false,
    this.groupParticipantIds,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  bool _isCurrentlyTyping = false;
  MessageModel? _replyingTo;
  Map<String, Map<String, String>> _groupMembersMeta = {};

  late final String _currentUid;
  late final ChatCubit _chatCubit;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _currentUid = context.read<AuthCubit>().state.user?.uid ?? '';
    _chatCubit = ChatCubit(
      chatRepository: ChatRepository(),
      conversationId: widget.conversationId,
      currentUid: _currentUid,
      otherUserId: widget.otherUserId,
      otherParticipantIds:
      widget.isGroup ? (widget.groupParticipantIds ?? []) : [widget.otherUserId],
    );
    _messageController.addListener(_handleTypingChange);
    if (widget.isGroup) _loadGroupMembersMeta();
  }

  Future<void> _loadGroupMembersMeta() async {
    final doc = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .get();
    final data = doc.data();
    if (data == null || !mounted) return;
    final rawMeta = data['participantsMeta'] as Map<String, dynamic>? ?? {};
    setState(() {
      _groupMembersMeta =
          rawMeta.map((uid, value) => MapEntry(uid, Map<String, String>.from(value as Map)));
    });
  }

  String _groupMemberName(String uid) {
    return _groupMembersMeta[uid]?['name'] ?? 'Unknown';
  }

  void _handleTypingChange() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _isCurrentlyTyping) {
      _isCurrentlyTyping = hasText;
      _chatCubit.updateTypingStatus(hasText);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleTypingChange);
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _chatCubit.close();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;

    try {
      await _chatCubit.sendImage(imageFile: File(picked.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    try {
      await _chatCubit.sendVideo(videoFile: File(picked.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send video: $e')),
        );
      }
    }
  }
  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndSendImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Video'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndSendVideo();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record voice messages'),
          ),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(), path: path);

    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecordingAndSend() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    final duration = _recordDuration;

    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
    });

    if (path == null) return;

    if (duration.inSeconds < 1) {
      try {
        File(path).deleteSync();
      } catch (_) {}
      return;
    }

    try {
      await _chatCubit.sendVoice(audioFile: File(path), durationSeconds: duration.inSeconds);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e')),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();

    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
    });

    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
  }

  Future<void> _showEditDialog(BuildContext dialogContext, MessageModel message) async {
    final editController = TextEditingController(text: message.text);
    final result = await showDialog<String>(
      context: dialogContext,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: TextField(
            controller: editController,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, editController.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (result != null && result.trim().isNotEmpty) {
      _chatCubit.editMessage(messageId: message.id, newText: result);
    }
  }

  Future<void> _confirmDelete(BuildContext dialogContext, MessageModel message) async {
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete message?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      _chatCubit.deleteMessage(message.id);
    }
  }
  Future<void> _saveMediaToDevice(MessageModel message) async {
    if (message.mediaUrl == null) return;
    try {
      final response = await http.get(Uri.parse(message.mediaUrl!));
      if (response.statusCode != 200) throw Exception('Download failed');

      if (message.type == MessageType.image) {
        await Gal.putImageBytes(response.bodyBytes);
      } else if (message.type == MessageType.video) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/save_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await file.writeAsBytes(response.bodyBytes);
        await Gal.putVideo(file.path);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to device')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _forwardMessage(BuildContext forwardContext, MessageModel message) async {
    final picked = await Navigator.of(forwardContext).push<user_model.UserModel>(
      MaterialPageRoute(builder: (_) => const SearchUsersScreen(selectMode: true)),
    );
    if (picked == null || !mounted) return;

    final currentProfile = forwardContext.read<UserCubit>().state.profile;
    if (currentProfile == null) return;

    final conversation = await ChatRepository().getOrCreateDirectConversation(
      currentUid: _currentUid,
      currentName: currentProfile.displayName,
      currentPhotoUrl: currentProfile.photoUrl,
      otherUid: picked.uid,
      otherName: picked.displayName,
      otherPhotoUrl: picked.photoUrl,
    );

    if (message.type == MessageType.image && message.mediaUrl != null) {
      await ChatRepository().sendImageMessage(
        conversationId: conversation.id,
        senderId: _currentUid,
        otherParticipantIds: [picked.uid],
        imageUrl: message.mediaUrl!,
      );
    } else {
      await ChatRepository().sendMessage(
        conversationId: conversation.id,
        senderId: _currentUid,
        otherParticipantIds: [picked.uid],
        text: message.text ?? '',
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(forwardContext).showSnackBar(
        SnackBar(content: Text('Forwarded to ${picked.displayName}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _chatCubit,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 64,
          actions: [
            if (widget.isGroup && _groupMembersMeta.isNotEmpty)
              ZegoSendCallInvitationButton(
                isVideoCall: true,
                resourceID: 'chatflow_group_call',
                invitees: _groupMembersMeta.entries
                    .where((e) => e.key != FirebaseAuth.instance.currentUser?.uid)
                    .map((e) => ZegoUIKitUser(id: e.key, name: e.value['name'] ?? 'Unknown'))
                    .toList(),
                icon: ButtonIcon(
                  icon: const Icon(Icons.videocam, color: Colors.black87),
                  backgroundColor: Colors.transparent,
                ),
                text: '', // hide the text label — icon-only, so it doesn't crowd out the title
                buttonSize: const Size(40, 40),
                iconSize: const Size(24, 24),
              ),
            if (!widget.isGroup) ...[
              ZegoSendCallInvitationButton(
                isVideoCall: false,
                resourceID: 'chatflow_call',
                invitees: [ZegoUIKitUser(id: widget.otherUserId, name: widget.otherUserName)],
                icon: ButtonIcon(
                  icon: const Icon(Icons.call, color: Colors.black87),
                  backgroundColor: Colors.transparent,
                ),
                text: '',
                buttonSize: const Size(40, 40),
                iconSize: const Size(22, 22),
              ),
              ZegoSendCallInvitationButton(
                isVideoCall: true,
                resourceID: 'chatflow_call',
                invitees: [ZegoUIKitUser(id: widget.otherUserId, name: widget.otherUserName)],
                icon: ButtonIcon(
                  icon: const Icon(Icons.videocam, color: Colors.black87),
                  backgroundColor: Colors.transparent,
                ),
                text: '',
                buttonSize: const Size(40, 40),
                iconSize: const Size(24, 24),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => showSearch(
                context: context,
                delegate: _MessageSearchDelegate(chatCubit: _chatCubit),
              ),
            ),
          ],
          title: InkWell(
            onTap: widget.isGroup
                ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GroupInfoScreen(conversationId: widget.conversationId),
              ),
            )
                : null,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: (widget.otherUserPhoto != null &&
                      widget.otherUserPhoto!.isNotEmpty)
                      ? NetworkImage(widget.otherUserPhoto!)
                      : null,
                  child: (widget.otherUserPhoto == null || widget.otherUserPhoto!.isEmpty)
                      ? Icon(widget.isGroup ? Icons.group : Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: widget.isGroup
                      ? Text(
                    widget.otherUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  )
                      : StreamBuilder<user_model.UserModel?>(
                    stream: UserRepository().watchUser(widget.otherUserId),
                    builder: (context, snapshot) {
                      final otherUser = snapshot.data;
                      final subtitle = otherUser == null
                          ? ''
                          : otherUser.isActuallyOnline
                          ? 'Online'
                          : 'Offline';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.otherUserName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontSize: 12),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              StreamBuilder<MessageModel?>(
                stream: _chatCubit.watchPinnedMessage(),
                builder: (context, snapshot) {
                  final pinned = snapshot.data;
                  if (pinned == null) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Row(
                      children: [
                        const Icon(Icons.push_pin, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pinned.text ?? '📷 Photo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => _chatCubit.unpinMessage(pinned.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (!widget.isGroup)
                StreamBuilder<bool>(
                  stream: _chatCubit.watchOtherUserTyping(),
                  builder: (context, snapshot) {
                    final isTyping = snapshot.data ?? false;
                    if (!isTyping) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${widget.otherUserName} is typing...',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                    );
                  },
                ),
              Expanded(
                child: ValueListenableBuilder<List<PendingUpload>>(
                  valueListenable: _chatCubit.pendingUploads,
                  builder: (context, pending, _) {
                    return BlocBuilder<ChatCubit, List<MessageModel>>(
                      builder: (context, messages) {
                        if (messages.isEmpty && pending.isEmpty) {
                          return const Center(child: Text('Say hello 👋'));
                        }
                        final totalCount = pending.length + messages.length;
                        return ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: totalCount,
                          itemBuilder: (context, index) {
                            if (index < pending.length) {
                              return _PendingUploadBubble(upload: pending[index]);
                            }
                            final message = messages[index - pending.length];
                            final isMe = message.senderId == _currentUid;
                            return _MessageBubble(
                              message: message,
                              isMe: isMe,
                              currentUid: _currentUid,
                              showSenderName: widget.isGroup && !isMe,
                              senderName:
                              widget.isGroup ? _groupMemberName(message.senderId) : null,
                              onReply: () => setState(() => _replyingTo = message),
                              onEdit: () => _showEditDialog(context, message),
                              onDelete: () => _confirmDelete(context, message),
                              onReact: (emoji) => _chatCubit
                                  .toggleReaction(messageId: message.id, emoji: emoji),
                              onForward: () => _forwardMessage(context, message),
                              onTogglePin: () => message.isPinned
                                  ? _chatCubit.unpinMessage(message.id)
                                  : _chatCubit.pinMessage(message.id),
                              onToggleStar: () => _chatCubit.toggleStar(message.id),
                              onSaveMedia: () => _saveMediaToDevice(message),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              if (_replyingTo != null)
                _ReplyPreviewBar(
                  message: _replyingTo!,
                  onCancel: () => setState(() => _replyingTo = null),
                ),
              _isRecording
                  ? _RecordingBar(
                duration: _recordDuration,
                onCancel: _cancelRecording,
                onSend: _stopRecordingAndSend,
              )
                  : _MessageInputBar(
                controller: _messageController,
                onSend: () {
                  final text = _messageController.text;
                  if (text.trim().isEmpty) return;
                  _chatCubit.sendMessage(text: text, replyToMessageId: _replyingTo?.id);
                  _messageController.clear();
                  setState(() => _replyingTo = null);
                },
                onPickImage: () => _showAttachmentOptions(context),
                onStartRecording: _startRecording,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  final Duration duration;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const _RecordingBar({
    required this.duration,
    required this.onCancel,
    required this.onSend,
  });

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: onCancel,
          ),
          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Recording... ${_format(duration)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: Icon(Icons.send_rounded, color: Theme.of(context).colorScheme.primary),
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
class _PendingUploadBubble extends StatelessWidget {
  final PendingUpload upload;

  const _PendingUploadBubble({required this.upload});

  @override
  Widget build(BuildContext context) {
    // Voice messages get a small, compact bubble matching the shape of
    // a real voice message bubble — NOT the large photo/video preview
    // box, which was the actual bug (voice was falling into the same
    // "else" branch as video).
    if (upload.type == MessageType.voice) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 10),
              Icon(Icons.mic, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Sending voice message...', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: const BoxConstraints(maxHeight: 260, maxWidth: 220),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (upload.type == MessageType.image)
                Image.file(upload.file, fit: BoxFit.cover)
              else
                Container(color: Colors.black87),
              Container(color: Colors.black26),
              const Center(child: CircularProgressIndicator(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyPreviewBar extends StatelessWidget {
  final MessageModel message;
  final VoidCallback onCancel;

  const _ReplyPreviewBar({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message.isDeleted ? 'Original message deleted' : (message.text ?? '📷 Photo'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onCancel),
        ],
      ),
    );
  }
}

class _QuotedReply extends StatelessWidget {
  final String messageId;

  const _QuotedReply({required this.messageId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MessageModel?>(
      future: context.read<ChatCubit>().getMessage(messageId),
      builder: (context, snapshot) {
        final original = snapshot.data;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            original == null
                ? '...'
                : original.isDeleted
                ? 'Original message deleted'
                : (original.text ?? '📷 Photo'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }
}

class _VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final int durationSeconds;
  final bool isMe;

  const _VoiceMessageBubble({
    required this.audioUrl,
    required this.durationSeconds,
    required this.isMe,
  });

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.audioUrl));
    }
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = Duration(seconds: widget.durationSeconds);
    final progress =
    total.inMilliseconds == 0 ? 0.0 : _position.inMilliseconds / total.inMilliseconds;
    final color = widget.isMe ? Colors.white : Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: 200,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: color,
              size: 32,
            ),
            onPressed: _toggle,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: color.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPlaying ? _format(_position) : _format(total),
                  style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String currentUid;
  final bool showSenderName;
  final String? senderName;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onReact;
  final VoidCallback onForward;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleStar;
  final VoidCallback? onSaveMedia;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.currentUid,
    this.showSenderName = false,
    this.senderName,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReact,
    required this.onForward,
    required this.onTogglePin,
    required this.onToggleStar,
    this.onSaveMedia,
  });

  static const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onReply();
                },
              ),
              if (isMe && !message.isDeleted && message.type == MessageType.text) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onEdit();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onDelete();
                  },
                ),
              ],
              if (!message.isDeleted) ...[
                ListTile(
                  leading: const Icon(Icons.forward_outlined),
                  title: const Text('Forward'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onForward();
                  },
                ),
                if (onSaveMedia != null &&
                    (message.type == MessageType.image || message.type == MessageType.video))
                  ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: const Text('Save to device'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onSaveMedia!();
                    },
                  ),
                ListTile(
                  leading: Icon(message.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                  title: Text(message.isPinned ? 'Unpin' : 'Pin'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onTogglePin();
                  },
                ),
                ListTile(
                  leading: Icon(
                    message.starredBy.contains(currentUid) ? Icons.star : Icons.star_border,
                  ),
                  title: Text(message.starredBy.contains(currentUid) ? 'Unstar' : 'Star'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onToggleStar();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showReactionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              children: _quickReactions.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onReact(emoji);
                  },
                  child: Text(emoji, style: const TextStyle(fontSize: 32)),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  String _summarizeReactions() {
    final counts = <String, int>{};
    for (final emoji in message.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts.entries.map((e) => '${e.key} ${e.value}').join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isMe ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final textColor = isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color;
    // Media-only bubbles get a thin border instead of the thicker
    // text-bubble padding.
    final isMediaOnly = !message.isDeleted &&
        (message.type == MessageType.image || message.type == MessageType.video) &&
        message.replyToMessageId == null;
    final bubblePadding = isMediaOnly
        ? const EdgeInsets.all(4)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);

    return GestureDetector(
      onLongPress: message.isDeleted ? null : () => _showOptions(context),
      onDoubleTap: message.isDeleted ? null : () => _showReactionPicker(context),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: bubblePadding,
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSenderName && senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        senderName!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  if (message.isDeleted)
                    Text(
                      'This message was deleted',
                      style: TextStyle(
                        color: textColor?.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    )
                  else ...[
                    if (message.replyToMessageId != null)
                      _QuotedReply(messageId: message.replyToMessageId!),
                    if (message.type == MessageType.image && message.mediaUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 260,
                            maxWidth: 220,
                          ),
                          child: AspectRatio(
                            aspectRatio: 3 / 4,
                            child: Image.network(
                              message.mediaUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (message.type == MessageType.video && message.mediaUrl != null)
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerScreen(videoUrl: message.mediaUrl!),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 260, maxWidth: 220),
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (message.thumbnailUrl != null)
                                    Image.network(
                                      message.thumbnailUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(color: Colors.black87),
                                    )
                                  else
                                    Container(color: Colors.black87),
                                  const Center(
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (message.type == MessageType.voice && message.mediaUrl != null)
                        _VoiceMessageBubble(
                          audioUrl: message.mediaUrl!,
                          durationSeconds: message.durationSeconds ?? 0,
                          isMe: isMe,
                        )
                      else
                        Text(
                          message.text ?? '',
                          style: TextStyle(color: textColor, fontSize: 15),
                        ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isEdited && !message.isDeleted)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            'edited',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: (isMe ? Colors.white : textColor)?.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      Text(
                        message.createdAt != null
                            ? DateFormat.Hm().format(message.createdAt!)
                            : '',
                        style: TextStyle(
                          fontSize: 11,
                          color: (isMe ? Colors.white : textColor)?.withValues(alpha: 0.7),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isPending
                              ? Icons.access_time
                              : (message.status == MessageStatus.sent
                              ? Icons.done
                              : Icons.done_all),
                          size: 14,
                          color: message.status == MessageStatus.seen
                              ? Colors.lightBlueAccent
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (message.reactions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Text(_summarizeReactions(), style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onStartRecording;

  const _MessageInputBar({
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.onStartRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.image_outlined), onPressed: onPickImage),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Message',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(icon: const Icon(Icons.mic_none_outlined), onPressed: onStartRecording),
          IconButton(
            icon: const Icon(Icons.send_rounded),
            color: Theme.of(context).colorScheme.primary,
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}

class _MessageSearchDelegate extends SearchDelegate<void> {
  final ChatCubit chatCubit;

  _MessageSearchDelegate({required this.chatCubit});

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Type to search messages'));
    }
    return FutureBuilder<List<MessageModel>>(
      future: chatCubit.searchMessages(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(child: Text('No matching messages'));
        }
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final message = results[index];
            return ListTile(
              title: Text(message.text ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                message.createdAt != null
                    ? DateFormat.yMMMd().add_Hm().format(message.createdAt!)
                    : '',
              ),
            );
          },
        );
      },
    );
  }
}