// lib/features/onboarding/onboarding_screen.dart
//
// First-run carousel shown to logged-out users before they land on the
// guest catalog (see RootRouter). Copy deliberately matches this app's real
// fulfillment model (same-day delivery for groceries AND fruit/veg) rather
// than borrowing a generic "10-minute delivery" quick-commerce claim that
// wouldn't be true here.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import 'onboarding_provider.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String message;
  const _Slide({required this.icon, required this.title, required this.message});
}

const _slides = [
  _Slide(
    icon: Icons.storefront_rounded,
    title: 'Your daily grocery run,\ndelivered',
    message: 'Everyday groceries picked and dropped at your door the same day.',
  ),
  _Slide(
    icon: Icons.eco_rounded,
    title: 'Fresh produce,\nsame speed as groceries',
    message: 'Fruits & vegetables delivered the same day — no more waiting until tomorrow.',
  ),
  _Slide(
    icon: Icons.shopping_cart_checkout_rounded,
    title: 'Browse now,\npay when ready',
    message: 'No account needed to explore the store — sign in only at checkout.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(onboardingOverrideProvider.notifier).state = true;
    markOnboardingSeen();
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: AppMotion.normal, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm, top: AppSpacing.xs),
                child: TextButton(
                  onPressed: isLast ? null : _finish,
                  child: Text(
                    'Skip',
                    style: TextStyle(color: isLast ? Colors.transparent : semantic.mutedText),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _SlideView(
                  key: ValueKey('onboarding-slide-$i'),
                  slide: _slides[i],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: AppMotion.normal,
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                          height: AppSpacing.xs,
                          width: i == _page ? AppSpacing.xl : AppSpacing.xs,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? theme.colorScheme.primary
                                : semantic.trackInactive,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(isLast ? 'Get started' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemantic.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 132,
            width: 132,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.72),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: AppIconSize.hero, color: theme.colorScheme.onPrimary),
          )
              .animate()
              .fadeIn(duration: AppMotion.slow, curve: Curves.easeOut)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: AppMotion.slow,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ).animate(delay: AppMotion.fast).fadeIn(duration: AppMotion.normal).slideY(
                begin: 0.15,
                end: 0,
                duration: AppMotion.normal,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: semantic.mutedText),
          ).animate(delay: AppMotion.normal).fadeIn(duration: AppMotion.normal),
        ],
      ),
    );
  }
}
