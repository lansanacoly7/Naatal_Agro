import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/offline_cache_banner.dart';
import '../../data/guides_provider.dart';
import '../../data/models/agronomic_guide.dart';

import '../../../../ui/ui.dart';
class GuideDetailScreen extends ConsumerWidget {
  final String slug;

  const GuideDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(guideDetailProvider(slug));

    return Scaffold(
      backgroundColor: context.c.bg,
      appBar: AppBar(
        backgroundColor: context.c.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.c.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          state.guide?.name ?? 'Fiche Technique',
          style: TextStyle(color: context.c.ink, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, GuideDetailState state) {
    if (state.isLoading && state.guide == null) {
      return Center(child: CircularProgressIndicator(color: context.c.accent));
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
      color: context.c.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.isFromCache && state.cachedAt != null)
              OfflineCacheBanner(cachedAt: state.cachedAt!),
            _buildHeader(context, guide),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(context, 
                    icon: Icons.info_outline,
                    title: 'Présentation & Description',
                    content: guide.summary,
                  ),
                  if (guide.zones.isNotEmpty)
                    _buildSection(context, 
                      icon: Icons.map_outlined,
                      title: 'Zones de culture au Sénégal',
                      content: guide.zones,
                    ),
                  if (guide.calendar.isNotEmpty)
                    _buildSection(context, 
                      icon: Icons.calendar_today_outlined,
                      title: 'Calendrier & Cycle de culture',
                      content: guide.calendar,
                    ),
                  if (guide.soilAndSowing.isNotEmpty)
                    _buildSection(context, 
                      icon: Icons.grass,
                      title: 'Sol, préparation et semis',
                      content: guide.soilAndSowing,
                    ),
                  if (guide.waterNeeds.isNotEmpty)
                    _buildSection(context, 
                      icon: Icons.water_drop_outlined,
                      title: 'Besoins en eau & Irrigation',
                      content: guide.waterNeeds,
                    ),
                  if (guide.fertilization.isNotEmpty)
                    _buildSection(context, 
                      icon: Icons.science_outlined,
                      title: 'Fertilisation & Fumure',
                      content: guide.fertilization,
                    ),
                  if (guide.pestsDiseases.isNotEmpty)
                    _buildPestsSection(context, guide.pestsDiseases),
                  if (guide.harvest.isNotEmpty)
                    _buildSection(context, 
                      icon: Icons.agriculture_outlined,
                      title: 'Récolte & Conservation',
                      content: guide.harvest,
                    ),
                  if (guide.yieldInfo.isNotEmpty)
                    _buildSection(context, 
                      icon: Icons.trending_up,
                      title: 'Rendements observés',
                      content: guide.yieldInfo,
                    ),
                  if (guide.limitations.isNotEmpty)
                    _buildLimitationsCard(context, guide.limitations),
                  const SizedBox(height: 8),
                  _buildSourcesSection(context, guide.sources),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AgronomicGuide guide) {
    return Container(
      width: double.infinity,
      color: context.c.surface,
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
                  style: TextStyle(
                    color: context.c.accent,
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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.c.ink),
          ),
          if (guide.scientificName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              guide.scientificName,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: context.c.ink2,
                fontSize: 15,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.c.surface,
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
              Icon(icon, color: context.c.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.c.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(fontSize: 14, height: 1.5, color: context.c.ink),
          ),
        ],
      ),
    );
  }

  Widget _buildPestsSection(BuildContext context, List<PestDiseaseItem> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.c.surface,
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
                      style: TextStyle(fontSize: 13, height: 1.4, color: context.c.ink),
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

  Widget _buildLimitationsCard(BuildContext context, String limitations) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.c.gold.withValues(alpha: 0.16),
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

  Widget _buildSourcesSection(BuildContext context, List<GuideSource> sources) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.c.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, color: context.c.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'Sources Scientifiques & Institutionnelles',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sources.isEmpty)
            Text('Aucune source spécifiée.', style: TextStyle(color: context.c.ink2, fontSize: 13)),
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
                        style: TextStyle(color: context.c.ink2, fontSize: 12),
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
