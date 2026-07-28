// lib/models/product.dart

class Product {
  final String id;
  final String? categoryId;
  final String name;
  final String unit;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final String productType; // 'grocery' or 'fruit_veg'

  Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.unit,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.productType,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      categoryId: map['category_id'] as String?,
      name: map['name'] as String,
      unit: map['unit'] as String,
      price: (map['price'] as num).toDouble(),
      imageUrl: map['image_url'] as String?,
      isAvailable: map['is_available'] as bool,
      productType: map['product_type'] as String,
    );
  }
}