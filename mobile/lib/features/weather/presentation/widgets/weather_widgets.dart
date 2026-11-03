import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/location/location_access.dart' show locationFixLabel;
import '../../../../core/location/senegal_regions.dart';
import '../../../../screens/markets/markets_data.dart' show userLocationProvider;
import '../../../../ui/ui.dart';
import '../../../dashboard/data/models/dashboard_data.dart';
import '../../data/models/weather_report.dart';
import '../../data/weather_provider.dart';
import '../../domain/weather_words.dart';

/// Icône de la famille de temps renvoyée par le serveur.
IconData weatherIconFor(String family) {
  switch (family) {
    case 'clear':
      return Icons.wb_sunny_rounded;
    case 'partly':
      return Icons.wb_cloudy_outlined;
    case 'fog':
      return Icons.foggy;
    case 'drizzle':
      return Icons.grain_rounded;
    case 'rain':
      return Icons.water_drop_rounded;
    case 'storm':
      return Icons.thunderstorm_rounded;
    default:
      return Icons.cloud_rounded;
  }
}

/// « 13 h 00 » : l'heure de la mesure, en heure du Sénégal.
String measuredAt(DateTime? time) {
  if (time == null) return '';
  return '${time.hour} h ${time.minute.toString().padLeft(2, '0')}';
}

/// Résumé de la météo réelle du lieu courant, pour les écrans qui n'ont besoin que de quelques chiffres.
final liveWeatherSummaryProvider = Provider<WeatherSummary>((ref) {
  final query = ref.watch(weatherQueryProvider);
  final report = query == null ? null : ref.watch(weatherReportProvider(query)).valueOrNull;
  if (query == null || report == null) {
    return WeatherSummary(location: '', temp: 0, humidity: 0, rainfall: 0, isAvailable: false);
  }
  return WeatherSummary(
    location: query.label,
    temp: report.current.temperature,
    humidity: report.current.humidity ?? 0,
    rainfall: report.current.rainfall,
    isAvailable: true,
    date: report.current.observedAt,
  );
});

/// Feuille de choix de la région dont on veut la météo.
Future<void> showWeatherPlaceSheet(BuildContext context, WidgetRef ref) {
  return showNaatalSheet<void>(
    context,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Météo de quelle région ?', style: T.title(color: ctx.c.ink)),
          const SizedBox(height: Space.l),
          Wrap(
            spacing: Space.m,
            runSpacing: Space.m,
            children: [
              for (final region in SenegalRegions.all)
                PressScale(
                  onTap: () {
                    ref.read(manualWeatherQueryProvider.notifier).state = WeatherQuery(lat: region.lat, lon: region.lon, label: region.name);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    height: Hit.primary,
                    padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ctx.c.surface,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(color: ctx.c.line, width: 1.5),
                    ),
                    child: Text(region.name, style: T.body(color: ctx.c.ink, weight: 700)),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Plusieurs lieux portent le même nom : on demande lequel, on ne devine pas.
class AmbiguousPlaceChooser extends ConsumerWidget {
  const AmbiguousPlaceChooser({super.key, required this.error, this.onDark = false});

  final AmbiguousWeatherPlace error;
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final fg = onDark ? Colors.white : c.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quel est votre lieu ?', style: T.title(color: fg)),
        const SizedBox(height: Space.xs),
        Text('Plusieurs lieux portent ce nom. Touchez le vôtre.', style: T.body(color: fg.withValues(alpha: 0.85))),
        const SizedBox(height: Space.l),
        for (final choice in error.candidates) ...[
          PillButton(
            label: choice.label,
            icon: Icons.place_rounded,
            variant: onDark ? PillVariant.glass : PillVariant.secondary,
            expand: true,
            onPressed: () => ref.read(manualWeatherQueryProvider.notifier).state =
                WeatherQuery(lat: choice.lat, lon: choice.lon, label: choice.label),
          ),
          const SizedBox(height: Space.s),
        ],
      ],
    );
  }
}

/// Carte de l'accueil : la météo réelle de l'endroit où se trouve la personne.
class LiveWeatherCard extends ConsumerStatefulWidget {
  const LiveWeatherCard({super.key});

  @override
  ConsumerState<LiveWeatherCard> createState() => _LiveWeatherCardState();
}

class _LiveWeatherCardState extends ConsumerState<LiveWeatherCard> {
  @override
  void initState() {
    super.initState();
    // On cherche la position une seule fois par session : un refus ne rappelle pas la demande à chaque affichage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(weatherLocateAskedProvider)) return;
      ref.read(weatherLocateAskedProvider.notifier).state = true;
      final location = ref.read(userLocationProvider);
      if (location.position == null && !location.loading) ref.read(userLocationProvider.notifier).locate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(weatherQueryProvider);
    if (query == null) return const _WeatherShell(child: _AskPlace());

    final report = ref.watch(weatherReportProvider(query));
    return report.when(
      loading: () => const Skeleton(height: 230, radius: 24),
      error: (error, _) {
        if (error is AmbiguousWeatherPlace) return _WeatherShell(child: AmbiguousPlaceChooser(error: error, onDark: true));
        final message = error is WeatherUnavailable ? error.message : 'La météo n\'a pas pu être chargée.';
        return _WeatherShell(
          child: _Unavailable(message: message, onRetry: () => ref.invalidate(weatherReportProvider(query))),
        );
      },
      data: (data) => _WeatherShell(child: _Current(report: data)),
    );
  }
}

/// Fond de la carte : la photo météo sous un voile bleu, lisible en clair comme en sombre.
class _WeatherShell extends StatelessWidget {
  const _WeatherShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.22), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/ui/ui_meteo.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF0369A1)),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0284C7).withValues(alpha: 0.88),
                      const Color(0xFF0369A1).withValues(alpha: 0.84),
                      const Color(0xFF0F1A14).withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(24), child: child),
          ],
        ),
      ),
    );
  }
}

