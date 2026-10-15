import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/weather_provider.dart';
import '../../data/models/weather_forecast.dart';

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
    final selectedRegion = ref.watch(selectedWeatherLocationProvider);
    final weatherAsync = ref.watch(weatherForecastProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Météo Agricole & Prévisions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(weatherForecastProvider),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // Sélecteur de régions
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: regions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    final isSelected = region == selectedRegion;
                    return FilterChip(
                      selected: isSelected,
                      label: Text(region),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide.none,
                      showCheckmark: false,
                      onSelected: (_) {
                        ref.read(selectedWeatherLocationProvider.notifier).state = region;
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          // Contenu principal
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: weatherAsync.when(
              data: (data) => SliverList(
                delegate: SliverChildListDelegate([
                  _buildCurrentWeatherCard(data),
                  const SizedBox(height: 20),
                  _buildAgroAdviceSection(data),
                  const SizedBox(height: 24),
                  const Text(
                    'Prévisions sur 5 jours',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  ...data.forecast.map((f) => _buildForecastDayTile(f)),
                  const SizedBox(height: 40),
                ]),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
              error: (err, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text('Erreur de chargement: $err', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(weatherForecastProvider),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWeatherCard(WeatherForecastData data) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    data.location,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Aujourd\'hui',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${data.currentTemp.round()}°C',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, height: 1.0),
              ),
              const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFFD54F), size: 54),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeatherStat(Icons.water_drop_rounded, '${data.currentHumidity}%', 'Humidité'),
                _buildWeatherStat(Icons.grain_rounded, '${data.currentRainfall} mm', 'Pluie'),
                _buildWeatherStat(Icons.air_rounded, '14 km/h', 'Vent'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _buildAgroAdviceSection(WeatherForecastData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.psychology_alt_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Recommandations Agronomiques',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...data.agriculturalAdvice.map(
            (advice) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                  Expanded(
                    child: Text(
                      advice,
                      style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastDayTile(WeatherDay day) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              day.date,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
            ),
          ),
          const Icon(Icons.wb_cloudy_rounded, color: Color(0xFF3B82F6), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              day.description,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Text(
            '${day.tempMax.round()}° / ${day.tempMin.round()}°',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
