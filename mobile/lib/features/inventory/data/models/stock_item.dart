class StockItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final bool alertStatus;
  final String? aiStorageAdvice;
  final String updatedAt;

  StockItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.alertStatus,
    this.aiStorageAdvice,
    required this.updatedAt,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] ?? '',
      alertStatus: json['alert_status'] ?? false,
      aiStorageAdvice: json['ai_storage_advice'],
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }
}
