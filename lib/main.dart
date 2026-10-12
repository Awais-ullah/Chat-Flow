import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'firebase_options.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'core/services/supabase_config.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'features/auth/repository/auth_repository.dart';
import 'features/users/repository/user_repository.dart';
import 'features/users/cubit/user_cubit.dart';
import 'features/chats/repository/chat_repository.dart';
import 'features/home/screens/auth_gate.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final conversationId = message.data['conversationId'];
  final messageId = message.data['messageId'];
  if (conversationId != null && messageId != null) {
    try {
      await ChatRepository().markMessageDelivered(
        conversationId: conversationId,
        messageId: messageId,
      );
    } catch (e) {
      // ignore: avoid_print
      print('markMessageDelivered (background) failed: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    Supabase.initialize(url: SupabaseConfig.projectUrl, anonKey: SupabaseConfig.anonKey),
  ]);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Attach navigator key globally to Zego
  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);

  // Enable Zego CallKit / Fullscreen System UI for incoming calls
  ZegoUIKit().initLog().then((value) {
    ZegoUIKitPrebuiltCallInvitationService().useSystemCallingUI(
      [ZegoUIKitSignalingPlugin()],
    );

    runApp(const ChatFlowApp());
  });

  NotificationService().initialize();
}

class ChatFlowApp extends StatelessWidget {
  const ChatFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(
          create: (_) => AuthCubit(
            authRepository: AuthRepository(),
            userRepository: UserRepository(),
          ),
        ),
        BlocProvider(create: (_) => UserCubit(userRepository: UserRepository())),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'ChatFlow',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}