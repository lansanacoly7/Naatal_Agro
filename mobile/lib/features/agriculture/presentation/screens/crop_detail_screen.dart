import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/crop.dart';

class CropDetailScreen extends ConsumerStatefulWidget {
  final Crop crop;

  const CropDetailScreen({super.key, required this.crop});

  @override
  ConsumerState<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends ConsumerState<CropDetailScreen> {
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
                        widget.crop.status == 'active' ? 'EN CROISSANCE' : 'RÉCOLTÉ',
                        Icons.eco,
                        widget.crop.status == 'active' ? Colors.greenAccent : Colors.orangeAccent,
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
        _buildTaskTile('Irrigation approfondie', 'Aujourd\'hui', true),
        _buildTaskTile('Apport d\'engrais NPK', 'Demain', false),
        _buildTaskTile('Sarclage', 'Dans 3 jours', false),
      ],
    );
  }

  Widget _buildTaskTile(String title, String time, bool isDone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(
          isDone ? Icons.check_circle : Icons.circle_outlined,
          color: isDone ? Colors.green : Colors.grey.shade400,
        ),
        title: Text(title, style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        subtitle: Text(time, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Gestion du Stock & Vente", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            OutlinedButton.icon(
              onPressed: () {
                // Logic to create an alert for price
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Formulaire de création d\'alerte de prix ouvert')));
              },
              icon: const Icon(Icons.notifications_active, size: 16, color: AppColors.primary),
              label: const Text('Créer une alerte', style: TextStyle(color: AppColors.primary, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2, color: AppColors.primaryDark),
                  SizedBox(width: 8),
                  Text('Préparation à la vente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Anticipez votre récolte. Surveillez les tendances des marchés locaux pour décider si vous devez stocker votre production ou vendre immédiatement après la récolte.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to market comparison using the crop's raw type
                    context.push('/market_comparison', extra: {
                      'productName': widget.crop.cropType,
                      'imageAsset': widget.crop.imageAsset,
                      'price': '', // Dynamic fetch based on cropType
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Analyser les prix du marché', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
