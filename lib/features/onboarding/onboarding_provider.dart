// lib/features/onboarding/onboarding_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingSeenKey = 'has_seen_onboarding';

/// Persisted "has this device seen onboarding" flag, checked once at launch.
final onboardingSeenProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_onboardingSeenKey) ?? false;
});

/// In-memory override so RootRouter can move past onboarding the instant
/// "Get Started" is tapped, without waiting on [onboardingSeenProvider] to
/// re-fetch from disk.
final onboardingOverrideProvider = StateProvider<bool>((ref) => false);

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_onboardingSeenKey, true);
}