class _AskPlace extends ConsumerWidget {
  const _AskPlace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(userLocationProvider);
    final loading = location.loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_searching_rounded, color: Colors.white, size: 32),
        const SizedBox(height: Space.m),
        Text('Où êtes-vous ?', style: T.title(color: Colors.white)),
        const SizedBox(height: Space.xs),
        Text(location.error ?? 'Pour la météo de votre zone, autorisez la localisation ou choisissez votre région.',
            style: T.body(color: Colors.white.withValues(alpha: 0.88))),
        const SizedBox(height: Space.l),
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            PillButton(
              label: location.needsFix ? locationFixLabel(location.access!) : 'Me localiser',
              icon: Icons.my_location_rounded,
              variant: PillVariant.light,
              loading: loading,
              onPressed: () {
                final notifier = ref.read(userLocationProvider.notifier);
                location.needsFix ? notifier.enable() : notifier.locate();
              },
            ),
            PillButton(
              label: 'Choisir ma région',
              variant: PillVariant.glass,
              onPressed: () => showWeatherPlaceSheet(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 32),
        const SizedBox(height: Space.m),
        Text('Météo indisponible', style: T.title(color: Colors.white)),
        const SizedBox(height: Space.xs),
        Text(message, style: T.body(color: Colors.white.withValues(alpha: 0.88))),
        const SizedBox(height: Space.l),
        PillButton(label: 'Réessayer', icon: Icons.refresh_rounded, variant: PillVariant.light, onPressed: onRetry),
      ],
    );
  }
}

class _Current extends StatelessWidget {
  const _Current({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final current = report.current;
    final time = measuredAt(current.observedAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.place_rounded, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Expanded(child: Text(report.placeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption(color: Colors.white, weight: 700).copyWith(fontSize: 14))),
            if (time.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: Text('Mesuré à $time', style: T.caption(color: Colors.white, weight: 700)),
              ),
          ],
        ),
        const SizedBox(height: Space.m),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${current.temperature.round()}°', style: T.number(64, color: Colors.white)),
            const SizedBox(width: Space.m),
            Icon(weatherIconFor(current.icon), color: const Color(0xFFFFD54F), size: 52),
            const SizedBox(width: Space.m),
            Expanded(child: Text(heatSentence(current.temperature), style: T.title(color: Colors.white))),
          ],
        ),
        const SizedBox(height: Space.s),
        Text('${skyWords(current.icon)}. ${todayRainSentence(current)}.', style: T.body(color: Colors.white, weight: 600)),
        const SizedBox(height: Space.l),
        PillButton(
          label: 'Voir la météo',
          icon: Icons.arrow_forward_rounded,
          variant: PillVariant.light,
          onPressed: () => context.push('/weather'),
        ),
      ],
    );
  }
}
