// lib/features/addresses/address_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';

class Address {
  final String id;
  final String label;
  final String landmark;
  final String phone;
  Address({required this.id, required this.label, required this.landmark, required this.phone});

  factory Address.fromMap(Map<String, dynamic> map) => Address(
        id: map['id'] as String,
        label: (map['label'] as String?) ?? 'Address',
        landmark: map['landmark'] as String,
        phone: map['phone'] as String,
      );
}

// RLS already restricts this to the logged-in user's own rows — no need to
// filter by user_id client-side, the database enforces it.
final addressesProvider = FutureProvider<List<Address>>((ref) async {
  final rows = await supabase.from('addresses').select().order('is_default', ascending: false);
  return (rows as List).map((m) => Address.fromMap(m as Map<String, dynamic>)).toList();
});

final addressServiceProvider = Provider((ref) => AddressService(ref));

class AddressService {
  final Ref ref;
  AddressService(this.ref);

  Future<void> addAddress({
    required String label,
    required String landmark,
    required String phone,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from('addresses').insert({
      'user_id': userId,
      'label': label,
      'landmark': landmark,
      'phone': phone,
    });
    ref.invalidate(addressesProvider);
  }
}