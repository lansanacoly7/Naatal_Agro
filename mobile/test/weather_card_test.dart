import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/weather/data/models/weather_report.dart';
import 'package:nataal_agro/features/weather/data/weather_provider.dart';
import 'package:nataal_agro/features/weather/presentation/widgets/weather_widgets.dart';
import 'package:nataal_agro/screens/markets/markets_data.dart' show userLocationProvider, UserLocationNotifier;
import 'package:nataal_agro/ui/ui.dart';

/// Exemple de réponse du serveur (valeurs de test) : la source météo réelle n'est jamais appelée dans les tests.
Map<String, dynamic> serverJson({List<String> advice = const []}) => {
      'available': true,
      'place': {'name': 'Ma position', 'lat': 14.72, 'lon': -17.18},
      'current': {
        'temperature': 31.4,
        'feels_like': 33.0,
        'humidity': 62,
        'rainfall': 0.0,
        'wind_speed': 18.0,
        'description': 'Partiellement nuageux',
        'icon': 'partly',
        'observed_at': '2026-10-24T13:00',
        'today_max': 33.0,
        'today_min': 24.0,
        'today_rain': 0.0,
      },
      'forecast': [
        {
          'date': '2026-10-25',
          'temperature_max': 33.0,
          'temperature_min': 24.0,
          'rainfall': 0.0,
          'rain_probability': 5,
          'wind_speed': 15.0,
          'description': 'Plutôt dégagé',
          'icon': 'clear',
        },
      ],
      'rain_last_7_days': 3.5,
      'advice': advice,
      'source': {'name': 'Open-Meteo', 'url': 'https://open-meteo.com', 'note': 'Prévision numérique.'},
    };

const _query = WeatherQuery(lat: 14.72, lon: -17.18, label: 'Ma position', isMyPosition: true);

class _NoLocation extends UserLocationNotifier {
  _NoLocation() : super();

  @override
  Future<void> locate() async {}
}

Future<void> pumpCard(WidgetTester tester, {required WeatherQuery? query, required Future<WeatherReport> Function() report}) async {
  tester.view.physicalSize = const Size(390, 900) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        weatherQueryProvider.overrideWithValue(query),
        weatherReportProvider.overrideWith((ref, q) => report()),
        weatherLocateAskedProvider.overrideWith((ref) => true),
        userLocationProvider.overrideWith((ref) => _NoLocation()),
      ],
      child: MaterialApp(
        theme: NaatalTheme.light,
        home: const EffectsScope(reduced: true, child: Scaffold(body: SingleChildScrollView(child: LiveWeatherCard()))),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  test('le rapport lit les mesures du serveur sans rien inventer', () {
    final report = WeatherReport.fromJson(serverJson(advice: ['Pluie annoncée.']));
    expect(report.current.temperature, 31.4);
    expect(report.current.windSpeed, 18.0);
    expect(report.current.observedAt, DateTime(2026, 10, 24, 13));
    expect(report.forecast.single.date, DateTime(2026, 10, 25));
    expect(report.forecast.single.rainProbability, 5);
    expect(report.rainLast7Days, 3.5);
    expect(report.advice, ['Pluie annoncée.']);
  });

  test('une mesure absente reste absente', () {
    final json = serverJson();
    (json['current'] as Map).remove('humidity');
    (json['current'] as Map).remove('feels_like');
    final report = WeatherReport.fromJson(json);
    expect(report.current.humidity, isNull);
    expect(report.current.feelsLike, isNull);
  });

  testWidgets('la carte montre la météo réelle : température, description, heure de mesure, vent', (tester) async {
    await pumpCard(tester, query: _query, report: () async => WeatherReport.fromJson(serverJson()).withPlaceName('Ma position'));
    expect(find.text('31°'), findsOneWidget);
    expect(find.text('Il fait bon'), findsOneWidget);
    expect(find.textContaining('Soleil et nuages'), findsOneWidget);
    expect(find.text('Mesuré à 13 h 00'), findsOneWidget);
    expect(find.text('Ma position'), findsOneWidget);
  });

  testWidgets('sans lieu connu, la carte demande où est la personne au lieu d\'afficher des chiffres', (tester) async {
    await pumpCard(tester, query: null, report: () async => throw StateError('ne doit pas être appelé'));
    expect(find.text('Où êtes-vous ?'), findsOneWidget);
    expect(find.text('Me localiser'), findsOneWidget);
    expect(find.text('Choisir ma région'), findsOneWidget);
    expect(find.textContaining('°'), findsNothing);
  });

  testWidgets('source indisponible : message clair, aucun chiffre de remplacement', (tester) async {
    await pumpCard(tester, query: _query, report: () async => throw const WeatherUnavailable('La météo est momentanément indisponible.'));
    expect(find.text('Météo indisponible'), findsOneWidget);
    expect(find.text('La météo est momentanément indisponible.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.textContaining('°'), findsNothing);
  });

  testWidgets('plusieurs lieux du même nom : la personne choisit, on ne devine pas', (tester) async {
    await pumpCard(
      tester,
      query: _query,
      report: () async => throw const AmbiguousWeatherPlace([
        WeatherPlaceChoice(label: 'Keur Massar (Louga)', lat: 15.46, lon: -15.88),
        WeatherPlaceChoice(label: 'Keur Massar (Dakar)', lat: 14.78, lon: -17.31),
      ]),
    );
    expect(find.text('Quel est votre lieu ?'), findsOneWidget);
    expect(find.text('Keur Massar (Louga)'), findsOneWidget);
    expect(find.text('Keur Massar (Dakar)'), findsOneWidget);
  });
}
