class WeatherDay {
  final String date;
  final double tempMax;
  final double tempMin;
  final int humidity;
  final double rainfall;
  final double windSpeed;
  final String description;

  const WeatherDay({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.humidity,
    required this.rainfall,
    required this.windSpeed,
    required this.description,
  });

  factory WeatherDay.fromJson(Map<String, dynamic> json) {
    return WeatherDay(
      date: json['date']?.toString() ?? '',
      tempMax: (json['temperature_max'] as num?)?.toDouble() ?? 30.0,
      tempMin: (json['temperature_min'] as num?)?.toDouble() ?? 22.0,
      humidity: (json['humidity'] as num?)?.toInt() ?? 60,
      rainfall: (json['rainfall'] as num?)?.toDouble() ?? 0.0,
      windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 12.0,
      description: json['description']?.toString() ?? 'Ensoleillé',
    );
  }
}

class WeatherForecastData {
  final String location;
  final double currentTemp;
  final int currentHumidity;
  final double currentRainfall;
  final List<WeatherDay> forecast;
  final List<String> agriculturalAdvice;

  const WeatherForecastData({
    required this.location,
    required this.currentTemp,
    required this.currentHumidity,
    required this.currentRainfall,
    required this.forecast,
    required this.agriculturalAdvice,
  });

  factory WeatherForecastData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? {};
    final rawForecast = json['forecast'] as List<dynamic>? ?? [];
    final rawAdvice = json['agricultural_advice'] as List<dynamic>? ?? [];

    return WeatherForecastData(
      location: json['location']?.toString() ?? 'Sénégal',
      currentTemp: (current['temperature'] as num?)?.toDouble() ?? 30.0,
      currentHumidity: (current['humidity'] as num?)?.toInt() ?? 60,
      currentRainfall: (current['rainfall'] as num?)?.toDouble() ?? 0.0,
      forecast: rawForecast.map((item) => WeatherDay.fromJson(item as Map<String, dynamic>)).toList(),
      agriculturalAdvice: rawAdvice.map((e) => e.toString()).toList(),
    );
  }
}
