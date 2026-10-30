/// Météo réelle d'un lieu du Sénégal, telle que la renvoie le serveur (source : Open-Meteo).
/// Rien n'est complété par une valeur « par défaut » : une mesure absente reste absente (`null`).
class WeatherReport {
  const WeatherReport({
    required this.placeName,
    required this.lat,
    required this.lon,
    required this.current,
    required this.forecast,
    required this.rainLast7Days,
    required this.advice,
    required this.sourceName,
    required this.sourceNote,
  });

  final String placeName;
  final double lat;
  final double lon;
  final CurrentWeather current;

  /// Demain et les jours suivants (aujourd'hui est décrit par [current]).
  final List<ForecastDay> forecast;

  /// Pluie tombée pendant les 7 derniers jours (mm).
  final double rainLast7Days;

  /// Conseils calculés à partir de ces mesures ; vide quand il n'y a rien de notable.
  final List<String> advice;

  final String sourceName;
  final String sourceNote;

  /// Même météo, avec le nom de lieu que la personne reconnaît (« Ma position », « Thiès »…).
  WeatherReport withPlaceName(String name) => WeatherReport(
        placeName: name,
        lat: lat,
        lon: lon,
        current: current,
        forecast: forecast,
        rainLast7Days: rainLast7Days,
        advice: advice,
        sourceName: sourceName,
        sourceNote: sourceNote,
      );

  factory WeatherReport.fromJson(Map<String, dynamic> json) {
    final place = Map<String, dynamic>.from(json['place'] as Map);
    final source = Map<String, dynamic>.from((json['source'] as Map?) ?? const {});
    return WeatherReport(
      placeName: place['name']?.toString() ?? 'Ma position',
      lat: (place['lat'] as num).toDouble(),
      lon: (place['lon'] as num).toDouble(),
      current: CurrentWeather.fromJson(Map<String, dynamic>.from(json['current'] as Map)),
      forecast: [for (final d in (json['forecast'] as List? ?? const [])) ForecastDay.fromJson(Map<String, dynamic>.from(d as Map))],
      rainLast7Days: (json['rain_last_7_days'] as num?)?.toDouble() ?? 0,
      advice: [for (final a in (json['advice'] as List? ?? const [])) a.toString()],
      sourceName: source['name']?.toString() ?? 'Open-Meteo',
      sourceNote: source['note']?.toString() ?? '',
    );
  }
}

class CurrentWeather {
  const CurrentWeather({
    required this.temperature,
    required this.humidity,
    required this.rainfall,
    required this.windSpeed,
    required this.description,
    required this.icon,
    this.feelsLike,
    this.observedAt,
    this.todayMax,
    this.todayMin,
    this.todayRain,
  });

  final double temperature;
  final double? feelsLike;
  final double? humidity;

  /// Pluie du moment (mm).
  final double rainfall;

  /// Vent (km/h).
  final double windSpeed;
  final String description;

  /// Famille d'icône : clear, partly, cloudy, fog, drizzle, rain, storm.
  final String icon;

  /// Heure de la mesure (heure du Sénégal).
  final DateTime? observedAt;
  final double? todayMax;
  final double? todayMin;
  final double? todayRain;

  factory CurrentWeather.fromJson(Map<String, dynamic> json) => CurrentWeather(
        temperature: (json['temperature'] as num).toDouble(),
        feelsLike: (json['feels_like'] as num?)?.toDouble(),
        humidity: (json['humidity'] as num?)?.toDouble(),
        rainfall: (json['rainfall'] as num?)?.toDouble() ?? 0,
        windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 0,
        description: json['description']?.toString() ?? '',
        icon: json['icon']?.toString() ?? 'cloudy',
        observedAt: json['observed_at'] == null ? null : DateTime.tryParse(json['observed_at'].toString()),
        todayMax: (json['today_max'] as num?)?.toDouble(),
        todayMin: (json['today_min'] as num?)?.toDouble(),
        todayRain: (json['today_rain'] as num?)?.toDouble(),
      );
}

class ForecastDay {
  const ForecastDay({
    required this.date,
    required this.temperatureMax,
    required this.temperatureMin,
    required this.rainfall,
    required this.windSpeed,
    required this.description,
    required this.icon,
    this.rainProbability,
  });

  final DateTime date;
  final double? temperatureMax;
  final double? temperatureMin;
  final double rainfall;

  /// Chances de pluie (%), quand la source les donne.
  final double? rainProbability;
  final double windSpeed;
  final String description;
  final String icon;

  factory ForecastDay.fromJson(Map<String, dynamic> json) => ForecastDay(
        date: DateTime.parse(json['date'].toString()),
        temperatureMax: (json['temperature_max'] as num?)?.toDouble(),
        temperatureMin: (json['temperature_min'] as num?)?.toDouble(),
        rainfall: (json['rainfall'] as num?)?.toDouble() ?? 0,
        rainProbability: (json['rain_probability'] as num?)?.toDouble(),
        windSpeed: (json['wind_speed'] as num?)?.toDouble() ?? 0,
        description: json['description']?.toString() ?? '',
        icon: json['icon']?.toString() ?? 'cloudy',
      );
}

/// Plusieurs lieux portent le nom demandé : la personne doit choisir le sien.
class AmbiguousWeatherPlace implements Exception {
  const AmbiguousWeatherPlace(this.candidates);

  final List<WeatherPlaceChoice> candidates;
}

class WeatherPlaceChoice {
  const WeatherPlaceChoice({required this.label, required this.lat, required this.lon});

  final String label;
  final double lat;
  final double lon;
}

/// La source météo ne répond pas : on le dit, on n'invente rien.
class WeatherUnavailable implements Exception {
  const WeatherUnavailable(this.message);

  final String message;
}
