# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter app for a hyperlocal grocery + fruits & vegetables delivery store (single store, India / ₹ / `en_IN`). Supabase is the entire backend — Postgres, Auth, Storage, and Realtime. There is no custom server.

## Commands

The app **cannot run without `--dart-define` credentials** — `Env.assertConfigured()` throws on startup otherwise. Use the local runner script:

```bash
./run_dev.sh chrome        # web
./run_dev.sh android       # single connected Android device/emulator
./run_dev.sh <device_id>   # specific device (see `flutter devices`)
```

`run_dev.sh` holds real Supabase/Razorpay keys and is git-ignored — never commit it, and never move those values into a tracked file. Required defines: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `RAZORPAY_KEY_ID`.

```bash
flutter pub get
flutter analyze                          # lint (flutter_lints via analysis_options.yaml)
flutter test                             # all tests
flutter test test/widget_test.dart       # single file
flutter test --plain-name '<test name>'  # single test by name
```

## Architecture

### Env / client
`lib/core/env.dart` reads compile-time `String.fromEnvironment` values. `lib/core/supabase_client.dart` exposes a single top-level `supabase` client — import it directly rather than reaching through `Supabase.instance`.

### One app, two roles — plus guest browsing
`lib/core/router.dart` (`RootRouter`, the `home` of `MaterialApp`, now a `ConsumerWidget`) is the only navigation gate: it watches `supabase.auth.onAuthStateChange`, then reads `profiles.role` for the session user and branches to `AdminHomeScreen` or `CustomerHomeShell`. There is no route table; everything below is `Navigator.push`. A logged-in user with no `profiles` row surfaces a dedicated error screen — that means the DB's `handle_new_user` trigger didn't fire.

Logged-out users are **not** routed to `LoginScreen` directly. `RootRouter` shows a one-time `OnboardingScreen` carousel (persisted via `shared_preferences`, see `features/onboarding/onboarding_provider.dart`), then lands on `CustomerHomeShell` as a guest — no session required. Login is only enforced where it's actually needed (checkout, order history) via `requireLogin(context)` in `lib/core/auth_guard.dart`, which pushes `LoginScreen` and returns whether sign-in succeeded. `LoginScreen` therefore pops with `true` on success **when it was pushed** (guest gate case) in addition to its original root-level behavior (RootRouter's auth-stream listener swaps the screen on its own when `LoginScreen` is the root, no pop needed).

**Backend dependency**: guest browsing means `catalogProvider`'s `categories`/`products` queries now run under the Postgres `anon` role, not an authenticated one. This requires a public/anon SELECT RLS policy on those two tables — verify this against the live Supabase project; if missing, guest catalog browsing will show `ErrorState` instead of products.

### Customer home is a bottom-nav shell, like admin already was
`lib/features/home/customer_home_shell.dart` (`CustomerHomeShell`) mirrors `AdminHomeScreen`'s existing pattern (one `Scaffold`, one `AppBar`, `body` swaps by index, no pushes between tabs) instead of introducing a second navigation style. Tab index lives in `homeTabIndexProvider` (a `StateProvider<int>`, not local `State`) specifically so deeply-nested widgets — the floating cart bar on the Home tab, the "place order" success handler in `checkout_screen.dart` — can switch tabs without threading a callback down. The four tabs: `CatalogScreen` (Home; now a plain body widget, no own `Scaffold`/`AppBar` — search field + grocery/fruit-veg `TabBar` + grid), `CartScreen` (review + `requireLogin()`-gated checkout push), `CustomerOrdersScreen` (also stripped of its own `Scaffold`; shows a sign-in prompt instead of querying when there's no session), `AccountScreen` (profile + sign-out, or a sign-in prompt for guests).

### State: Riverpod, invalidate-not-mutate
`FutureProvider` for reads, plain `Provider` for services, `StreamProvider` for Realtime. Services take `Ref` and call `ref.invalidate(<listProvider>)` after a write instead of mutating local state — follow this pattern for new writes. The only mutable local state is `CartNotifier` (`StateNotifierProvider`, in-memory, cleared on restart).

### RLS is the security boundary
Queries deliberately **omit `user_id` filters** — Postgres RLS restricts rows (`addresses`, `orders`, `customer_orders_provider`), and the admin's `is_admin()` policy is what lets `adminOrdersProvider` see every order with the same query shape. Don't add client-side owner filters "for safety"; don't assume a query is safe because it looks unfiltered.

### Schema lives outside this repo
Code comments reference `supabase_schema.sql`, `handle_new_user`, `is_admin()`, and the `mark_order_paid` RPC, but **no SQL file is checked in**. Tables/columns in use: `profiles(id, role, full_name, phone)`, `categories(sort_order, product_type)`, `products(name, unit, price, image_url, is_available, product_type, category_id)`, `addresses(label, landmark, phone, is_default)`, `orders(user_id, address_id, order_type, status, delivery_slot, payment_method, payment_status, total_amount)`, `order_items(order_id, product_id, quantity, price_at_order)`. Storage bucket: `product-images`. Verify against the live project before assuming a column exists.

