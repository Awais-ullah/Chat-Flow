import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import '../../../core/services/delivery_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/services/zego_config.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/screens/login_screen.dart';
import 'dart:async';
import '../../chats/screens/chat_list_screen.dart';
import '../../users/cubit/user_cubit.dart';
import '../../users/repository/user_repository.dart';
import 'splash_screen.dart';

/// Sits directly under MaterialApp and lives for the ENTIRE app session.
/// Unlike the old approach (SplashScreen navigating away once and then
/// being removed from the tree), this widget is never unmounted, so it
/// can react to AuthCubit's state changing at any point in the app's
/// life — including right after a successful registration, no matter
/// which screen the user happens to be on at that moment.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _lastHandledUid;
  StreamSubscription<String>? _tokenRefreshSubscription;

  Future<void> _runLoginSideEffects(String uid, String displayName) async {
    // Guard: only run these once per uid, not on every rebuild while
    // still authenticated as the same user.
    if (_lastHandledUid == uid) return;
    _lastHandledUid = uid;

    context.read<UserCubit>().watchProfile(uid);
    PresenceManager.instance.start(uid);
    DeliveryManager.instance.start(uid);

    try {
      final token = await NotificationService().getToken();
      if (token != null) {
        await UserRepository().saveFcmToken(uid: uid, token: token);
      }
      // Keep listening for future token changes (app updates, reinstalls,
      // periodic rotation) and re-save automatically — without this, an
      // old saved token can silently go stale and pushes stop arriving
      // until the user fully logs out and back in.
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          NotificationService().onTokenRefresh.listen((newToken) {
            UserRepository().saveFcmToken(uid: uid, token: newToken);
          });
    } catch (e) {
      // ignore: avoid_print
      print('FCM token save failed (non-blocking): $e');
    }

    try {
      await ZegoUIKitPrebuiltCallInvitationService().init(
        appID: ZegoConfig.appID,
        appSign: ZegoConfig.appSign,
        userID: uid,
        userName: displayName,
        plugins: [ZegoUIKitSignalingPlugin()],
        requireConfig: (ZegoCallInvitationData data) {
          final isVideoCall = data.type == ZegoCallInvitationType.videoCall.value;
          final config = isVideoCall
              ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
              : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();
          // Video calls default to loudspeaker (matches how people actually
          // use video calls); voice calls default to earpiece, same as a
          // normal phone call. Either can still be toggled manually
          // in-call via the speaker button.
          config.turnOnCameraWhenJoining = isVideoCall;
          config.useSpeakerWhenJoining = isVideoCall;
          return config;
        },
      );
    } catch (e) {
      // ignore: avoid_print
      print('ZEGOCLOUD init failed (non-blocking): $e');
    }
  }

  void _handleLogout() {
    _lastHandledUid = null;
    _tokenRefreshSubscription?.cancel();
    context.read<UserCubit>().stopWatching();
    PresenceManager.instance.stop();
    DeliveryManager.instance.stop();
    try {
      ZegoUIKitPrebuiltCallInvitationService().uninit();
    } catch (_) {}
  }

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      // Only rebuild the visible screen when the STATUS changes or the
      // logged-in user actually changes (different uid). Ignore other
      // AuthState emissions — e.g. Firebase's periodic token refresh,
      // which fires on the same logged-in user and would otherwise
      // tear down and recreate the whole Chat List screen for no reason.
      buildWhen: (previous, current) {
        return previous.status != current.status ||
            previous.user?.uid != current.user?.uid;
      },
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated && state.user != null) {
          final profile = context.read<UserCubit>().state.profile;
          final displayName = profile?.displayName ?? state.user!.email ?? 'User';
          _runLoginSideEffects(state.user!.uid, displayName);

          // Clear away any screens pushed on top (e.g. RegisterScreen,
          // pushed from LoginScreen) so the ChatListScreen we're about
          // to show underneath actually becomes visible, instead of
          // staying hidden behind whatever screen the user was on.
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else if (state.status == AuthStatus.unauthenticated) {
          _handleLogout();
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.authenticated:
            return const ChatListScreen();
          case AuthStatus.unauthenticated:
          case AuthStatus.error:
            return const LoginScreen();
          case AuthStatus.unknown:
          case AuthStatus.loading:
            return const SplashScreen();
        }
      },
    );
  }
}