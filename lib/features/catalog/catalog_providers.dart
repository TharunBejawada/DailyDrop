// lib/features/catalog/catalog_providers.dart
//
// Fetches categories and in-stock products in parallel (two small queries
// run together, not one after another) — with a single-store catalog this
// is fast and simple; grouping by category happens client-side afterward.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase_client.dart';
import '../../models/category.dart';
import '../../models/product.dart';

class CatalogData {
  final List<Category> categories;
  final List<Product> products;
  CatalogData({required this.categories, required this.products});

  List<Product> productsForCategory(String categoryId) =>
      products.where((p) => p.categoryId == categoryId).toList();
}

/// Search box text on the Home tab, filtering the grid client-side — the
/// catalog is small enough (single store) that a separate search query
/// isn't worth it.
final catalogSearchQueryProvider = StateProvider<String>((ref) => '');

final catalogProvider = FutureProvider<CatalogData>((ref) async {
  final results = await Future.wait([
    supabase.from('categories').select().order('sort_order'),
    supabase.from('products').select().eq('is_available', true).order('name'),
  ]);

  final categories =
      (results[0] as List).map((m) => Category.fromMap(m as Map<String, dynamic>)).toList();
  final products =
      (results[1] as List).map((m) => Product.fromMap(m as Map<String, dynamic>)).toList();

  return CatalogData(categories: categories, products: products);
});