// lib/core/auth_guard.dart
//
// Guest browsing means catalog access no longer implies a session. Any
// action that actually needs a user (checkout, order history) should call
// requireLogin() first instead of assuming supabase.auth.currentSession.

import 'package:flutter/material.dart';
import 'supabase_client.dart';
import '../features/auth/login_screen.dart';

/// Returns true immediately if already signed in. Otherwise pushes
/// [LoginScreen] and returns whether the user completed sign-in — false if
/// they backed out.
Future<bool> requireLogin(BuildContext context) async {
  if (supabase.auth.currentSession != null) return true;

  final signedIn = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
  return signedIn ?? false;
}
