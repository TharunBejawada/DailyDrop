// lib/models/category.dart

class Category {
  final String id;
  final String name;
  final String productType; // 'grocery' or 'fruit_veg'
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.productType,
    required this.sortOrder,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      productType: map['product_type'] as String,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}