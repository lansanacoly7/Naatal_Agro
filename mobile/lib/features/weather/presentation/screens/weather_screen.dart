import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../ui/ui.dart';
import '../../data/weather_provider.dart';

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  static const regions = [
    'Dakar',
    'Thiès',
    'Kaolack',
    'Saint-Louis',
    'Touba',
    'Ziguinchor',
    'Kolda',
    'Tambacounda',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final selectedRegion = ref.watch(selectedWeatherLocationProvider);
    final weatherAsync = ref.watch(weatherForecastProvider);

    return LargeTitleScaffold(
      title: 'Météo agricole',
      eyebrow: selectedRegion,
      reserveNav: false,
      onRefresh: () async => ref.invalidate(weatherForecastProvider),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sélecteur de région en pilules
              SizedBox(
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  scrollDirection: Axis.horizontal,
                  itemCount: regions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: Space.s),
                  itemBuilder: (context, i) {
                    final region = regions[i];
                    final isSelected = region == selectedRegion;
                    return PressScale(
                      onTap: () {
                        ref.read(selectedWeatherLocationProvider.notifier).state = region;
                      },
                      child: AnimatedContainer(
                        duration: Motion.base,
                        curve: Motion.out,
                        padding: const EdgeInsets.symmetric(horizontal: Space.l),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? c.accent : c.surface,
                          borderRadius: BorderRadius.circular(Radii.pill),
                          border: Border.all(color: isSelected ? c.accent : c.line),
                        ),
                        child: Text(
                          region,
                          style: T.caption(
                            color: isSelected ? c.onAccent : c.ink,
                            weight: isSelected ? 800 : 600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: Space.m),

              // Contenu principal
              weatherAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(Space.gutter),
                  child: Skeleton(height: 280, radius: 24),
                ),
                error: (err, _) => ErrorState(
                  message: 'Impossible de charger la météo pour $selectedRegion.',
                  onRetry: () => ref.invalidate(weatherForecastProvider),
                ),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Grande carte hero météo avec photo
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Radii.xl),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/ui/ui_meteo.jpg'),
                            fit: BoxFit.cover,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: c.isDark ? 0.35 : 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(Space.xl),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Radii.xl),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                Colors.black.withValues(alpha: 0.88),
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        data.location,
                                        style: T.caption(color: Colors.white, weight: 700),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(Radii.pill),
                                    ),
                                    child: Text(
                                      'Aujourd\'hui',
                                      style: T.caption(color: Colors.white, weight: 700),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Space.l),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${data.currentTemp.round()}°C',
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1.0,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFFD54F), size: 48),
                                ],
                              ),
                              const SizedBox(height: Space.l),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(Radii.m),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _Stat(icon: Icons.water_drop_rounded, value: '${data.currentHumidity}%', label: 'Humidité'),
                                    _Stat(icon: Icons.grain_rounded, value: '${data.currentRainfall} mm', label: 'Pluie'),
                                    _Stat(icon: Icons.air_rounded, value: '14 km/h', label: 'Vent'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Recommandations agronomiques
                    if (data.agriculturalAdvice.isNotEmpty) ...[
                      const SectionHeader('Impact sur vos travaux'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                        child: Column(
                          children: [
                            for (var i = 0; i < data.agriculturalAdvice.length; i++) ...[
                              AppCard(
                                color: c.surface,
                                padding: const EdgeInsets.all(Space.l),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: c.accent.withValues(alpha: c.isDark ? 0.25 : 0.1),
                                        borderRadius: BorderRadius.circular(Radii.m),
                                      ),
                                      child: Icon(Icons.eco_rounded, color: c.accent, size: 20),
                                    ),
                                    const SizedBox(width: Space.m),
                                    Expanded(
                                      child: Text(
                                        data.agriculturalAdvice[i],
                                        style: T.body(color: c.ink),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: Space.s),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Prévisions sur 5 jours
                    if (data.forecast.isNotEmpty) ...[
                      const SectionHeader('Prévisions sur 5 jours'),
                      GroupedList(
                        children: [
                          for (var i = 0; i < data.forecast.length; i++)
                            Reveal(
                              index: i,
                              child: GroupedRow(
                                leading: IconTile(
                                  icon: _weatherIcon(data.forecast[i].description),
                                  color: c.slate,
                                ),
                                title: data.forecast[i].date,
                                subtitle: data.forecast[i].description,
                                value: '${data.forecast[i].tempMax.round()}° / ${data.forecast[i].tempMin.round()}°',
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: Space.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _weatherIcon(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('pluie') || d.contains('averse')) return Icons.grain_rounded;
    if (d.contains('nuag') || d.contains('couvert')) return Icons.wb_cloudy_rounded;
    if (d.contains('orage')) return Icons.thunderstorm_rounded;
    return Icons.wb_sunny_rounded;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 3),
        Text(value, style: T.caption(color: Colors.white, weight: 800)),
        Text(label, style: T.caption(color: Colors.white70, weight: 500)),
      ],
    );
  }
}
