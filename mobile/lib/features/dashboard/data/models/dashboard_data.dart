import '../../../inventory/data/models/stock_item.dart';

class DashboardData {
  final AgricultureSummary agriculture;
  final List<MarketPrice> markets;
  final WeatherSummary weather;
  final List<String> alerts;
  
  // Nouveaux champs pour la V2 (Mockup)
  final List<CalendarEvent> calendarEvents;
  final List<FeaturedProduct> featuredProducts;
  final List<StockItem> stockItems;

  DashboardData({
    required this.agriculture,
    required this.markets,
    required this.weather,
    required this.alerts,
    this.calendarEvents = const [],
    this.featuredProducts = const [],
    this.stockItems = const [],
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      agriculture: AgricultureSummary.fromJson(json['agriculture'] ?? {}),
      markets: (json['markets'] as List?)
              ?.map((e) => MarketPrice.fromJson(e))
              .toList() ??
          [],
      weather: WeatherSummary.fromJson(json['weather'] ?? {}),
      // Le backend renvoie des objets {id, type, message, created_at}
      alerts: (json['alerts'] as List?)
              ?.map((e) => e is Map ? (e['message'] ?? '').toString() : e.toString())
              .toList() ??
          [],

      calendarEvents: (json['calendarEvents'] as List?)
              ?.map((e) => CalendarEvent.fromJson(e))
              .toList() ??
          [],
      featuredProducts: (json['featuredProducts'] as List?)
              ?.map((e) => FeaturedProduct.fromJson(e))
              .toList() ??
          const [],
      stockItems: (json['stockItems'] as List?)
              ?.map((e) => StockItem.fromJson(e))
              .toList() ??
          const [],
    );
  }
}

// ------------------ NOUVEAUX MODELES ------------------

class CalendarEvent {
  final String date;
  final String monthYear;
  final String phase;
  final String title;
  final String description;
  final bool isCompleted;

  CalendarEvent({
    required this.date,
    required this.monthYear,
    required this.phase,
    required this.title,
    required this.description,
    this.isCompleted = false,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      date: json['date'] ?? '',
      monthYear: json['month_year'] ?? '',
      phase: json['phase'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      isCompleted: json['is_completed'] ?? false,
    );
  }
}

/// Le backend envoie le prix en nombre (FCFA/kg) ; l'UI affiche une chaîne.
String _formatPrice(dynamic value) {
  if (value == null || value == '') return '';
  if (value is num) return '${value.round()} F/kg';
  return value.toString();
}

class FeaturedProduct {
  final String name;
  final String variety;
  final String imageAsset;
  final String price;
  final String cycle;
  final String profitability;

  FeaturedProduct({
    required this.name,
    required this.variety,
    required this.imageAsset,
    this.price = '',
    this.cycle = '',
    this.profitability = '',
  });

  factory FeaturedProduct.fromJson(Map<String, dynamic> json) {
    return FeaturedProduct(
      name: json['name'] ?? '',
      variety: (json['variety'] ?? json['category'] ?? '').toString(),
      imageAsset: (json['imageAsset'] ?? json['image_asset'] ?? '').toString(),
      price: _formatPrice(json['price']),
      cycle: (json['cycle'] ?? '').toString(),
      profitability: (json['profitability'] ?? '').toString(),
    );
  }
}

// (StockItem is now imported from inventory)

// ------------------ ANCIENS MODELES (MAINTENUS) ------------------

class AgricultureSummary {
  final int activeCropsCount;
  final double totalAreaSize;

  AgricultureSummary({
    required this.activeCropsCount,
    required this.totalAreaSize,
  });

  factory AgricultureSummary.fromJson(Map<String, dynamic> json) {
    return AgricultureSummary(
      activeCropsCount: json['active_crops_count'] ?? 0,
      totalAreaSize: (json['total_area_size'] ?? 0.0).toDouble(),
    );
  }
}

class MarketPrice {
  final String productName;
  final double price;
  final String trend;
  final String marketName;

  MarketPrice({
    required this.productName,
    required this.price,
    required this.trend,
    required this.marketName,
  });

  factory MarketPrice.fromJson(Map<String, dynamic> json) {
    return MarketPrice(
      productName: json['product_name'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      trend: json['trend'] ?? 'stable',
      marketName: json['market__name'] ?? '',
    );
  }
}

class WeatherSummary {
  final String location;
  final double temp;
  final double humidity;
  final double rainfall;

  WeatherSummary({
    required this.location,
    required this.temp,
    required this.humidity,
    required this.rainfall,
  });

  factory WeatherSummary.fromJson(Map<String, dynamic> json) {
    return WeatherSummary(
      location: json['location'] ?? 'Inconnue',
      temp: (json['temp'] ?? 0.0).toDouble(),
      humidity: (json['humidity'] ?? 0.0).toDouble(),
      rainfall: (json['rainfall'] ?? 0.0).toDouble(),
    );
  }
}
