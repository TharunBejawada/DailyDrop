// lib/features/admin/products/admin_product_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_client.dart';
import 'admin_products_provider.dart';

final adminProductServiceProvider = Provider((ref) => AdminProductService(ref));

class AdminProductService {
  final Ref ref;
  AdminProductService(this.ref);

  /// This is the one-tap toggle from the roadmap — flip stock status
  /// instantly without opening the full edit form.
  Future<void> setAvailability(String productId, bool isAvailable) async {
    await supabase.from('products').update({'is_available': isAvailable}).eq('id', productId);
    ref.invalidate(adminCatalogProvider);
  }

  Future<void> createProduct({
    required String name,
    required String unit,
    required double price,
    required String categoryId,
    required String productType,
    String? imageUrl,
  }) async {
    await supabase.from('products').insert({
      'name': name,
      'unit': unit,
      'price': price,
      'category_id': categoryId,
      'product_type': productType,
      'image_url': imageUrl,
      'is_available': true,
    });
    ref.invalidate(adminCatalogProvider);
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    required String unit,
    required double price,
    required String categoryId,
    String? imageUrl,
  }) async {
    await supabase.from('products').update({
      'name': name,
      'unit': unit,
      'price': price,
      'category_id': categoryId,
      'image_url': imageUrl,
    }).eq('id', productId);
    ref.invalidate(adminCatalogProvider);
  }

  Future<void> deleteProduct(String productId) async {
    await supabase.from('products').delete().eq('id', productId);
    ref.invalidate(adminCatalogProvider);
  }
}