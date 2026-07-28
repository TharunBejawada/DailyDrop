// lib/core/router.dart
//
// This is the "one app, two roles" piece: it watches the auth state,
// and once someone is logged in, checks their `role` in the profiles table
// (see supabase_schema.sql) to decide which screen tree to show.
//
// The actual login screen, customer catalog, and admin dashboard are built
// in later steps — for now this wires up the decision logic with clear
// placeholders, so the whole flow is testable end-to-end from day one.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import 'theme/app_spacing.dart';
import 'theme/app_theme.dart';
import '../features/home/customer_home_shell.dart';
import '../features/admin/admin_home_screen.dart';
import '../features/onboarding/onboarding_provider.dart';
import '../features/onboarding/onboarding_screen.dart';

class RootRouter extends ConsumerStatefulWidget {
  const RootRouter({super.key});

  @override
  ConsumerState<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends ConsumerState<RootRouter>
    with WidgetsBindingObserver {
  bool _hasBeenBackgrounded = false;
  bool _showResumeFlash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _hasBeenBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _hasBeenBackgrounded) {
      // Shortened version of the Phase 1 splash crossfade — just a quick
      // fade back in, not the full logo animation, since this is a resume
      // rather than a first launch.
      _hasBeenBackgrounded = false;
      setState(() => _showResumeFlash = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildRoutedContent(context),
        if (_showResumeFlash)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Theme.of(context).colorScheme.surface)
                  .animate(onComplete: (_) {
                if (mounted) setState(() => _showResumeFlash = false);
              }).fadeOut(duration: AppMotion.normal, curve: Curves.easeOut),
            ),
          ),
      ],
    );
  }

  Widget _buildRoutedContent(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (session == null) {
          // Guest browsing: show the first-run carousel once, then the
          // catalog directly — login is only required at checkout (see
          // requireLogin in core/auth_guard.dart).
          final seenAsync = ref.watch(onboardingSeenProvider);
          final override = ref.watch(onboardingOverrideProvider);

          final Widget child;
          final Key key;
          if (!seenAsync.hasValue) {
            // Still reading the persisted flag from disk — reuse the splash
            // rather than flashing onboarding then immediately skipping it.
            child = const _SplashScreen();
            key = const ValueKey('splash-initial');
          } else if (!(override || seenAsync.value!)) {
            child = const OnboardingScreen();
            key = const ValueKey('onboarding');
          } else {
            child = const CustomerHomeShell();
            key = const ValueKey('guest-catalog');
          }

          return AnimatedSwitcher(
            duration: AppMotion.normal,
            child: KeyedSubtree(key: key, child: child),
          );
        }

        // Logged in — figure out the role before deciding which UI to show.
        return FutureBuilder<Map<String, dynamic>?>(
          future: supabase
              .from('profiles')
              .select('role')
              .eq('id', session.user.id)
              .maybeSingle(), // returns null instead of erroring when 0 rows match
          builder: (context, roleSnapshot) {
            final Widget child;
            final Key key;

            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              child = const _SplashScreen();
              key = const ValueKey('splash');
            } else if (roleSnapshot.hasError) {
              child = _ErrorScreen(
                message: 'Could not load your account: ${roleSnapshot.error}',
              );
              key = const ValueKey('error-role');
            } else if (roleSnapshot.data == null) {
              // Auth user exists but no matching profiles row — the
              // handle_new_user trigger didn't create one. See the schema
              // setup step: check the profiles table and the trigger.
              child = const _ErrorScreen(
                message:
                    "We couldn't find your profile record. This usually means the "
                    "database's profile-creation trigger didn't run for this "
                    "account. Please check the profiles table in Supabase.",
              );
              key = const ValueKey('error-profile');
            } else if (roleSnapshot.data!['role'] as String == 'admin') {
              child = const AdminHomeScreen();
              key = const ValueKey('admin');
            } else {
              // Real customer home shell.
              child = const CustomerHomeShell();
              key = const ValueKey('customer');
            }

            return AnimatedSwitcher(
              duration: AppMotion.normal,
              child: KeyedSubtree(key: key, child: child),
            );
          },
        );
      },
    );
  }
}

/// Shown while the role lookup is in flight. Branded rather than a bare
/// spinner, because this is the very first frame a returning user sees.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.72),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Icon(
                Icons.storefront_outlined,
                size: AppIconSize.xl,
                color: theme.colorScheme.onPrimary,
              ),
            )
                .animate()
                .fadeIn(duration: AppMotion.slow, curve: Curves.easeOut)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: AppMotion.slow,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: AppSpacing.lg),
            Text('DailyDrop', style: theme.textTheme.titleLarge)
                .animate(delay: AppMotion.fast)
                .fadeIn(duration: AppMotion.normal),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: AppIconSize.md,
              width: AppIconSize.md,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: semantic.mutedText,
              ),
            )
                .animate(delay: AppMotion.normal)
                .fadeIn(duration: AppMotion.normal),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 88,
                    width: 88,
                    decoration: BoxDecoration(
                      color: semantic.danger.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: AppIconSize.hero,
                      color: semantic.danger,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    "We can't open your account",
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: semantic.mutedText),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    onPressed: () => supabase.auth.signOut(),
                    icon:
                        const Icon(Icons.logout_outlined, size: AppIconSize.md),
                    label: const Text('Sign out and try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
