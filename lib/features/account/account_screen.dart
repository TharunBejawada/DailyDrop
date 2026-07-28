// lib/features/account/account_screen.dart
//
// The "Account" tab inside CustomerHomeShell. Guests get a sign-in prompt;
// signed-in users get their identity plus sign-out (moved here from the old
// app-bar icon now that Orders/Account are dedicated tabs).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../cart/cart_provider.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final user = supabase.auth.currentUser;

    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline, size: AppIconSize.hero, color: semantic.mutedText),
              const SizedBox(height: AppSpacing.lg),
              Text('You\'re browsing as a guest', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sign in to track orders and save delivery addresses.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: semantic.mutedText),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: AppIconSize.xl,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.person_outline,
                  size: AppIconSize.lg, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(user.email ?? 'Signed in', style: theme.textTheme.titleMedium),
                  Text('DailyDrop customer',
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: semantic.mutedText)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton.tonalIcon(
          onPressed: () => _confirmSignOut(context, ref),
          icon: const Icon(Icons.logout_outlined, size: AppIconSize.md),
          label: const Text('Sign out'),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your cart will be cleared when you sign out.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authServiceProvider).signOut();
      ref.read(cartProvider.notifier).clear();
    }
  }
}
