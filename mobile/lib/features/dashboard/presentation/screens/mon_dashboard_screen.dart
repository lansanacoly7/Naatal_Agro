import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class MonDashboardScreen extends ConsumerStatefulWidget {
  const MonDashboardScreen({super.key});

  @override
  ConsumerState<MonDashboardScreen> createState() => _MonDashboardScreenState();
}

class _MonDashboardScreenState extends ConsumerState<MonDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Mon Dashboard',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) setState(() {});
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Performances Financières'),
              const SizedBox(height: 16),
              _buildFinancialStats(),
              
              const SizedBox(height: 32),
              _buildSectionTitle('État de mon Stock'),
              const SizedBox(height: 16),
              _buildStockInfo(),
              
              const SizedBox(height: 32),
              _buildSectionTitle('Naatal IA - Stock & Récoltes'),
              const SizedBox(height: 16),
              _buildAiRecommendations(),
              
              const SizedBox(height: 32),
              _buildSectionTitle('Tendances & Investissements'),
              const SizedBox(height: 16),
              _buildInvestmentAdvice(),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
      ),
    );
  }

  // 1. Finances : Chiffre d'affaires, Revenus, Pertes
  Widget _buildFinancialStats() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chiffre d\'Affaires Global',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '2 450 000 FCFA',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '+12% par rapport au mois dernier',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.green),
                    SizedBox(height: 12),
                    Text('Revenus Nets', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    SizedBox(height: 4),
                    Text('1 800 000 F', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.trending_down, color: Colors.red),
                    SizedBox(height: 12),
                    Text('Pertes Estimées', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    SizedBox(height: 4),
                    Text('150 000 F', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 2. Stock : Quantité de stock
  Widget _buildStockInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildStockItem('Oignon Local', '2.5 Tonnes', 'Bon état', Icons.eco),
          const Divider(height: 1),
          _buildStockItem('Riz de la vallée', '800 Kg', 'Risque d\'humidité', Icons.water_drop, warning: true),
          const Divider(height: 1),
          _buildStockItem('Arachide', '1.2 Tonnes', 'Prêt à la vente', Icons.sell),
        ],
      ),
    );
  }

  Widget _buildStockItem(String name, String qty, String status, IconData icon, {bool warning = false}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: warning ? Colors.orange.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: warning ? Colors.orange : AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(status, style: TextStyle(color: warning ? Colors.orange : AppColors.textSecondary, fontSize: 12, fontWeight: warning ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          ),
          Text(qty, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  // 3. IA : Recommandations pour le stock
  Widget _buildAiRecommendations() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conseil de Stockage',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vos 800 kg de riz risquent de s\'abîmer avec les pluies prévues. Assurez-vous que l\'entrepôt est bien ventilé et surélevé.',
                  style: TextStyle(color: AppColors.textPrimary, height: 1.4, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.push('/ai'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    minimumSize: const Size(120, 36),
                  ),
                  child: const Text('Parler à Naatal IA', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Investissements : Gestion du revenu & Tendances
  Widget _buildInvestmentAdvice() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
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
              Icon(Icons.lightbulb_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('Où réinvestir vos gains ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'D\'après les tendances actuelles des marchés de Dakar et Thiès, voici les recommandations pour vos prochains investissements :',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          _buildTrendItem('Tomate Cerise', 'Forte demande prévue pour les fêtes. Marge estimée : +40%', Colors.green),
          const SizedBox(height: 12),
          _buildTrendItem('Oignon Local', 'Marché bientôt saturé. Réduisez la production de 20% au prochain cycle.', Colors.red),
        ],
      ),
    );
  }

  Widget _buildTrendItem(String crop, String detail, Color trendColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(trendColor == Colors.green ? Icons.trending_up : Icons.trending_down, color: trendColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(crop, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(detail, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
