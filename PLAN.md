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

## Phase 2 — Home / Browse (Catalog) [implemented]

**Goal**: the grid is the highest-traffic screen — this is where "quick
commerce" speed needs to be felt most.

**Pulled forward during the Phase 1 journey redesign**: a search field
above the grocery/fruit-veg tabs (client-side filter over the
already-fetched `catalogProvider` data — `catalogSearchQueryProvider` in
`catalog_providers.dart`), `CatalogScreen` stripped of its own
`Scaffold`/`AppBar` to become `CustomerHomeShell`'s Home-tab body, and
pull-to-refresh (`RefreshIndicator` wrapping the `CustomScrollView`,
calling `ref.refresh(catalogProvider.future)`).

**Implemented this phase**:
- Shimmer skeleton grid: `SkeletonBox` (`app_states.dart`) went back to a
  plain static block, and `ProductGridSkeleton`/`ListSkeleton` now wrap
  their whole batch in one `Shimmer.fromColors` sweep (`_ShimmerSweep`) —
  a single coherent loading surface rather than each box pulsing on its
  own, and the first real use of the `shimmer` dependency. Skipped
  entirely when `MediaQuery.disableAnimationsOf` is set.
- Staggered fade+slide-in for grid tiles on first load / tab switch /
  search filter, via `flutter_animate`'s `.animate().fadeIn().slideY()`
  chained directly on each `ProductCard` in `_ProductGrid`'s
  `itemBuilder`, delay scaled by index (capped at 12 tiles worth of
  delay) — first real use of `flutter_animate` too.
- Quantity stepper bounce: `_Bouncy` (now in
  `animated_quantity_stepper.dart`) wraps the Add button and both stepper
  buttons in a `GestureDetector` + `AnimatedScale`, scaling to 0.85 on
  tap-down.
- Fly-to-cart: `lib/shared/widgets/fly_to_cart_overlay.dart` — tapping Add
  or the stepper's `+` arcs a small circular thumbnail of the product from
  the tap point to the **bottom-nav cart icon**, not the floating cart bar
  as originally scoped below. Deviation: the floating bar is hidden
  exactly when this matters most (the first add to an empty cart), while
  the bottom-nav icon (`cartIconKeyProvider`, attached in
  `customer_home_shell.dart`) is always mounted.
- Floating cart bar's item-count and price now cross-fade/slide via
  `AnimatedSwitcher` (keyed by value) instead of snapping in place.

**Files touched**
- `lib/features/catalog/catalog_screen.dart` — staggered tile entrance,
  `AnimatedSwitcher` on cart-bar count/price.
- `lib/shared/widgets/app_states.dart` — `SkeletonBox` simplified to
  stateless, `_ShimmerSweep` added.
