// lib/core/env.dart
//
// Reads Supabase credentials passed in at build/run time via --dart-define,
// so your real keys never sit as plain text inside a file that goes into git.
//
// Run the app locally with:
//   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=your_anon_key
//
// Or, easier for daily use, create a local (git-ignored) script — see run_dev.sh.

class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID');

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing Supabase config. Run the app with --dart-define=SUPABASE_URL=... '
        'and --dart-define=SUPABASE_ANON_KEY=... (see run_dev.sh).',
      );
    }
  }
}