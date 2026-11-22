class SupabaseConfig {
  SupabaseConfig._();

  // Supply these at build time; never put a Supabase secret key in the app.
  static const String url = String.fromEnvironment('SUPABASE_URL');
  // The existing build variable contains the Supabase publishable key.
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String bucketName = 'worker-proof-videos';
  static const String profilePhotoBucketName = 'profile-photos';

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