### The `product_type` split — browsing only, not fulfillment
Every product and category is `'grocery'` or `'fruit_veg'`, used to split the catalog into its two browsing tabs (and the `grocery`/`fruitVeg` tint pair in the design system). **Both fulfill identically now** — same-day, 30–45 min (`lib/features/checkout/delivery_slot.dart`'s single `deliverySlot()`). Fruit/veg used to be a next-morning pre-order track with a cutoff hour; that was dropped in favor of matching grocery's speed (see PLAN.md's Phase 1 notes for why).

`OrderService.placeOrder` creates **one merged order per checkout** regardless of what product types are in the cart, and returns a single-element list of order IDs (kept as a list since checkout/payment-marking code iterates over it). `orders.order_type` is `'grocery'`, `'fruit_veg'`, or `'mixed'` (cart had both) — **`'mixed'` requires the Supabase schema's check constraint on that column to allow it**; this hasn't been verified against the live project since the schema lives outside this repo. `OrderTypeChip` (`lib/shared/widgets/status_badge.dart`) is the single source of truth for order-type label/icon/color, including the `'mixed'` case — reuse it rather than re-deriving a label from `orderType` inline.

### Checkout / payment
Orders are inserted first (`payment_status` stays `'pending'`), then Razorpay opens for the combined total; on success each order ID is marked paid via the `mark_order_paid` RPC. Payment failure is deliberately non-rollback — the orders remain and the customer is told they can pay on delivery. Razorpay is client-side only (public Key ID, no server order creation or signature verification); `razorpay_service.dart` documents this as an accepted launch-stage trade-off.

### Order status
Advancement is linear via `orderStatusFlow` / `nextStatus()` in `admin_order_service.dart`: `placed → confirmed → out_for_delivery → delivered`, plus a separate `cancelled`. Use those helpers rather than writing status strings inline.

### Realtime
Two channels, both auto-cleaned in `ref.onDispose`: admin listens for `orders` INSERTs (`order_realtime_service.dart`) and customers for UPDATEs **server-side filtered** on their own `user_id` (`customer_orders_realtime.dart`). Realtime payloads don't include joins, so callbacks invalidate the full list provider rather than patching a row.

### Admin product scan
`product_scanner_service.dart` runs on-device ML Kit: OCR first (printed packaging), falling back to image labeling (loose produce). `edit_product_screen.dart` runs the scan and the Supabase Storage upload concurrently on the same picked image. The suggested name is a starting point the admin edits — no accuracy guarantees needed.

## Platform constraints

`razorpay_flutter` and both `google_mlkit_*` packages have **no Flutter Web support**. Web builds must keep working, so those paths are guarded with `kIsWeb` — checkout hides UPI and locks to COD; the scan button is hidden entirely. Any new native-only dependency needs the same treatment. `image_upload_service.dart` uses `uploadBinary` with bytes (not a `File` path) specifically to stay web-compatible.

## Layout

`lib/core/` (env, client, router, `auth_guard.dart`) · `lib/models/` (`fromMap` factories mapping snake_case columns) · `lib/features/<feature>/` (screens + providers + services colocated; admin has `orders/`, `products/`, `products/scan/`; customer-facing also has `home/` — the bottom-nav shell — and `account/`) · `lib/shared/widgets/`.

## Design system

Tokens live under `lib/core/theme/` — never hardcode a hex value, `EdgeInsets` literal, or animation duration outside these files.

**Colors** (`app_colors.dart`) — the only file allowed to contain hex codes. Emerald/green brand (`primary` `#059669`, lighter `primaryDark` `#34D399` for dark-mode contrast) + amber `accent` (`#D97706`) for CTAs/price emphasis. Separate light/dark surface, text, and status (`success`/`warning`/`destructive`/`info`) pairs, plus a `grocery`/`fruitVeg` tint pair for the `product_type` split. Screens never read `AppColors` directly — use `Theme.of(context).colorScheme` for brand/surface and `AppSemantic.of(context)` (a `ThemeExtension` in `app_theme.dart`) for status/category colors, so light/dark mode stay correct automatically.

**Spacing** (`app_spacing.dart`) — 4/8dp rhythm: `AppSpacing.xxs`(2) `xs`(4) `sm`(8) `md`(12) `lg`(16) `xl`(24) `xxl`(32) `xxxl`(48), plus `AppSpacing.gutterFor(width)` for adaptive page gutters (16/24/32 by phone/large-phone/tablet breakpoints). `AppRadius` (`sm`8 `md`12 `lg`16 `xl`20 `pill`999) and `AppIconSize` (`sm`16 `md`20 `lg`24 `xl`32 `hero`48) are companion token sets in the same file — use them instead of literal numbers so component/section/page spacing stays on one scale.

**Motion** — `AppMotion` in `app_spacing.dart` defines the duration band: `fast`(150ms) `normal`(220ms) `slow`(300ms). Keep micro-interactions inside this band.

**Animation packages**: `Hero` (built into Flutter, no package) for shared-element transitions; `flutter_animate` (^4.5.2) for declarative one-off/staggered animations; `shimmer` (^3.0.0) for skeleton loading states. All three were added for the Blinkit/Zepto-style redesign in `PLAN.md` — as of this writing they are dependencies but not yet wired into any screen, so don't assume existing usage without checking the screen file first.

## Known gaps

- `test/widget_test.dart` is the unmodified `flutter create` template and **does not compile** — it pumps `MyApp`, but the root widget is `GroceryApp`. Fix or replace it before relying on `flutter test`; note the real app also requires `--dart-define` values and a Supabase init.
- `lib/models/order.dart` is empty. Order shapes are defined per-feature as `AdminOrder` / `CustomerOrder`.
- `README.md` is the unmodified Flutter template — not a source of project information.
- `_PlaceholderScreen` in `router.dart` is dead code left from scaffolding.
