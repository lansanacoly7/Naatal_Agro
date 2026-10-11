import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/offline_cache_banner.dart';
import '../../data/guides_provider.dart';
import '../../data/models/agronomic_guide.dart';

class GuideDetailScreen extends ConsumerWidget {
  final String slug;

  const GuideDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(guideDetailProvider(slug));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          state.guide?.name ?? 'Fiche Technique',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, GuideDetailState state) {
    if (state.isLoading && state.guide == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (state.error != null && state.guide == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(guideDetailProvider(slug).notifier).loadGuide(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final guide = state.guide!;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(guideDetailProvider(slug).notifier).loadGuide();
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.isFromCache && state.cachedAt != null)
              OfflineCacheBanner(cachedAt: state.cachedAt!),
            _buildHeader(guide),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    icon: Icons.info_outline,
                    title: 'Présentation & Description',
                    content: guide.summary,
                  ),
                  if (guide.zones.isNotEmpty)
                    _buildSection(
                      icon: Icons.map_outlined,
                      title: 'Zones de culture au Sénégal',
                      content: guide.zones,
                    ),
                  if (guide.calendar.isNotEmpty)
                    _buildSection(
                      icon: Icons.calendar_today_outlined,
                      title: 'Calendrier & Cycle de culture',
                      content: guide.calendar,
                    ),
                  if (guide.soilAndSowing.isNotEmpty)
                    _buildSection(
                      icon: Icons.grass,
                      title: 'Sol, préparation et semis',
                      content: guide.soilAndSowing,
                    ),
                  if (guide.waterNeeds.isNotEmpty)
                    _buildSection(
                      icon: Icons.water_drop_outlined,
                      title: 'Besoins en eau & Irrigation',
                      content: guide.waterNeeds,
                    ),
                  if (guide.fertilization.isNotEmpty)
                    _buildSection(
                      icon: Icons.science_outlined,
                      title: 'Fertilisation & Fumure',
                      content: guide.fertilization,
                    ),
                  if (guide.pestsDiseases.isNotEmpty)
                    _buildPestsSection(guide.pestsDiseases),
                  if (guide.harvest.isNotEmpty)
                    _buildSection(
                      icon: Icons.agriculture_outlined,
                      title: 'Récolte & Conservation',
                      content: guide.harvest,
                    ),
                  if (guide.yieldInfo.isNotEmpty)
                    _buildSection(
                      icon: Icons.trending_up,
                      title: 'Rendements observés',
                      content: guide.yieldInfo,
                    ),
                  if (guide.limitations.isNotEmpty)
                    _buildLimitationsCard(guide.limitations),
                  const SizedBox(height: 8),
                  _buildSourcesSection(guide.sources),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AgronomicGuide guide) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  guide.categoryLabel,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (guide.cycleDisplay != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    guide.cycleDisplay!,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            guide.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          if (guide.scientificName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              guide.scientificName,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildPestsSection(List<PestDiseaseItem> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report_outlined, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Maladies, Ravageurs & Protection',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ${p.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      p.advice,
                      style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
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

  Widget _buildLimitationsCard(String limitations) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Précautions & Limites',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.brown),
                ),
                const SizedBox(height: 4),
                Text(
                  limitations,
                  style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.brown),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourcesSection(List<GuideSource> sources) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Sources Scientifiques & Institutionnelles',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sources.isEmpty)
            Text('Aucune source spécifiée.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ...sources.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final src = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('[$idx] ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Expanded(
                        child: Text(
                          src.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (src.publisher.isNotEmpty || src.year.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 2),
                      child: Text(
                        '${src.publisher}${src.year.isNotEmpty ? ' (${src.year})' : ''}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: src.isSenegal ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        src.isSenegal ? 'Référence officielle Sénégal' : 'Référence hors Sénégal, à adapter',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: src.isSenegal ? Colors.green.shade800 : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
