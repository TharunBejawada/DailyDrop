// lib/features/admin/products/admin_products_provider.dart
//
// Unlike catalogProvider (customer-facing, only shows is_available=true),
// this fetches every product regardless of stock status — admin needs to
// see and toggle out-of-stock items too.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase_client.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';

class AdminCatalogData {
  final List<Category> categories;
  final List<Product> products;
  AdminCatalogData({required this.categories, required this.products});
}

final adminCatalogProvider = FutureProvider<AdminCatalogData>((ref) async {
  final results = await Future.wait([
    supabase.from('categories').select().order('sort_order'),
    supabase.from('products').select().order('name'),
  ]);

  final categories =
      (results[0] as List).map((m) => Category.fromMap(m as Map<String, dynamic>)).toList();
  final products =
      (results[1] as List).map((m) => Product.fromMap(m as Map<String, dynamic>)).toList();

  return AdminCatalogData(categories: categories, products: products);
});