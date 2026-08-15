class Product {
  final String id;
  final String name;
  final String category;
  final double currentPrice;
  final double trendPercentage;
  final String imageAsset;
  final bool isTrending;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.currentPrice,
    required this.trendPercentage,
    required this.imageAsset,
    required this.isTrending,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      currentPrice: double.tryParse(json['current_price']?.toString() ?? '0.0') ?? 0.0,
      trendPercentage: double.tryParse(json['trend_percentage']?.toString() ?? '0.0') ?? 0.0,
      imageAsset: json['image_asset'] ?? '',
      isTrending: json['is_trending'] ?? false,
    );
  }
}
