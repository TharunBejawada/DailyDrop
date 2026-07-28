// lib/features/home/home_tab_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which bottom-nav destination is active in CustomerHomeShell. A provider
/// rather than local State so widgets nested deep inside the Home tab (e.g.
/// the floating cart bar) can switch tabs without a callback threaded all
/// the way down.
final homeTabIndexProvider = StateProvider<int>((ref) => 0);
