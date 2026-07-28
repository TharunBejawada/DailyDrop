// lib/features/auth/auth_service.dart
//
// Thin wrapper around Supabase Auth. Screens call these methods; nothing
// here manages UI state, that stays in the screens themselves.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthService {
  /// Creates the auth user (email/password), then fills in the profile
  /// fields (full name via signUp metadata, phone via a follow-up update —
  /// see supabase_schema.sql's handle_new_user trigger for why phone needs
  /// this extra step when using email-based signup).
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final res = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    final user = res.user;
    if (user != null) {
      await supabase.from('profiles').update({'phone': phone}).eq('id', user.id);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}