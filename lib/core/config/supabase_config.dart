class SupabaseConfig {
  SupabaseConfig._();

  // Supply these at build time; never put a Supabase secret key in the app.
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String bucketName = 'worker-proof-videos';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
