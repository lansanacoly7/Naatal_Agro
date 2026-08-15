class Price {
  final String id;
  final String marketId;
  final String productName;
  final double priceValue;
  final String trend; // 'up', 'down', 'stable'
  final String date;

  Price({
    required this.id,
    required this.marketId,
    required this.productName,
    required this.priceValue,
    required this.trend,
    required this.date,
  });

  factory Price.fromJson(Map<String, dynamic> json) {
    return Price(
      id: json['id'],
      marketId: json['market'],
      productName: json['product_name'],
      priceValue: double.parse(json['price'].toString()),
      trend: json['trend'],
      date: json['date'],
    );
  }
}
