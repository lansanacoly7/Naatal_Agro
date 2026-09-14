class ProductDetail {
  final String id;
  final String name;
  final String category;
  final double currentPrice;
  final double trendPercentage;
  final String imageAsset;
  final double rating;
  final String description;
  final NaatalRecommendation recommendation;

  ProductDetail({
    required this.id,
    required this.name,
    required this.category,
    required this.currentPrice,
    required this.trendPercentage,
    required this.imageAsset,
    required this.rating,
    required this.description,
    required this.recommendation,
  });
}

class NaatalRecommendation {
  final String title;
  final String message;
  final bool isPositive;

  NaatalRecommendation({
    required this.title,
    required this.message,
    this.isPositive = true,
  });
}
