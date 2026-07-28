// lib/core/supabase_client.dart
//
// One shared Supabase client for the whole app. Import `supabase` anywhere
// you need to query the database or check the logged-in user.

import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;