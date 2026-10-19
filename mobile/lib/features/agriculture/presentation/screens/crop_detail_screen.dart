import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/data_refresh.dart';
import '../../../../ui/ui.dart';
import '../../data/agriculture_provider.dart';
import '../../data/models/crop.dart';

/// Formate une date en français sans intl (compatible Web et mobile sans locale pack).
String _formatFrenchDate(String? dateStr, {bool short = false}) {
  if (dateStr == null || dateStr.trim().isEmpty) return 'Date non renseignée';
  final date = DateTime.tryParse(dateStr.trim());
  if (date == null) return dateStr;
  const shortMonths = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  const fullMonths = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  final m = (short ? shortMonths : fullMonths)[date.month - 1];
  return '${date.day} $m ${date.year}';
}

/// Formate un montant en FCFA avec séparateur de milliers
String _formatFcfa(double amount) {
  final intVal = amount.round();
  final s = intVal.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(s[i]);
  }
  return buffer.toString();
}

/// Fiche détaillée d'une culture sur l'exploitation : avancement, récoltes réelles,
/// activités de parcelle enregistrées via l'API, conseils agronomiques et valorisation.
class CropDetailScreen extends ConsumerStatefulWidget {
  const CropDetailScreen({super.key, required this.crop});

  final Crop crop;

  @override
  ConsumerState<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends ConsumerState<CropDetailScreen> {
  late String _currentStatus;
  final List<CropActivity> _localAddedActivities = [];
  final List<CropHarvest> _localAddedHarvests = [];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.crop.status;
  }

  // --- Calcul de l'avancement cultural ---
  double? _calculateGrowthProgress(Crop c) {
    final start = c.parsedPlantingDate;
    final end = c.parsedHarvestDate;
    if (start == null || end == null) return null;
    final totalDays = end.difference(start).inDays;
    if (totalDays <= 0) return null;
    final elapsed = DateTime.now().difference(start).inDays;
    return (elapsed / totalDays).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    // Écoute de la liste des cultures pour récupérer les activités et récoltes à jour
    final cropsAsync = ref.watch(cropsProvider);
    final serverCrop = cropsAsync.asData?.value.cast<Crop?>().firstWhere(
      (c) => c?.id == widget.crop.id,
      orElse: () => null,
    );
    final crop = serverCrop ?? widget.crop;

    // Fusion des activités serveur et des activités ajoutées localement dans la session
    final allActivities = <CropActivity>[
      ...crop.activities,
      ..._localAddedActivities.where((a) => !crop.activities.any((sa) => sa.id == a.id)),
    ]..sort((a, b) => (b.parsedDate ?? DateTime(1970)).compareTo(a.parsedDate ?? DateTime(1970)));

    // Fusion des récoltes serveur et des récoltes ajoutées localement dans la session
    final allHarvests = <CropHarvest>[
      ...crop.harvests,
      ..._localAddedHarvests.where((h) => !crop.harvests.any((sh) => sh.id == h.id)),
    ]..sort((a, b) => (b.parsedDate ?? DateTime(1970)).compareTo(a.parsedDate ?? DateTime(1970)));

    final progress = _calculateGrowthProgress(crop);
    final isHarvested = _currentStatus.toLowerCase() == 'harvested' || crop.status.toLowerCase() == 'harvested';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(crop, isHarvested),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Actions rapides (Images d'abord)
                  _buildPhotoActions(crop),
                  const SizedBox(height: 18),

                  // 2. Cycle & Calendrier cultural
                  _buildGrowthCard(crop, progress, isHarvested),
                  const SizedBox(height: 14),

                  // 2. Récoltes déjà enregistrées
                  _buildHarvestsCard(crop, allHarvests, isHarvested),
                  const SizedBox(height: 14),

                  // 3. Activités & Travaux réels (enregistrés via l'API)
                  _buildActivitiesCard(crop, allActivities),
                  const SizedBox(height: 14),

                  // 4. Santé & Suivi phytosanitaire
                  _buildSanitaryCard(crop),
                  const SizedBox(height: 14),

                  // 5. Commercialisation & Marchés
                  _buildMarketCard(crop),
                  const SizedBox(height: 14),

                  // 6. Conseil Naatal IA
                  _buildAiCard(crop),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(crop, isHarvested),
    );
  }

  // ────────────────────────── SliverAppBar ──────────────────────────

