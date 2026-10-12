/// Supabase project configuration.
///
/// The anon/public key below is SAFE to be visible in client code —
/// it is designed for this purpose (similar to a Firebase apiKey).
/// The service_role/secret key must NEVER be placed here or anywhere
/// in this Flutter app.
class SupabaseConfig {
  SupabaseConfig._();

  static const String projectUrl = 'https://msxdkbbawysczzjnaole.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zeGRrYmJhd3lzY3p6am5hb2xlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg1NDAwNDcsImV4cCI6MjEwNDExNjA0N30.EtdCXu25n7YumPNg_8qgMFrhv4zfewQvdB93VPLdBGg';
}