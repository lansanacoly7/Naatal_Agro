import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/senegal_regions.dart';
import '../../../../screens/markets/markets_data.dart' show userLocationProvider;
import '../../../../ui/ui.dart';
import '../../data/models/weather_report.dart';
import '../../data/weather_provider.dart';
import '../../domain/weather_words.dart';
import '../widgets/weather_widgets.dart';

/// Météo agricole : mesures et prévisions réelles du lieu où se trouve la personne (ou de la région choisie).
class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(weatherQueryProvider);
    final manual = ref.watch(manualWeatherQueryProvider);

    return LargeTitleScaffold(
      title: 'Météo',
      eyebrow: query?.label,
      reserveNav: false,
      onRefresh: () async {
        if (query != null) ref.invalidate(weatherReportProvider(query));
      },
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // « Ma position » d'abord, puis les régions
              SizedBox(
                height: 52,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _Chip(
                      label: 'Ma position',
                      icon: Icons.my_location_rounded,
                      selected: manual == null,
                      onTap: () {
                        ref.read(manualWeatherQueryProvider.notifier).state = null;
                        if (ref.read(userLocationProvider).position == null) ref.read(userLocationProvider.notifier).locate();
                      },
                    ),
                    for (final region in SenegalRegions.all) ...[
                      const SizedBox(width: Space.s),
                      _Chip(
                        label: region.name,
                        selected: manual?.label == region.name,
                        onTap: () => ref.read(manualWeatherQueryProvider.notifier).state =
                            WeatherQuery(lat: region.lat, lon: region.lon, label: region.name),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Space.m),
              if (query == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: EmptyState(
                    icon: Icons.location_searching_rounded,
                    title: 'Où êtes-vous ?',
                    message: 'Touchez « Ma position » ou choisissez votre région.',
                  ),
                )
              else
                ref.watch(weatherReportProvider(query)).when(
                      loading: () => const Padding(padding: EdgeInsets.all(Space.gutter), child: Skeleton(height: 280, radius: 24)),
                      error: (error, _) {
                        if (error is AmbiguousWeatherPlace) {
                          return Padding(padding: const EdgeInsets.symmetric(horizontal: Space.gutter), child: AmbiguousPlaceChooser(error: error));
                        }
                        return ErrorState(
                          message: error is WeatherUnavailable ? error.message : 'Impossible de charger la météo.',
                          onRetry: () => ref.invalidate(weatherReportProvider(query)),
                        );
                      },
                      data: (report) => _Report(report: report),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.out,
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? c.accent : c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: selected ? c.onAccent : c.ink), const SizedBox(width: 6)],
            Text(label, style: T.caption(color: selected ? c.onAccent : c.ink, weight: selected ? 800 : 600)),
          ],
        ),
      ),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final current = report.current;
    final time = measuredAt(current.observedAt);
    final today = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Aujourd'hui : le ciel, la chaleur et la pluie en une phrase. La photo est derrière, jamais devant le texte.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xl),
            child: Stack(
              children: [
                Positioned.fill(child: Image.asset('assets/images/ui/ui_meteo.jpg', fit: BoxFit.cover)),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.45), Colors.black.withValues(alpha: 0.82)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Expanded(child: Text(report.placeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(color: Colors.white, weight: 700))),
                        ],
                      ),
                      const SizedBox(height: Space.l),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(weatherIconFor(current.icon), color: const Color(0xFFFFD54F), size: 76),
                          const SizedBox(width: Space.l),
                          Text('${current.temperature.round()}°', style: T.number(64, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: Space.m),
                      Text(heatSentence(current.temperature), style: T.largeTitle(color: Colors.white).copyWith(fontSize: 28)),
                      const SizedBox(height: Space.xs),
                      Text(skyWords(current.icon), style: T.title(color: Colors.white)),
                      const SizedBox(height: Space.xs),
                      Text(todayRainSentence(current), style: T.body(color: Colors.white, weight: 600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, 0),
          child: Align(alignment: Alignment.centerLeft, child: ReadAloudButton(key: ValueKey('weather-listen-${report.placeName}'), text: weatherSpoken(report, today))),
        ),

        // Que faire : le plus utile, tout de suite sous la météo du jour
        const SectionHeader('Que faire ?'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: report.advice.isEmpty
              ? _AdviceCard(icon: Icons.check_circle_rounded, color: c.accent, text: 'Rien de spécial. Vous pouvez travailler.')
              : Column(
                  children: [
                    for (final line in report.advice) ...[
                      _AdviceCard(icon: Icons.lightbulb_rounded, color: c.gold, text: line),
                      const SizedBox(height: Space.s),
                    ],
                  ],
                ),
        ),

        // Vent et pluie des derniers jours, en mots
        const SizedBox(height: Space.l),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Row(
            children: [
              Expanded(child: _FactCard(icon: Icons.air_rounded, color: c.slate, title: 'Le vent', text: windWords(current.windSpeed))),
              const SizedBox(width: Space.s),
              Expanded(child: _FactCard(icon: Icons.water_drop_rounded, color: c.domainMeteo, title: 'Ces 7 jours', text: recentRainWords(report.rainLast7Days))),
            ],
          ),
        ),

        // Les jours qui viennent
        if (report.forecast.isNotEmpty) ...[
          const SectionHeader('Les jours qui viennent'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Column(
              children: [
                for (var i = 0; i < report.forecast.length; i++) ...[
                  Reveal(index: i, child: _ForecastRow(day: report.forecast[i], today: today)),
                  const SizedBox(height: Space.s),
                ],
              ],
            ),
          ),
        ],

        // Provenance de la mesure : dite, jamais cachée
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, Space.xxl),
          child: Text(
            '${time.isEmpty ? '' : 'Mesuré à $time. '}Source : ${report.sourceName}.',
            style: T.caption(color: c.ink2, weight: 500),
          ),
        ),
      ],
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      color: c.surface,
      padding: const EdgeInsets.all(Space.l),
      child: Row(
        children: [
          IconTile(icon: icon, color: color),
          const SizedBox(width: Space.m),
          Expanded(child: Text(text, style: T.body(color: c.ink, weight: 700))),
        ],
      ),
    );
  }
}

class _FactCard extends StatelessWidget {
  const _FactCard({required this.icon, required this.color, required this.title, required this.text});

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      color: c.surface,
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: color),
          const SizedBox(height: Space.m),
          Text(title, style: T.caption(color: c.ink2, weight: 700)),
          const SizedBox(height: 2),
          Text(text, style: T.body(color: c.ink, weight: 800)),
        ],
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  const _ForecastRow({required this.day, required this.today});

  final ForecastDay day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wet = bringsWater(day.icon);
    final high = day.temperatureMax?.round();
    return AppCard(
      color: c.surface,
      padding: const EdgeInsets.all(Space.l),
      child: Row(
        children: [
          Icon(weatherIconFor(day.icon), size: 40, color: wet ? c.domainMeteo : c.gold),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dayName(day.date, today), style: T.body(color: c.ink, weight: 800)),
                Text(skyWords(day.icon), style: T.caption(color: c.ink2, weight: 600)),
              ],
            ),
          ),
          if (high != null) Text('$high°', style: T.figure(color: c.ink)),
        ],
      ),
    );
  }
}