- `lib/shared/widgets/` — **NEW**: `fly_to_cart_overlay.dart`,
  `animated_quantity_stepper.dart` (extracted from `product_card.dart` so
  Phase 3's detail sheet reuses the same control).
- `lib/features/home/customer_home_shell.dart` — `cartIconKeyProvider` key
  attached to the bottom-nav cart `Badge`.

---

## Phase 3 — Product Detail [implemented]

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

**Implemented**: `lib/features/catalog/product_detail_sheet.dart` —
`showProductDetailSheet(context, product)` opens a `DraggableScrollableSheet`
(62% initial / 40% min / 92% max height, transparent barrier so the sheet's
own rounded top corners show through) with a drag handle, `Hero`-tagged image
(`productImageHeroTag`, shared with the grid tile), name, unit, price, and
the same `AnimatedQuantityStepper` used on the grid. `product_card.dart`
wraps its tile image in `GestureDetector(onTap: () =>
showProductDetailSheet(...))` + `Hero`. `AnimatedQuantityStepper` (Phase 2)
was reused as-is with no changes needed.

**Files touched**
- `lib/features/catalog/product_detail_sheet.dart` — **NEW**.
- `lib/shared/widgets/product_card.dart` — tile image wrapped in
  `GestureDetector` + `Hero`, tap opens the sheet.
- `lib/shared/widgets/animated_quantity_stepper.dart` — reused unchanged from
  Phase 2.
- `lib/models/product.dart` — no change (existing fields are sufficient).

---

## Phase 4 — Cart [superseded by a full screen, not a sheet; implemented]

**Original goal** (superseded): there was no dedicated cart screen — the
floating bar pushed straight to `CheckoutScreen`. Keep that navigation
shape (per CLAUDE.md, no route table / minimal screens) but make the cart
*reviewable* before checkout via an expandable sheet rather than a new
pushed screen.

**What actually got built**: the bottom-nav restructure (see Phase 1's
notes) made a bottom-sheet review feel like the wrong shape — a persistent
"Cart" tab fits a bottom-nav shell better than a sheet you'd have to
re-trigger from the Home tab. `lib/features/cart/cart_screen.dart`
(`CartScreen`) is a full-page line-item review living at tab index 1 in
`CustomerHomeShell`. Its "Proceed to checkout" button calls
`requireLogin()` before pushing `CheckoutScreen` — same gate used
everywhere else guest actions need auth.

**Implemented this phase**:
- Row content now reuses the shared `AnimatedQuantityStepper` (Phase 2/3)
  instead of the screen's own plain `_QtyStepper`, so bounce + fly-to-cart
  feedback is consistent everywhere a stepper appears.
- `CartScreen` converted to a `ConsumerStatefulWidget` driving an
  `AnimatedList` keyed by product id — a natural fit since `CartNotifier`'s
  state is already `Map<String, CartItem>`. Local `_order`/`_snapshot`
  fields track the currently-rendered id list and cache each item's
  last-known data; `ref.listen(cartProvider, ...)` diffs incoming state
  against them each change to call `insertItem`/`removeItem` explicitly
  (`AnimatedList` needs manual insert/remove calls — it doesn't diff a
  rebuilt list itself). Removing the last unit of a product now shrinks +
  fades the row out (`SizeTransition` + `FadeTransition`) instead of the
  list snapping to its new length.
- Because `CustomerHomeShell` swaps `body: screens[tabIndex]` directly (no
  `IndexedStack`), `CartScreen` is disposed/recreated on every tab switch —
  so this animation only ever plays for changes made while the Cart tab is
  actually mounted; re-opening the tab after adding items elsewhere just
  shows the current state with no animation, which is correct (nothing
  visibly changed on this screen).
- The whole body (item list vs. `EmptyState`) is wrapped in one top-level
  `AnimatedSwitcher` so removing the last item crossfades into the empty
  state once its row-removal animation finishes, rather than replacing the
  screens instantly the moment the underlying cart map goes empty.

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

## Phase 5 — Checkout [implemented]

**Goal**: checkout today is a single screen with an inline address dialog and
a blocking payment flow. Make the multi-step nature (address → slot → total →
pay) read as a sequence instead of a flat form.

**Two bullets below were already satisfied or no longer apply by the time
this phase started**: the address selector already used an `AnimatedContainer`
border/color transition on selection (`_SelectableTile`, built earlier) — no
new work needed. The delivery-slot cutoff countdown doesn't apply anymore —
`delivery_slot.dart` dropped the `fvCutoffHour` / next-morning pre-order model
back in Phase 1 (grocery and fruit/veg both fulfill same-day now), so there's
no cutoff left to animate a countdown toward.

**Implemented this phase**:
- "Place order" button morph: `_PlaceOrderState` enum (`idle`/`placing`/
  `success`) drives an `AnimatedSwitcher` in the button's child between the
  label text, a spinner, and a checkmark icon.
- Full-bleed success confirmation: `_OrderSuccessOverlay` (a `Positioned.fill`
  layered via `Stack` over the screen's `Scaffold`) shows a `flutter_animate`
  checkmark scale-in (`Curves.elasticOut`) + "Order placed!" fade-in, held for
  `AppMotion.slow * 3` (~900ms) before the existing navigation runs — replaces
  the old instant `SnackBar`-and-pop. Applies to both the COD path and the
  post-payment UPI path (`onSuccess` callback), via a shared
  `_showSuccessAndFinish()` helper.
- Cart-clear-on-success (the phase's one open question) turned out to already
  be implemented in `_finishCheckout()` from earlier work — not new this
  phase, just confirmed still in place.

**Files touched**
- `lib/features/checkout/checkout_screen.dart` — `_PlaceOrderState`, button
  `AnimatedSwitcher`, `_OrderSuccessOverlay`, `_showSuccessAndFinish()`.
- `lib/features/checkout/delivery_slot.dart` — no change.
- `lib/features/checkout/order_service.dart` — no change.
- `lib/features/checkout/razorpay_service.dart` — no change.
- `lib/features/addresses/address_provider.dart` — no change.

---

## Phase 6 — Order Tracking [implemented]

**Goal**: `orderStatusFlow` (`placed → confirmed → out_for_delivery →
delivered`, plus `cancelled`) already exists as a linear model in
`admin_order_service.dart` — this phase is purely about visualizing that
linear flow, both for customers and admin.

**Two bullets below were already satisfied by the time this phase
started**: `CustomerOrdersScreen`'s `_StatusTracker` already drew the
animated horizontal stepper (dots/line, `AnimatedContainer` fill) from
earlier work — it just drove stage order off a locally-duplicated `_steps`
list instead of `orderStatusFlow`, fixed below. Cancelled orders already got
a distinct red callout replacing the tracker entirely (not just red text),
so no separate stepper variant was needed.

**Implemented this phase**:
- `customer_orders_screen.dart`'s `_StatusTracker` now imports
  `orderStatusFlow` from `admin_order_service.dart` instead of a duplicated
  local list, so stage order has one real source of truth as originally
  intended.
- The current step's dot now does a quick scale pulse (`flutter_animate`,
  re-keyed on `currentIndex`) whenever it's newly reached — replays on a
  Realtime-driven status update, not just first paint, since the `dot`'s
  `AnimatedContainer` fill-color transition alone (already present) didn't
  read as an "event" the way a pulse does.
- `admin_orders_screen.dart`'s `_AdminOrderCard` converted from
  `ConsumerWidget` to `ConsumerStatefulWidget` so the "advance status" button
  can hold local `_AdvanceState` (idle/advancing/success) and morph label →
  spinner → checkmark via `AnimatedSwitcher`, mirroring the Phase 5 checkout
  button pattern.
- `admin_home_screen.dart`'s new-order alert replaced the plain `SnackBar`
  with `_NewOrderBanner`, shown via `AnimatedSlide` (`Curves.easeOutBack` for
  a bit of overshoot) + `AnimatedOpacity` layered over whichever tab is open,
  auto-dismissing after 6s. "View" still routes to `_tabIndex = 0` and clears
  the unseen badge, unchanged.

**Files touched**
- `lib/features/orders/customer_orders_screen.dart` — `orderStatusFlow`
  import, pulse animation on the current step.
- `lib/features/orders/customer_orders_provider.dart` — no change.
- `lib/features/orders/customer_orders_realtime.dart` — no change.
- `lib/features/admin/orders/admin_orders_screen.dart` — `_AdvanceState`,
  button `AnimatedSwitcher`.
- `lib/features/admin/orders/admin_order_service.dart` — no change
  (`orderStatusFlow`/`nextStatus()` reused as-is).
- `lib/features/admin/admin_home_screen.dart` — `_NewOrderBanner`, banner
  state/timer replacing the SnackBar call.
- `lib/features/admin/orders/order_realtime_service.dart` — no change.

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

All three resolved during Phases 1-5: cart-clear-on-success was implemented
in `_finishCheckout()`, Phase 3 used the bottom-sheet design as recommended,
and `shimmer` was added as planned.
