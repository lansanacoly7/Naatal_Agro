import '../data/models/weather_report.dart';

/// Les mesures dites avec des mots de tous les jours : le public est peu lettré, les chiffres ne lui disent rien.
/// Les seuils ci-dessous sont des repères de l'application (pas des données de la source) ; la mesure reste réelle.

/// « Il fait chaud » : la température ressentie en une phrase.
String heatSentence(double celsius) {
  if (celsius >= 38) return 'Il fait très chaud';
  if (celsius >= 33) return 'Il fait chaud';
  if (celsius >= 24) return 'Il fait bon';
  if (celsius >= 18) return 'Il fait frais';
  return 'Il fait froid';
}

/// Le ciel en mots simples, d'après la famille de temps renvoyée par le serveur.
String skyWords(String family) {
  switch (family) {
    case 'clear':
      return 'Du soleil';
    case 'partly':
      return 'Soleil et nuages';
    case 'fog':
      return 'Du brouillard';
    case 'drizzle':
      return 'Petite pluie';
    case 'rain':
      return 'De la pluie';
    case 'storm':
      return 'Orage';
    default:
      return 'Ciel couvert';
  }
}

/// Vrai si le temps de cette famille amène de l'eau.
bool bringsWater(String family) => family == 'drizzle' || family == 'rain' || family == 'storm';

/// La pluie d'aujourd'hui en une phrase.
String todayRainSentence(CurrentWeather current) {
  final rain = current.todayRain ?? current.rainfall;
  if (bringsWater(current.icon) || current.rainfall > 0) return 'Il pleut en ce moment';
  if (rain >= 10) return 'Il a beaucoup plu aujourd\'hui';
  if (rain >= 1) return 'Il a plu un peu aujourd\'hui';
  return 'Pas de pluie aujourd\'hui';
}

/// Le vent en mots.
String windWords(double kmh) {
  if (kmh >= 30) return 'Vent fort';
  if (kmh >= 15) return 'Un peu de vent';
  return 'Pas de vent';
}

/// La pluie des 7 derniers jours en mots.
String recentRainWords(double mm) {
  if (mm < 2) return 'Presque pas de pluie';
  if (mm < 20) return 'Un peu de pluie';
  if (mm < 60) return 'Assez de pluie';
  return 'Beaucoup de pluie';
}

/// « Aujourd'hui », « Demain », « Après-demain », puis le nom du jour.
String dayName(DateTime day, DateTime today) {
  final a = DateTime(today.year, today.month, today.day);
  final b = DateTime(day.year, day.month, day.day);
  final gap = b.difference(a).inDays;
  if (gap == 0) return 'Aujourd\'hui';
  if (gap == 1) return 'Demain';
  if (gap == 2) return 'Après-demain';
  const names = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  return names[day.weekday - 1];
}

/// Ce que la personne entend quand elle touche le haut-parleur.
String weatherSpoken(WeatherReport report, DateTime today) {
  final current = report.current;
  final parts = <String>[
    '${heatSentence(current.temperature)}. ${skyWords(current.icon)}. ${todayRainSentence(current)}.',
    ...report.advice,
  ];
  if (report.forecast.isNotEmpty) {
    final next = report.forecast.first;
    parts.add('${dayName(next.date, today)} : ${skyWords(next.icon).toLowerCase()}.');
  }
  return parts.join(' ');
}