  Widget _buildSliverAppBar(Crop crop, bool isHarvested) {
    return SliverAppBar(
      expandedHeight: 250.0,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
        ),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              crop.imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.primary,
                child: const Icon(Icons.eco_rounded, size: 72, color: Colors.white24),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 18,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _statusChip(isHarvested),
                      const SizedBox(width: 8),
                      _glassChip('${crop.areaSize.toStringAsFixed(crop.areaSize.truncateToDouble() == crop.areaSize ? 0 : 1)} ha', Icons.square_foot_rounded),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    crop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          crop.location.isNotEmpty ? crop.location : 'Parcelle d\'exploitation',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(bool isHarvested) {
    final (label, icon, color) = isHarvested
        ? ('RÉCOLTÉE', Icons.check_circle_rounded, const Color(0xFF6FD3A0))
        : (_currentStatus == 'attention'
            ? ('SURVEILLANCE', Icons.warning_amber_rounded, AppColors.warning)
            : ('EN CROISSANCE', Icons.grass_rounded, Colors.white));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _glassChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ────────────────────────── 0. Actions rapides photo ──────────────────────────

  Widget _buildPhotoActions(Crop crop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions de la parcelle',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PhotoTile(
                imageAsset: 'assets/images/ui/ui_arroser.jpg',
                label: 'Arroser',
                icon: Icons.water_drop_rounded,
                height: 110,
                onTap: () => _performQuickActivity(
                  crop,
                  type: 'irrigation',
                  label: 'Arrosage',
                  icon: Icons.water_drop_rounded,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PhotoTile(
                imageAsset: 'assets/images/ui/ui_engrais.jpg',
                label: 'Engrais',
                icon: Icons.grain_rounded,
                height: 110,
                onTap: () => _performQuickActivity(
                  crop,
                  type: 'fertilisation',
                  label: 'Engrais',
                  icon: Icons.grain_rounded,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PhotoTile(
                imageAsset: 'assets/images/ui/ui_traiter.jpg',
                label: 'Traiter',
                icon: Icons.health_and_safety_rounded,
                height: 110,
                onTap: () => _performQuickActivity(
                  crop,
                  type: 'traitement',
                  label: 'Traitement',
                  icon: Icons.health_and_safety_rounded,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PhotoTile(
                imageAsset: 'assets/images/ui/ui_recolter_geste.jpg',
                label: 'Récolter',
                icon: Icons.agriculture_rounded,
                height: 110,
                onTap: () => _showHarvestDialog(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _performQuickActivity(
    Crop crop, {
    required String type,
    required String label,
    required IconData icon,
  }) {
    final costController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Enregistrer $label', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          Text(crop.name, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Coût en FCFA (optionnel)',
                    labelStyle: const TextStyle(fontSize: 13),
                    hintText: '0 FCFA',
                    prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Note ou observation (optionnel)',
                    labelStyle: const TextStyle(fontSize: 13),
                    hintText: 'Ex: engrais NPK, dose habituelle',
                    prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                      final rawCost = costController.text.trim().replaceAll(' ', '').replaceAll(',', '.');
                      final cost = double.tryParse(rawCost);
                      final desc = descController.text.trim().isNotEmpty ? descController.text.trim() : label;

                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      try {
                        await ref.read(agricultureRepositoryProvider).addActivity(
                          cropId: crop.id,
                          type: type,
                          date: dateStr,
                          description: desc,
                          cost: cost,
                        );

                        if (!mounted) return;

                        setState(() {
                          _localAddedActivities.add(
                            CropActivity(
                              id: 'local_${now.millisecondsSinceEpoch}',
                              cropId: crop.id,
                              activityType: type,
                              description: desc,
                              date: dateStr,
                              cost: cost,
                              createdAt: now.toIso8601String(),
                            ),
                          );
                        });

                        refreshAfterDataChange(ref);
                        nav.pop();

                        final size = MediaQuery.of(context).size;
                        await showSuccessReveal(
                          context,
                          origin: Offset(size.width / 2, size.height * 0.8),
                          headline: 'INTERVENTION ENREGISTRÉE',
                          title: label,
                          details: [
                            crop.name,
                            cost != null && cost > 0 ? '${_formatFcfa(cost)} FCFA' : 'Sans coût supplémentaire',
                            desc,
                          ],
                          doneLabel: 'Super',
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Impossible d\'enregistrer : $e'),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Valider $label', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────── 1. Cycle & Calendrier ──────────────────────────

  Widget _buildGrowthCard(Crop crop, double? progress, bool isHarvested) {
    final days = crop.daysToHarvest;
    final progressVal = isHarvested ? 1.0 : (progress ?? 0.0);
    final percent = (progressVal * 100).toInt();

    final caption = isHarvested
        ? 'Cycle achevé'
        : days == null
            ? 'Dates à renseigner'
            : days < 0
                ? 'Récolte attendue il y a ${-days} j'
                : days == 0
                    ? 'Récolte aujourd\'hui'
                    : 'Récolte dans $days j';

    return _cardContainer(
      title: 'Cycle cultural',
      trailing: Text(
        isHarvested ? '100%' : (progress == null ? '—' : '$percent%'),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressVal,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stageColumn('Semis', _formatFrenchDate(crop.plantingDate, short: true), CrossAxisAlignment.start),
              _stageColumn('État', caption, CrossAxisAlignment.center, isHighlight: true),
              _stageColumn('Récolte prévue', _formatFrenchDate(crop.expectedHarvestDate, short: true), CrossAxisAlignment.end),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stageColumn(String label, String value, CrossAxisAlignment align, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w600,
            color: isHighlight ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ────────────────────────── 2. Récoltes enregistrées ──────────────────────────

  Widget _buildHarvestsCard(Crop crop, List<CropHarvest> harvests, bool isHarvested) {
    final double totalHarvested = harvests.fold<double>(0, (sum, h) => sum + h.quantity);
    final primaryUnit = harvests.isNotEmpty ? harvests.first.unit : 'kg';

    return _cardContainer(
      title: 'Récoltes enregistrées',
      tag: harvests.isNotEmpty ? '${harvests.length}' : null,
      trailing: TextButton.icon(
        onPressed: () => _showHarvestDialog(context),
        icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
        label: const Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (harvests.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.agriculture_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Total récolté : ${totalHarvested.toStringAsFixed(totalHarvested.truncateToDouble() == totalHarvested ? 0 : 1)} $primaryUnit',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            for (final h in harvests) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.inventory_2_rounded, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${h.quantity.toStringAsFixed(h.quantity.truncateToDouble() == h.quantity ? 0 : 1)} ${h.unit}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              ),
                              Text(
                                _formatFrenchDate(h.date, short: true),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          if (h.notes.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              h.notes,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isHarvested
                          ? 'Cette culture est marquée récoltée, mais aucune pesée détaillée n\'a été enregistrée.'
                          : 'Aucune récolte enregistrée pour le moment. Enregistrez la pesée dès la coupe pour incrémenter le stock.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ────────────────────────── 3. Activités & Travaux réels ──────────────────────────

  Widget _buildActivitiesCard(Crop crop, List<CropActivity> activities) {
    return _cardContainer(
      title: 'Activités & travaux',
      tag: activities.isNotEmpty ? '${activities.length}' : null,
      trailing: TextButton.icon(
        onPressed: () => _showAddActivityDialog(context, crop),
        icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
        label: const Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activities.isNotEmpty) ...[
            for (final act in activities) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_activityIcon(act.activityType), size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _readableActivityType(act.activityType),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              Text(
                                _formatFrenchDate(act.date, short: true),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          if (act.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              act.description,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                            ),
                          ],
                          if (act.cost != null && act.cost! > 0) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_formatFcfa(act.cost!)} F (dépense enregistrée)',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Aucune intervention enregistrée sur cette parcelle. Notez vos arrosages, engrais et traitements pour suivre vos coûts.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _activityIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('arros') || t.contains('irrig')) return Icons.water_drop_rounded;
    if (t.contains('engrais') || t.contains('fertil')) return Icons.eco_rounded;
    if (t.contains('trait') || t.contains('phyto') || t.contains('pestic')) return Icons.healing_rounded;
    if (t.contains('desherb') || t.contains('sarcl')) return Icons.content_cut_rounded;
    if (t.contains('semis') || t.contains('plant')) return Icons.grass_rounded;
    if (t.contains('recolt')) return Icons.agriculture_rounded;
    if (t.contains('butt')) return Icons.landscape_rounded;
    return Icons.event_note_rounded;
  }

  String _readableActivityType(String type) {
    final t = type.toLowerCase();
    if (t == 'irrigation') return 'Irrigation / Arrosage';
    if (t == 'fertilisation') return 'Fertilisation / Engrais';
    if (t == 'traitement') return 'Traitement phytosanitaire';
    if (t == 'desherbage') return 'Désherbage / Sarclage';
    if (t == 'semis') return 'Semis / Repiquage';
    if (t == 'recolte') return 'Récolte';
    if (t == 'buttage') return 'Buttage';
    return type.isNotEmpty ? '${type[0].toUpperCase()}${type.substring(1)}' : 'Intervention';
  }

  // ────────────────────────── 4. Suivi phytosanitaire ──────────────────────────

  Widget _buildSanitaryCard(Crop crop) {
    final hasGuide = crop.guideSlug != null && crop.guideSlug!.isNotEmpty;

    return _cardContainer(
      title: 'Santé phytosanitaire',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Parcelle sous contrôle', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      'Aucune alerte sanitaire ou parasitaire majeure n\'a été signalée pour cette culture à ${crop.location.isNotEmpty ? crop.location : "votre zone"}.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasGuide) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => context.push('/agriculture/guides/${crop.guideSlug}'),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: const [
                    Text(
                      'Consulter la fiche technique de référence',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ────────────────────────── 5. Commercialisation ──────────────────────────

  Widget _buildMarketCard(Crop crop) {
    return _cardContainer(
      title: 'Marchés & Commercialisation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.push('/market_comparison', extra: {
                      'productName': crop.cropType.isNotEmpty ? crop.cropType : crop.name,
                      'imageAsset': crop.imageAsset,
                      'price': '',
                    });
                  },
                  icon: const Icon(Icons.storefront_rounded, size: 16),
                  label: const Text('Comparer les cours'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCreatePriceAlertDialog(context, crop),
                  icon: const Icon(Icons.notifications_active_rounded, size: 16),
                  label: const Text('Alerte de prix'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ────────────────────────── 6. Conseil IA ──────────────────────────

  Widget _buildAiCard(Crop crop) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/ai'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Besoin d\'un conseil agronomique ?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      'Demandez à Naatal IA des recommandations personnalisées pour ${crop.name}.',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────── BottomBar ──────────────────────────

  Widget _buildBottomBar(Crop crop, bool isHarvested) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddActivityDialog(context, crop),
                  icon: const Icon(Icons.post_add_rounded, size: 20),
                  label: const Text('Activité'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: isHarvested ? () => context.push('/stock') : () => _showHarvestDialog(context),
                  icon: Icon(isHarvested ? Icons.inventory_2_rounded : Icons.agriculture_rounded, size: 20),
                  label: Text(isHarvested ? 'Voir en Stock' : 'Enregistrer la récolte'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────── Helper Container ──────────────────────────

  Widget _cardContainer({required String title, String? tag, Widget? trailing, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  if (tag != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(tag, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
                    ),
                  ],
                ],
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ────────────────────────── Dialogs ──────────────────────────

  void _showAddActivityDialog(BuildContext context, Crop crop) {
    final descController = TextEditingController();
    final costController = TextEditingController();
    String activityType = 'irrigation';
    DateTime selectedDate = DateTime.now();

    final activityOptions = const [
      ('irrigation', 'Irrigation / Arrosage'),
      ('fertilisation', 'Fertilisation / Engrais'),
      ('traitement', 'Traitement phytosanitaire'),
      ('desherbage', 'Désherbage / Sarclage'),
      ('semis', 'Semis / Repiquage'),
      ('buttage', 'Buttage'),
      ('recolte', 'Travail de récolte'),
      ('autre', 'Autre intervention'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Nouvelle activité', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: activityType,
                  decoration: InputDecoration(
                    labelText: 'Type d\'intervention',
                    labelStyle: const TextStyle(fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: [
                    for (final opt in activityOptions)
                      DropdownMenuItem(value: opt.$1, child: Text(opt.$2, style: const TextStyle(fontSize: 13))),
                  ],
                  onChanged: (val) {
                    if (val != null) setSheetState(() => activityType = val);
                  },
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setSheetState(() => selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date de l\'intervention',
                      labelStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description ou observations',
                    labelStyle: const TextStyle(fontSize: 13),
                    hintText: 'Ex: 2 sacs de NPK, désherbage manuel...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Coût en FCFA (optionnel)',
                    labelStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
                      final rawCost = costController.text.trim().replaceAll(' ', '').replaceAll(',', '.');
                      final cost = double.tryParse(rawCost);
                      final optLabel = activityOptions.firstWhere((o) => o.$1 == activityType, orElse: () => ('', 'Intervention')).$2;
                      final desc = descController.text.trim().isNotEmpty ? descController.text.trim() : optLabel;

                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      try {
                        await ref.read(agricultureRepositoryProvider).addActivity(
                          cropId: crop.id,
                          type: activityType,
                          date: dateStr,
                          description: desc,
                          cost: cost,
                        );

                        setState(() {
                          _localAddedActivities.add(
                            CropActivity(
                              id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                              cropId: crop.id,
                              activityType: activityType,
                              description: desc,
                              date: dateStr,
                              cost: cost,
                              createdAt: DateTime.now().toIso8601String(),
                            ),
                          );
                        });

                        refreshAfterDataChange(ref);
                        nav.pop();

                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text('Activité enregistrée avec succès !'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      } catch (e) {
                        String errorText = 'Impossible d\'enregistrer l\'activité.';
                        if (e is DioException) {
                          final data = e.response?.data;
                          if (data is Map) {
                            final firstVal = data.values.first;
                            if (firstVal is List && firstVal.isNotEmpty) {
                              errorText = firstVal.first.toString();
                            } else if (firstVal is String) {
                              errorText = firstVal;
                            } else if (data['detail'] != null) {
                              errorText = data['detail'].toString();
                            }
                          } else if (e.response?.statusCode == 400) {
                            errorText = 'Données d\'activité invalides. Veuillez vérifier les champs.';
                          } else if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
                            errorText = 'Vous n\'êtes pas autorisé à modifier cette culture.';
                          }
                        }
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(errorText),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Enregistrer l\'activité', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHarvestDialog([BuildContext? _]) {
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    String unit = 'kg';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pesée de récolte : ${widget.crop.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cette pesée enregistre la production récoltée et l\'ajoute automatiquement à votre inventaire de stock.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quantité',
                          labelStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.scale_rounded, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: unit,
                        decoration: InputDecoration(
                          labelText: 'Unité',
                          labelStyle: const TextStyle(fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'kg', child: Text('kg', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'tonnes', child: Text('tonnes', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem(value: 'sacs', child: Text('sacs', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (val) {
                          if (val != null) setSheetState(() => unit = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Observations (optionnel)',
                    labelStyle: const TextStyle(fontSize: 13),
                    hintText: 'Ex: Qualité supérieure, première passe...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final qty = double.tryParse(quantityController.text.trim()) ?? 0.0;
                      if (qty <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez saisir une quantité valide')),
                        );
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(ctx);

                      try {
                        await ref.read(agricultureRepositoryProvider).harvestCrop(
                          widget.crop.id,
                          quantity: qty,
                          unit: unit,
                          notes: notesController.text.trim(),
                        );

                        if (!mounted) return;

                        final now = DateTime.now();
                        final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

                        setState(() {
                          _currentStatus = 'harvested';
                          _localAddedHarvests.add(
                            CropHarvest(
                              id: 'local_${now.millisecondsSinceEpoch}',
                              quantity: qty,
                              unit: unit,
                              date: dateStr,
                              notes: notesController.text.trim(),
                            ),
                          );
                        });

                        refreshAfterDataChange(ref);
                        nav.pop();

                        final size = MediaQuery.of(context).size;
                        await showSuccessReveal(
                          context,
                          origin: Offset(size.width / 2, size.height * 0.8),
                          headline: 'RÉCOLTE ENREGISTRÉE',
                          title: '$qty $unit',
                          details: [
                            widget.crop.name,
                            'Production ajoutée à votre stock',
                            if (notesController.text.trim().isNotEmpty) notesController.text.trim(),
                          ],
                          doneLabel: 'Super',
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Erreur: $e'),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Confirmer la pesée', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreatePriceAlertDialog(BuildContext context, Crop crop) {
    final priceController = TextEditingController();
    String alertCondition = 'greater';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Alerte de cours : ${crop.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: alertCondition,
                  decoration: InputDecoration(
                    labelText: 'Condition de déclenchement',
                    labelStyle: const TextStyle(fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'greater', child: Text('Quand le prix dépasse (> )', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'lower', child: Text('Quand le prix descend sous (< )', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (val) {
                    if (val != null) setSheetState(() => alertCondition = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Prix seuil cible (FCFA / kg)',
                    labelStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final val = priceController.text.trim();
                      if (val.isEmpty) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Alerte enregistrée : alerte dès que le cours est ${alertCondition == "greater" ? ">" : "<"} $val FCFA/kg'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Activer l\'alerte', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
