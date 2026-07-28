// lib/shared/widgets/fly_to_cart_overlay.dart
//
// The Blinkit/Zepto "fly to cart" micro-interaction: a small clone of the
// tapped product arcs from wherever "Add"/"+" was pressed toward the
// bottom-nav cart icon. Targets the bottom nav (not the floating cart bar
// in catalog_screen.dart) because the nav icon is always mounted — the
// floating bar is hidden on exactly the moment this matters most, the very
// first add to an empty cart.

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_spacing.dart';

/// Stable for the shell's lifetime — attached to the bottom nav's cart icon
/// in `CustomerHomeShell`, read from wherever an add-to-cart tap happens so
/// the flight has a target regardless of which grid/tile triggered it.
final cartIconKeyProvider = Provider<GlobalKey>((ref) => GlobalKey());

/// Launches the flight from [sourceContext]'s render box toward [targetKey].
/// Quietly no-ops if either render box isn't laid out yet (e.g. mid
/// route-transition) rather than throwing.
void flyToCart({
  required BuildContext sourceContext,
  required GlobalKey targetKey,
  String? imageUrl,
}) {
  final overlay = Overlay.maybeOf(sourceContext);
  final sourceBox = sourceContext.findRenderObject() as RenderBox?;
  final targetBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
  if (overlay == null || sourceBox == null || targetBox == null) return;
  if (!sourceBox.attached || !targetBox.attached) return;

  final start = sourceBox.localToGlobal(sourceBox.size.center(Offset.zero));
  final end = targetBox.localToGlobal(targetBox.size.center(Offset.zero));

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyingItem(
      start: start,
      end: end,
      imageUrl: imageUrl,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _FlyingItem extends StatefulWidget {
  final Offset start;
  final Offset end;
  final String? imageUrl;
  final VoidCallback onDone;

  const _FlyingItem({
    required this.start,
    required this.end,
    required this.imageUrl,
    required this.onDone,
  });

  @override
  State<_FlyingItem> createState() => _FlyingItemState();
}

class _FlyingItemState extends State<_FlyingItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 36.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInCubic.transform(_controller.value);
        final dx = widget.start.dx + (widget.end.dx - widget.start.dx) * t;
        final straightY = widget.start.dy + (widget.end.dy - widget.start.dy) * t;
        // A thrown arc, not a straight slide: peaks partway through the flight.
        final arc = -math.sin(t * math.pi) * 80;
        final scale = 1.0 - (t * 0.55);
        final opacity = 1.0 - (t * 0.85);

        return Positioned(
          left: dx - size / 2,
          top: straightY + arc - size / 2,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale.clamp(0.0, 1.0),
              child: _Thumbnail(imageUrl: widget.imageUrl, size: size),
            ),
          ),
        );
      },
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const _Thumbnail({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final imageUrl = this.imageUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? const Icon(Icons.shopping_basket, size: AppIconSize.sm)
          : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
    );
  }
}
