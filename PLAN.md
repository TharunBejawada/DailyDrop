# Blinkit/Zepto-style Redesign Plan

Goal: bring the fast, physical, "quick-commerce" feel (snappy micro-interactions,
skeleton loading, fly-to-cart, animated status trackers) to the existing screen
flow without changing navigation structure, RLS-based queries, or the
`FutureProvider`/`StreamProvider`/invalidate-not-mutate state pattern documented
in CLAUDE.md.

**Dependency stance**: `pubspec.yaml` currently has zero animation packages —
everything today is default Material widgets. Prefer Flutter's built-in
implicit animations (`AnimatedContainer`, `AnimatedSwitcher`, `Hero`,
`AnimatedPositioned`, custom `AnimationController`s) before adding a package.
The one package worth adding is `shimmer` (^3.0, tiny, pure-Dart, web-safe) for
skeleton loading states — call this out explicitly in Phase 2 since it's the
only new dependency this plan proposes. Everything else (staggered lists,
fly-to-cart, status steppers) is achievable with core Flutter animation APIs
and keeps every phase working under `kIsWeb` without extra guards.

Each phase is independently shippable and testable in isolation via
`./run_dev.sh chrome`.

**Off-plan work done ahead of schedule**: implementing Phase 1's splash
surfaced that fruit/veg's next-morning pre-order model didn't match what
was wanted (should fulfill same-day like groceries), which cascaded into a
bottom-nav shell restructure matching real Blinkit/Zepto navigation
(`CustomerHomeShell`, mirroring `AdminHomeScreen`'s existing tab pattern).
This pulled pieces of Phases 2 and 4 forward — see the "implemented" notes
in those sections below for what's now done vs. still open. Orders no
longer split by product type either (see CLAUDE.md's `product_type`
section) — checkout creates one merged order per cart.

---

## Phase 1 — Splash & App Launch [implemented, expanded scope]

**Goal**: replace the static role-check spinner with a branded, animated
launch sequence so the auth/role lookup doesn't read as a blank stall.

**Scope grew beyond the original plan below**: testing surfaced that the
animated splash only ever rendered for users who were *already logged in*
(role lookup in flight) — a logged-out user hit `LoginScreen` directly and
never saw it. Fixing that turned into replicating the actual Blinkit/Zepto/
Instamart launch journey: splash → one-time onboarding carousel → **guest
catalog browsing** (no login required to browse), with login only enforced
at checkout/order-history via a new `requireLogin()` gate. Implemented:

- `lib/core/router.dart` — `RootRouter` is now a `ConsumerWidget`. The
  logged-out branch shows `_SplashScreen` while the persisted
  "seen onboarding" flag loads, then `OnboardingScreen` (first run only) or
  `CatalogScreen` as a guest, all crossfaded via the same `AnimatedSwitcher`
  pattern as the role-resolution branch.
- `lib/features/onboarding/onboarding_screen.dart`,
  `onboarding_provider.dart` — 3-slide carousel (copy matches this app's
  real fulfillment model: same-day grocery / next-morning fruit-veg, not a
  generic quick-commerce claim), `shared_preferences`-backed "seen" flag.
- `lib/core/auth_guard.dart` — `requireLogin(context)`: no-op if already
  signed in, otherwise pushes `LoginScreen` and returns whether sign-in
  succeeded.
- `lib/features/auth/login_screen.dart` — pops `true` on success when
  pushed (guest-gate case), in addition to its original root-level
  behavior (auth-stream-driven swap, no pop).
- `lib/features/catalog/catalog_screen.dart` — guest-aware app bar (a
  "Sign in" action replaces orders/sign-out when there's no session), and
  the checkout button now calls `requireLogin()` before pushing
  `CheckoutScreen`.

**Open item**: guest browsing means `catalogProvider`'s queries now run
under Postgres's `anon` role. This needs a public SELECT RLS policy on
`categories`/`products` in the live Supabase project — unverified from this
repo since the schema lives outside it (see CLAUDE.md). Without it, guest
catalog browsing will show an error state instead of products.

**Original Phase 1 scope** (still accurate, now just one part of the above):

- Animated logo/wordmark on `_SplashScreen` — fade+scale in on first frame
  (`AnimationController` + `FadeTransition`/`ScaleTransition`), not a bare
  `CircularProgressIndicator`.
- Crossfade transition from splash → `LoginScreen`/`CatalogScreen`/
  `AdminHomeScreen` once the role lookup resolves, via `AnimatedSwitcher`
  wrapping the `StreamBuilder` branch in `RootRouter`, instead of the current
  hard swap.
- Keep `_ErrorScreen`'s sign-out path untouched — no animation needed on an
  error/escape-hatch screen.

**Files touched**
- `lib/core/router.dart` — `_SplashScreen` widget, `RootRouter`'s branch
  `build()` (wrap in `AnimatedSwitcher`).
- `lib/main.dart` — only if the app icon/wordmark asset needs registering
  under `flutter: assets:` in `pubspec.yaml`.
- `pubspec.yaml` — add logo asset path if a static image/SVG is introduced.

---

## Phase 2 — Home / Browse (Catalog) [partially implemented]

**Goal**: the grid is the highest-traffic screen — this is where "quick
commerce" speed needs to be felt most.

**Already done** (pulled forward during the Phase 1 journey redesign):
a search field above the grocery/fruit-veg tabs (client-side filter over
the already-fetched `catalogProvider` data — `catalogSearchQueryProvider`
in `catalog_providers.dart`), and `CatalogScreen` itself was stripped of
its own `Scaffold`/`AppBar` to become `CustomerHomeShell`'s Home-tab body.
The floating cart bar now reads "View cart" and switches to the Cart tab
(`homeTabIndexProvider`) instead of pushing `CheckoutScreen` directly.
Everything below — skeletons, staggered grid entrance, fly-to-cart,
pull-to-refresh — is still open.

- Skeleton/shimmer grid while `catalogProvider` is loading, replacing the
  default `.when(loading: () => CircularProgressIndicator())` branch. Add
  `shimmer` package for this (see dependency note above).
- Staggered fade+slide-in for grid tiles on first load / tab switch
  (grocery ↔ fruit_veg), via a small reusable `StaggeredFadeIn` wrapper widget
  driven by tile index — no package needed, just delayed `AnimationController`s
  or `flutter_staggered_animations`-style manual delay per tile.
- Quantity stepper on each product tile gets a spring/bounce
  (`AnimatedScale` on tap-down) instead of an instant `+`/`-` value change.
- "Fly to cart" micro-animation: on add-to-cart tap, a small clone of the
  product image arcs from the tile toward the floating cart bar
  (`Overlay` + `AnimationController` driving a `Positioned` clone, removed on
  completion). This is the single most recognizable Zepto/Blinkit signature
  interaction.
- Floating cart bar at the bottom of `CatalogScreen` (replacing the current
  plain "Checkout" bar) animates its item-count/total in place
  (`AnimatedSwitcher` on the count text) and slides up from off-screen the
  first time the cart goes from empty → non-empty (`AnimatedSlide`), rather
  than being permanently visible.
- Pull-to-refresh on the grid (`RefreshIndicator` wrapping the `GridView`,
  calling `ref.invalidate(catalogProvider)`) — cheap addition, matches the
  category of app.

**Files touched**
- `lib/features/catalog/catalog_screen.dart` — grid loading branch, tile
  layout, floating cart bar, `RefreshIndicator`.
- `lib/features/catalog/catalog_providers.dart` — no logic change, just the
  provider being invalidated by pull-to-refresh.
- `lib/features/cart/cart_provider.dart` — no state-shape change; animations
  react to existing `totalItems`/`totalPrice` getters.
- `lib/shared/widgets/` — **NEW**: `shimmer_grid_tile.dart`,
  `fly_to_cart_overlay.dart`, `animated_quantity_stepper.dart` (extracted so
  Phase 3's detail view and Phase 4's cart can reuse the stepper).
- `pubspec.yaml` — add `shimmer: ^3.0.0`.

---

## Phase 3 — Product Detail

**Goal**: today there is no dedicated product-detail screen — the grid tile
*is* the whole interaction (image, name, price, stepper). Recommend adding a
lightweight **bottom sheet**, not a full pushed screen, so quick-add on the
grid stays the fast path and the detail view is opt-in (tap the image) —
matches how Zepto/Blinkit actually behave, not a traditional PDP.

- Tapping a product image opens `showModalBottomSheet` with a `Hero`-animated
  product image (shared `Hero` tag with the grid tile) expanding into the
  sheet — the single highest-impact "app feels expensive" animation available
  here for the effort.
- Sheet contents: larger image, name, unit, price, the same
  `AnimatedQuantityStepper` from Phase 2, drag-to-dismiss (native to
  `DraggableScrollableSheet`).
- Out-of-stock products (`is_available=false`, already excluded from
  `catalogProvider` results) — n/a for customer view; no change needed since
  unavailable products never reach the customer grid.

**Files touched**
- `lib/features/catalog/catalog_screen.dart` — wrap tile image in `Hero`, wire
  tap → `showModalBottomSheet`.
- `lib/features/catalog/` — **NEW**: `product_detail_sheet.dart`.
- `lib/shared/widgets/animated_quantity_stepper.dart` — reused from Phase 2.
- `lib/models/product.dart` — no change (existing fields are sufficient).

---

## Phase 4 — Cart [superseded by a full screen, not a sheet]

**Original goal** (superseded): there was no dedicated cart screen — the
floating bar pushed straight to `CheckoutScreen`. Keep that navigation
shape (per CLAUDE.md, no route table / minimal screens) but make the cart
*reviewable* before checkout via an expandable sheet rather than a new
pushed screen.

**What actually got built**: the bottom-nav restructure (see Phase 1's
notes) made a bottom-sheet review feel like the wrong shape — a persistent
"Cart" tab fits a bottom-nav shell better than a sheet you'd have to
re-trigger from the Home tab. `lib/features/cart/cart_screen.dart`
(`CartScreen`) is a full-page line-item review (quantity steppers reusing
`CartNotifier.add`/`remove`, empty state) living at tab index 1 in
`CustomerHomeShell`. Its "Proceed to checkout" button calls
`requireLogin()` before pushing `CheckoutScreen` — same gate used
everywhere else guest actions need auth. The animation ideas below
(`AnimatedList` row removal, staggered stepper) are still open, just
against this screen instead of a sheet.

- Tapping the floating cart bar's price/count area (not the "Checkout"
  action itself) expands a `DraggableScrollableSheet` cart review — line
  items with the same `AnimatedQuantityStepper`, animated row removal when a
  quantity hits 0 (`AnimatedList` or `SliverAnimatedList` keyed by product id,
  since `CartNotifier`'s state is a `Map<String, CartItem>` keyed by product
  id already — a natural fit for `AnimatedList`'s key-based diffing).
- Empty-cart state: if the last item is removed inside the sheet, animate the
  sheet collapsing shut rather than showing an empty list.
- "Checkout" button inside the sheet performs the existing
  `Navigator.push(CheckoutScreen)`.

**Files touched**
- `lib/features/cart/cart_provider.dart` — no state-shape change.
- `lib/features/cart/` — **NEW**: `cart_review_sheet.dart`.
- `lib/features/catalog/catalog_screen.dart` — wire floating bar tap →
  `showModalBottomSheet(CartReviewSheet)`.
- `lib/shared/widgets/animated_quantity_stepper.dart` — reused.

---

## Phase 5 — Checkout

**Goal**: checkout today is a single screen with an inline address dialog and
a blocking payment flow. Make the multi-step nature (address → slot → total →
pay) read as a sequence instead of a flat form.

- Delivery slot display (from `groceryDeliverySlot()`/`fruitVegDeliverySlot()`
  in `delivery_slot.dart`) gets a small animated countdown/badge when close to
  `fvCutoffHour` (21:00) — e.g. an `AnimatedContainer` color shift from
  neutral to warning as cutoff approaches, reusing the existing pure
  functions with no logic change.
- Address selector: replace the current dialog-only add-address flow's static
  list with an animated radio-card selection (`AnimatedContainer` border/
  elevation on selection) for existing addresses from `addressesProvider`.
- "Place order" button gets a loading-state morph (button → spinner → check
  mark) driven by the existing async `OrderService.placeOrder()` /
  `RazorpayService` flow — no change to the non-rollback payment semantics,
  purely visual state during the wait.
- Order-placed confirmation: replace the current `showDialog` with a
  full-bleed animated success state (checkmark draw-in via
  `AnimatedContainer`/`CustomPainter` or a simple `ScaleTransition` bounce) —
  still pops back to `CheckoutScreen` per existing behavior, or optionally
  now pops all the way to `CatalogScreen` and clears the cart (`clear()` on
  `CartNotifier`) as part of this phase, since today nothing clears the cart
  after a successful order — worth confirming with the user whether that's
  in scope here since it's a behavior change, not just visual.

**Files touched**
- `lib/features/checkout/checkout_screen.dart` — address selector UI, slot
  badge, button loading-state, confirmation UI.
- `lib/features/checkout/delivery_slot.dart` — no logic change (pure
  functions consumed as-is).
- `lib/features/checkout/order_service.dart` — only touched if cart-clear on
  success is added (calls `ref.read(cartProvider.notifier).clear()`).
- `lib/features/checkout/razorpay_service.dart` — only touched to surface
  intermediate payment states (`onPaymentSuccess`/`onPaymentError` callbacks)
  to the new button-morph UI; no change to the client-side-only trade-off.
- `lib/features/addresses/address_provider.dart` — no logic change.

---

## Phase 6 — Order Tracking

**Goal**: `orderStatusFlow` (`placed → confirmed → out_for_delivery →
delivered`, plus `cancelled`) already exists as a linear model in
`admin_order_service.dart` — this phase is purely about visualizing that
linear flow, both for customers and admin.

- `CustomerOrdersScreen`: each order card gets an animated horizontal stepper
  (dots/line connecting the 4 states, filled progressively) instead of a
  plain status text/chip. Drive it off the existing `orderStatusFlow` list so
  there's one source of truth for stage order.
- Realtime status change (`customerOrdersRealtimeProvider` firing on an
  `orders` UPDATE) animates the stepper advancing (`AnimatedContainer` fill +
  a brief pulse/glow on the newly-reached stage) rather than the list just
  silently re-rendering after `ref.invalidate`.
- `AdminOrdersScreen`: the "advance status" action button gets a pressed-state
  ripple/morph matching the customer-side stepper visuals, and new-order
  Realtime alerts (`newOrderAlertProvider`) upgrade from a plain `SnackBar` to
  a slide-in banner with a subtle bounce, still routing "View" to
  `_tabIndex = 0` unchanged.
- Cancelled state gets a distinct (not just red-text) treatment — e.g. a
  strikethrough-stepper or greyed-out variant of the same stepper widget, so
  cancellation reads as visually distinct rather than just another status
  string.

**Files touched**
- `lib/features/orders/customer_orders_screen.dart` — stepper UI, Realtime
  update animation.
- `lib/features/orders/customer_orders_provider.dart` — no logic change.
- `lib/features/orders/customer_orders_realtime.dart` — no logic change
  (still just invalidates + emits).
- `lib/features/admin/orders/admin_orders_screen.dart` — action button
  states, alert banner.
- `lib/features/admin/orders/admin_order_service.dart` — `orderStatusFlow` /
  `nextStatus()` reused as-is (single source of truth for the stepper).
- `lib/features/admin/orders/order_realtime_service.dart` — no logic change.
- `lib/shared/widgets/` — **NEW**: `order_status_stepper.dart` (shared
  between customer and admin screens).

---

## Phase 7 — App-close / Background State

**Goal**: nothing today observes app lifecycle — no reconnect banner, no
resume animation, no exit confirmation. Scope this phase to UI/animation only
(no cart-persistence or state-machine changes, since `CartNotifier` being
in-memory-only and cleared on restart is an explicit, documented design
choice in CLAUDE.md, not a bug to fix here).

- Add a `WidgetsBindingObserver` (likely on `RootRouter` or a thin new
  wrapper around it in `main.dart`) to detect `AppLifecycleState.paused`/
  `resumed`/`inactive`.
- On resume from background, replay a shortened version of the Phase 1 splash
  crossfade (skip the full logo animation, just a quick fade) rather than
  popping back in with no transition.
- Connectivity loss (already tracked via `connectivity_plus`, currently
  unused for UI per the codebase investigation) gets a slide-down banner
  ("You're offline — showing saved data") using `AnimatedSlide`, shown on
  `CatalogScreen`/`CustomerOrdersScreen`/`AdminOrdersScreen` — ties an
  existing unused dependency to actual UI for the first time.
- Android back-button on `CatalogScreen`/`AdminHomeScreen` (the two "root"
  post-login screens) gets a double-back-to-exit toast pattern
  (`PopScope`/`WillPopScope` + a brief `AnimatedOpacity` toast), matching the
  quick-commerce app convention instead of exiting instantly on first back
  press.

**Files touched**
- `lib/main.dart` — `WidgetsBindingObserver` wiring (new stateful wrapper or
  added directly to `GroceryApp`).
- `lib/core/router.dart` — resume-crossfade hook into `RootRouter`.
- `lib/features/catalog/catalog_screen.dart` — offline banner, back-button
  toast.
- `lib/features/admin/admin_home_screen.dart` — offline banner, back-button
  toast.
- `lib/features/orders/customer_orders_screen.dart` — offline banner.
- `lib/features/admin/orders/admin_orders_screen.dart` — offline banner.
- `lib/shared/widgets/` — **NEW**: `offline_banner.dart`,
  `double_back_to_exit.dart`.
- `pubspec.yaml` — no new dependency; `connectivity_plus` is already present
  and unused for UI today.

---

## Open questions before implementation starts

1. **Phase 5 cart-clear-on-success** is a behavior change, not purely visual
   — confirm whether the redesign should also fix "cart survives a
   successful order" while touching that screen anyway, or strictly leave
   behavior untouched and animation-only.
2. **Phase 3's bottom-sheet-not-a-screen** call is a design recommendation
   matching real Zepto/Blinkit UX, not a hard requirement — confirm before
   building if a full pushed `ProductDetailScreen` is preferred instead for
   consistency with the rest of the app's `Navigator.push` pattern.
3. **`shimmer` package** is the one new dependency proposed across all seven
   phases — confirm it's acceptable to add, or whether Phase 2's skeleton
   loading should be hand-rolled with `AnimatedContainer` opacity pulsing
   instead to keep the dependency count at zero.
