import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/crop.dart';
import '../../data/agriculture_provider.dart';
import '../../../../shared/utils/data_refresh.dart';

class CropDetailScreen extends ConsumerStatefulWidget {
  final Crop crop;

  const CropDetailScreen({super.key, required this.crop});

  @override
  ConsumerState<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends ConsumerState<CropDetailScreen> {
  final Set<String> _completedTasks = {'Irrigation approfondie'};
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.crop.status;
  }

  // --- Helpers for Growth Calculation ---
  double _calculateGrowthProgress() {
    try {
      final start = DateTime.parse(widget.crop.plantingDate);
      final end = DateTime.parse(widget.crop.expectedHarvestDate);
      final now = DateTime.now();

      if (now.isBefore(start)) return 0.0;
      if (now.isAfter(end)) return 1.0;

      final totalDuration = end.difference(start).inDays;
      final elapsed = now.difference(start).inDays;

      return elapsed / totalDuration;
    } catch (e) {
      return 0.5; // fallback if dates are invalid
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy', 'fr_FR').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _calculateGrowthProgress();
    final progressPercent = (progress * 100).toInt();

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _currentStatus == 'active'
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ElevatedButton.icon(
                  onPressed: () => _showHarvestDialog(context),
                  icon: const Icon(Icons.agriculture_rounded, color: Colors.white),
                  label: const Text(
                    'Enregistrer la récolte (Ajouter au stock)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                ),
              ),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGrowthSection(progress, progressPercent),
                  const SizedBox(height: 32),
                  _buildAiCard(),
                  const SizedBox(height: 32),
                  _buildTasksSection(),
                  const SizedBox(height: 32),
                  _buildRisksSection(),
                  const SizedBox(height: 32),
                  _buildSalesSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.go('/ai');
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.green, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Besoin d\'un conseil ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                      SizedBox(height: 4),
                      Text('Demandez à Naatal IA des recommandations personnalisées pour cette culture.', style: TextStyle(color: Colors.black87, fontSize: 12, height: 1.4)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.green, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280.0,
      pinned: true,
      backgroundColor: AppColors.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              widget.crop.imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildGlassChip(
                        _currentStatus == 'active' ? 'EN CROISSANCE' : 'RÉCOLTÉ',
                        Icons.eco,
                        _currentStatus == 'active' ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 8),
                      _buildGlassChip('${widget.crop.areaSize} ha', Icons.square_foot, Colors.white),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.crop.name,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        widget.crop.location,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
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

  Widget _buildGlassChip(String label, IconData? icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthSection(double progress, int progressPercent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Stade de croissance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            Text('$progressPercent%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: Colors.grey.shade200,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStageInfo('Semis', _formatDate(widget.crop.plantingDate), progress >= 0.0, CrossAxisAlignment.start),
            _buildStageInfo('Croissance', 'En cours', progress > 0.0 && progress < 1.0, CrossAxisAlignment.center),
            _buildStageInfo('Récolte', _formatDate(widget.crop.expectedHarvestDate), progress >= 1.0, CrossAxisAlignment.end),
          ],
        ),
      ],
    );
  }

  Widget _buildStageInfo(String title, String subtitle, bool isActive, CrossAxisAlignment alignment) {
    return Expanded(
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: 11,
              color: isActive ? AppColors.textPrimary : Colors.grey.shade500,
            ),
            textAlign: alignment == CrossAxisAlignment.end 
                ? TextAlign.right 
                : alignment == CrossAxisAlignment.center 
                    ? TextAlign.center 
                    : TextAlign.left,
          ),
        ],
      ),
    );
  }

  Widget _buildTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Ce qu'il faut faire (Plan d'action)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        _buildTaskTile('Irrigation approfondie', 'Aujourd\'hui'),
        _buildTaskTile('Apport d\'engrais NPK', 'Demain'),
        _buildTaskTile('Sarclage', 'Dans 3 jours'),
      ],
    );
  }

  Widget _buildTaskTile(String title, String time) {
    final isDone = _completedTasks.contains(title);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () {
          setState(() {
            if (isDone) {
              _completedTasks.remove(title);
            } else {
              _completedTasks.add(title);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isDone ? 'Tâche "$title" marquée non terminée' : 'Bravo ! Tâche "$title" accomplie'),
              duration: const Duration(seconds: 2),
              backgroundColor: isDone ? Colors.grey.shade800 : AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        leading: Icon(
          isDone ? Icons.check_circle : Icons.circle_outlined,
          color: isDone ? Colors.green : Colors.grey.shade400,
        ),
        title: Text(
          title,
          style: TextStyle(
            decoration: isDone ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
            color: isDone ? Colors.grey : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(time, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: Icon(
          isDone ? Icons.done_all_rounded : Icons.touch_app_outlined,
          size: 16,
          color: isDone ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildRisksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Prévention & Risques", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Risque de Mildiou élevé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
                    SizedBox(height: 4),
                    Text(
                      'L\'humidité récente augmente fortement le risque d\'apparition de maladies fongiques. Il est impératif d\'appliquer un traitement préventif dans les 48h.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalesSection() {
    final isHarvested = _currentStatus == 'harvested';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Gestion du Stock & Vente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            OutlinedButton.icon(
              onPressed: () => _showCreatePriceAlertDialog(context),
              icon: const Icon(Icons.notifications_active, size: 16, color: AppColors.primary),
              label: const Text('Alerte prix', style: TextStyle(color: AppColors.primary, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHarvested ? Colors.green.withValues(alpha: 0.05) : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isHarvested ? Colors.green.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isHarvested ? Icons.check_circle_rounded : Icons.inventory_2,
                    color: isHarvested ? Colors.green : AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isHarvested ? 'Récolte effectuée — En Stock' : 'Cycle de Récolte & Commercialisation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isHarvested ? Colors.green.shade800 : AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isHarvested
                    ? 'La récolte a été enregistrée avec succès. La production a été ajoutée à vos stocks et est prête à être commercialisée ou conservée.'
                    : 'Dès que la récolte est prête, enregistrez-la pour transférer automatiquement le volume dans vos stocks et suivre vos revenus.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              if (!isHarvested) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showHarvestDialog(context),
                    icon: const Icon(Icons.agriculture_rounded, color: Colors.white),
                    label: const Text(
                      'Enregistrer la récolte (Transférer au Stock)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/inventory'),
                    icon: const Icon(Icons.inventory_2_rounded, color: Colors.white),
                    label: const Text(
                      'Voir les stocks & Enregistrer une vente',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    context.push('/market_comparison', extra: {
                      'productName': widget.crop.cropType,
                      'imageAsset': widget.crop.imageAsset,
                      'price': '',
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Analyser les prix du marché', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreatePriceAlertDialog(BuildContext context) {
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
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Alerte de prix : ${widget.crop.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: alertCondition,
                  decoration: InputDecoration(
                    labelText: 'Condition de déclenchement',
                    prefixIcon: const Icon(Icons.tune_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'greater', child: Text('Quand le prix dépasse (> )')),
                    DropdownMenuItem(value: 'lower', child: Text('Quand le prix descend sous (< )')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setSheetState(() => alertCondition = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Prix seuil cible (FCFA / kg)',
                    prefixIcon: const Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      final val = priceController.text.trim();
                      if (val.isEmpty) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Alerte enregistrée : alerte si le prix de ${widget.crop.name} est ${alertCondition == "greater" ? ">" : "<"} $val FCFA/kg'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Activer l\'alerte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showHarvestDialog(BuildContext context) {
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
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Récolter : ${widget.crop.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Cette récolte basculera le statut de la culture à "Récolté" et incrémentera automatiquement votre inventaire de stock.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quantité récoltée',
                          prefixIcon: const Icon(Icons.scale_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: unit,
                        decoration: InputDecoration(
                          labelText: 'Unité',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'kg', child: Text('kg')),
                          DropdownMenuItem(value: 'tonnes', child: Text('tonnes')),
                          DropdownMenuItem(value: 'sacs', child: Text('sacs')),
                        ],
                        onChanged: (val) {
                          if (val != null) setSheetState(() => unit = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes ou observations (optionnel)',
                    prefixIcon: const Icon(Icons.notes_rounded),
                    hintText: 'Ex: Qualité exceptionnelle, parcelle Est...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
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
                        setState(() {
                          _currentStatus = 'harvested';
                        });
                        refreshAfterDataChange(ref);
                        nav.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Récolte de $qty $unit enregistrée ! Le stock et les alertes sont à jour.'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Erreur: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Confirmer la Récolte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
