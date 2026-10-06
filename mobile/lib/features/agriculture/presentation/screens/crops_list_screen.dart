import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/notifications_sheet.dart';
import '../../../../core/network/paginated_response.dart';
import '../../../../core/widgets/offline_cache_banner.dart';

// Imports pour Mes Cultures
import '../../data/agriculture_provider.dart';
import '../../data/models/crop.dart';

// Imports pour Catalogue
import '../../../markets/data/markets_provider.dart';
import '../../../markets/data/models/product.dart';

class CropsListScreen extends ConsumerStatefulWidget {
  const CropsListScreen({super.key});

  @override
  ConsumerState<CropsListScreen> createState() => _CropsListScreenState();
}

class _CropsListScreenState extends ConsumerState<CropsListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = ['Tout', 'Céréales', 'Fruits', 'Légumes'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              backgroundImage: const AssetImage('assets/images/naatal_agro_logo-removebg-preview.png'),
              radius: 18,
            ),
            const SizedBox(width: 12),
            const Text('Naatal Agro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
            onPressed: () => showNotificationsSheet(context, ref),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Mes Cultures'),
            Tab(text: 'Catalogue'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMesCulturesTab(),
          _buildCatalogueTab(),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton(
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            context.push('/agriculture/add');
          },
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: MES CULTURES
  // ==========================================

  Widget _buildMesCulturesTab() {
    final paginatedState = ref.watch(cropsPaginationNotifierProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(cropsPaginationNotifierProvider.notifier).refresh();
      },
      color: AppColors.primary,
      child: paginatedState.isLoading && paginatedState.items.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : paginatedState.error != null && paginatedState.items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Erreur de chargement', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(paginatedState.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.read(cropsPaginationNotifierProvider.notifier).refresh(),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (paginatedState.isFromCache && paginatedState.cachedAt != null)
                      OfflineCacheBanner(cachedAt: paginatedState.cachedAt!),
                    Expanded(child: _buildCropsList(context, paginatedState)),
                  ],
                ),
    );
  }

  Widget _buildCropsList(BuildContext context, PaginatedState<Crop> state) {
    if (state.items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco_rounded, size: 64, color: Colors.green),
              ),
              const SizedBox(height: 24),
              Text(
                'Aucune culture enregistrée',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Commencez par ajouter votre première parcelle.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final hasFooter = state.hasMore || state.isLoadingMore;
    final totalCount = state.items.length + (hasFooter ? 1 : 0);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          if (state.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.arrow_downward, color: AppColors.primary),
                label: const Text(
                  'Charger plus de cultures',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => ref.read(cropsPaginationNotifierProvider.notifier).loadMore(),
              ),
            ),
          );
        }
        final crop = state.items[index];
        return _buildCropCard(context, crop);
      },
    );
  }

  Widget _buildCropCard(BuildContext context, Crop crop) {
    Color statusColor = crop.status == 'active' ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image de fond avec fallback
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              crop.imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
              ),
            ),
          ),
          // Dégradé sombre
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.push(
              '/crop_detail',
              extra: crop,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: statusColor, blurRadius: 4)],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              crop.status.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
                        ),
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (value) async {
                          if (value == 'delete') {
                            // Show confirmation dialog
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Supprimer la culture'),
                                content: Text('Voulez-vous vraiment supprimer "${crop.name}" de votre exploitation ? Cette action est irréversible.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Annuler'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              try {
                                await ref.read(agricultureRepositoryProvider).deleteCrop(crop.id);
                                ref.read(cropsPaginationNotifierProvider.notifier).refresh();
                                ref.invalidate(cropsProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Culture supprimée avec succès')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erreur: ${e.toString()}')),
                                  );
                                }
                              }
                            }
                          } else if (value == 'edit') {
                            _showEditCropDialog(context, ref, crop);
                          } else if (value == 'harvest') {
                            try {
                              await ref.read(agricultureRepositoryProvider).updateCrop(crop.id, {'status': 'harvested'});
                              ref.read(cropsPaginationNotifierProvider.notifier).refresh();
                              ref.invalidate(cropsProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Culture "${crop.name}" marquée comme récoltée avec succès'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          } else if (value == 'details') {
                            context.push('/crop_detail', extra: crop);
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'details',
                            child: ListTile(
                              leading: Icon(Icons.info_outline, color: AppColors.primary),
                              title: Text('Détails'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined, color: Colors.blue),
                              title: Text('Modifier'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'harvest',
                            child: ListTile(
                              leading: Icon(Icons.check_circle_outline, color: Colors.green),
                              title: Text('Marquer comme récolté'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline, color: Colors.red),
                              title: Text('Supprimer', style: TextStyle(color: Colors.red)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crop.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.landscape_rounded, color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${crop.areaSize} ha',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              crop.location,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildCropProgressBar(crop),
                    ],
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

  Widget _buildCropProgressBar(Crop crop) {
    double progress = 0.0;
    try {
      final start = DateTime.parse(crop.plantingDate);
      final end = DateTime.parse(crop.expectedHarvestDate);
      final now = DateTime.now();
      if (now.isAfter(end)) {
        progress = 1.0;
      } else if (now.isAfter(start)) {
        final totalDays = end.difference(start).inDays;
        if (totalDays > 0) {
          progress = now.difference(start).inDays / totalDays;
        }
      }
    } catch (e) {
      progress = 0.5;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Semis', style: TextStyle(color: Colors.white70, fontSize: 10)),
            Text('Croissance', style: TextStyle(color: Colors.white70, fontSize: 10)),
            Text('Récolte', style: TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: CATALOGUE
  // ==========================================

  Widget _buildCatalogueTab() {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(trendingProductsProvider);
        ref.invalidate(filteredProductsProvider);
      },
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildCategoryTabs()),
          SliverToBoxAdapter(child: _buildTrendingSection()),
          _buildAllProductsHeader(),
          _buildAllProductsGrid(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        ref.read(productFilterProvider.notifier).state = ProductFilter(
                          category: ref.read(productFilterProvider).category,
                          search: value,
                        );
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Rechercher un produit...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tune, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final filter = ref.watch(productFilterProvider);

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = filter.category == category;
          // Gestion des pluriels pour matcher l'API (CÉRÉALE, FRUIT, LÉGUME)
          String apiCategory = category;
          if (category == 'Céréales') apiCategory = 'CÉRÉALE';
          if (category == 'Fruits') apiCategory = 'FRUIT';
          if (category == 'Légumes') apiCategory = 'LÉGUME';

          return GestureDetector(
            onTap: () {
              ref.read(productFilterProvider.notifier).state = ProductFilter(
                category: apiCategory == 'Tout' ? 'Tout' : apiCategory,
                search: filter.search,
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade200,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendingSection() {
    final filter = ref.watch(productFilterProvider);
    // Masquer la section tendance si on recherche ou on filtre
    if (filter.category != 'Tout' || filter.search.isNotEmpty) {
      return const SizedBox.shrink();
    }

    final trendingAsyncValue = ref.watch(trendingProductsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'Tendances du jour',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: trendingAsyncValue.when(
            data: (products) {
              if (products.isEmpty) {
                return const Center(child: Text('Aucune tendance pour le moment.'));
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return _buildTrendingCard(products[index]);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, stack) => Center(child: Text('Erreur: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingCard(Product product) {
    final isPositive = product.trendPercentage >= 0;
    
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                image: DecorationImage(
                  image: AssetImage(product.imageAsset),
                  fit: BoxFit.cover,
                ),
              ),
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: isPositive ? Colors.green : Colors.red,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${product.trendPercentage}%',
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${product.currentPrice.toInt()} FCFA / kg',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
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

  Widget _buildAllProductsHeader() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tous les produits',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllProductsGrid() {
    final filteredAsyncValue = ref.watch(filteredProductsProvider);

    return filteredAsyncValue.when(
      data: (products) {
        if (products.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text('Aucun produit trouvé.'),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 100.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _buildProductGridCard(products[index]);
              },
              childCount: products.length,
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ),
      error: (err, stack) => SliverToBoxAdapter(
        child: Center(child: Text('Erreur: $err')),
      ),
    );
  }

  Widget _buildProductGridCard(Product product) {
    Color getCategoryColor(String cat) {
      if (cat == 'LÉGUME') return Colors.green.shade600;
      if (cat == 'FRUIT') return Colors.orange.shade600;
      if (cat == 'CÉRÉALE') return Colors.amber.shade700;
      return AppColors.primary;
    }

    return GestureDetector(
      onTap: () => context.push(
        '/product_detail',
        extra: {
          'productName': product.name,
          'imageAsset': product.imageAsset,
          'price': '${product.currentPrice.toInt()} FCFA/kg',
        },
      ),
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    image: DecorationImage(
                      image: AssetImage(product.imageAsset),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: getCategoryColor(product.category),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${product.currentPrice.toInt()} F',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                product.trendPercentage >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                color: product.trendPercentage >= 0 ? Colors.green : Colors.red,
                                size: 10,
                              ),
                              Text(
                                '${product.trendPercentage}%',
                                style: TextStyle(
                                  color: product.trendPercentage >= 0 ? Colors.green : Colors.red,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          context.push('/agriculture/add');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  void _showEditCropDialog(BuildContext context, WidgetRef ref, Crop crop) {
    final nameController = TextEditingController(text: crop.name);
    final areaController = TextEditingController(text: crop.areaSize.toString());
    final locationController = TextEditingController(text: crop.location);
    String currentStatus = crop.status;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                    Text('Modifier : ${crop.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nom de la culture',
                    prefixIcon: const Icon(Icons.grass_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: areaController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Superficie (ha)',
                    prefixIcon: const Icon(Icons.square_foot_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: 'Localisation',
                    prefixIcon: const Icon(Icons.location_on_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: currentStatus,
                  decoration: InputDecoration(
                    labelText: 'Statut',
                    prefixIcon: const Icon(Icons.info_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('En croissance (Active)')),
                    DropdownMenuItem(value: 'harvested', child: Text('Récoltée')),
                    DropdownMenuItem(value: 'paused', child: Text('En pause')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => currentStatus = val);
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final updatedData = {
                          'name': nameController.text.trim(),
                          'area_size': double.tryParse(areaController.text.trim()) ?? crop.areaSize,
                          'location': locationController.text.trim(),
                          'status': currentStatus,
                        };
                        await ref.read(agricultureRepositoryProvider).updateCrop(crop.id, updatedData);
                        ref.read(cropsPaginationNotifierProvider.notifier).refresh();
                        ref.invalidate(cropsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Culture mise à jour avec succès'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
