import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls our Supabase Edge Function to deliver a push notification to a
/// specific device via Firebase Cloud Messaging. The function ALSO marks
/// the message as "delivered" in Firestore server-side, the moment the
/// push is successfully dispatched — this works even if the receiver's
/// app is closed or suspended by battery optimization, unlike a
/// client-side approach that depends on their app actively running.
class PushNotificationApi {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> sendPush({
    required String receiverToken,
    required String title,
    required String body,
    required String conversationId,
    required String messageId,
  }) async {
    try {
      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'token': receiverToken,
          'title': title,
          'body': body,
          'conversationId': conversationId,
          'messageId': messageId,
        },
      );
    } catch (e) {
      // ignore: avoid_print
      print('Push notification failed: $e');
    }
  }
}