import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/offline_cache_banner.dart';
import '../../data/guides_provider.dart';
import '../../data/models/agronomic_guide.dart';

class GuidesListScreen extends ConsumerStatefulWidget {
  const GuidesListScreen({super.key});

  @override
  ConsumerState<GuidesListScreen> createState() => _GuidesListScreenState();
}

class _GuidesListScreenState extends ConsumerState<GuidesListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'all';

  final List<Map<String, String>> _categories = const [
    {'id': 'all', 'label': 'Toutes'},
    {'id': 'legume', 'label': 'Légumes'},
    {'id': 'cereale', 'label': 'Céréales'},
    {'id': 'legumineuse', 'label': 'Légumineuses'},
    {'id': 'fruit', 'label': 'Fruits'},
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    ref.read(guidesNotifierProvider.notifier).loadGuides(
          category: _selectedCategory,
          search: val,
        );
  }

  void _onCategorySelected(String catId) {
    setState(() => _selectedCategory = catId);
    ref.read(guidesNotifierProvider.notifier).loadGuides(
          category: catId,
          search: _searchCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(guidesNotifierProvider);

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
        title: const Text(
          'Fiches Agronomiques',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 19),
        ),
      ),
      body: Column(
        children: [
          if (state.isFromCache && state.cachedAt != null)
            OfflineCacheBanner(cachedAt: state.cachedAt!),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une culture (ex. Niébé, Mil, Oignon)...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat['id'];
                      return ChoiceChip(
                        label: Text(cat['label']!),
                        selected: isSelected,
                        onSelected: (_) => _onCategorySelected(cat['id']!),
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref.read(guidesNotifierProvider.notifier).loadGuides(
                      category: _selectedCategory,
                      search: _searchCtrl.text,
                    );
              },
              color: AppColors.primary,
              child: _buildBody(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(GuidesListState state) {
    if (state.isLoading && state.guides.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (state.error != null && state.guides.isEmpty) {
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
                onPressed: () => ref.read(guidesNotifierProvider.notifier).loadGuides(
                      category: _selectedCategory,
                      search: _searchCtrl.text,
                    ),
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

    if (state.guides.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                'Aucune fiche agronomique trouvée',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Essayez d\'ajuster vos filtres de recherche ou de catégorie.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.guides.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final guide = state.guides[index];
        return _buildGuideCard(context, guide);
      },
    );
  }

  Widget _buildGuideCard(BuildContext context, AgronomicGuide guide) {
    IconData iconData = Icons.eco;
    Color iconColor = AppColors.primary;
    if (guide.category == 'cereale') {
      iconData = Icons.grass;
      iconColor = Colors.amber.shade800;
    } else if (guide.category == 'fruit') {
      iconData = Icons.agriculture;
      iconColor = Colors.orange;
    } else if (guide.category == 'legumineuse') {
      iconData = Icons.grain;
      iconColor = Colors.brown;
    }

    return GestureDetector(
      onTap: () => context.push('/agriculture/guides/${guide.slug}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(iconData, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          guide.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          guide.categoryLabel,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (guide.scientificName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      guide.scientificName,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    guide.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (guide.cycleDisplay != null)
                        _buildInfoBadge(Icons.schedule, guide.cycleDisplay!),
                      _buildInfoBadge(
                        Icons.menu_book,
                        '${guide.sources.length} réf. sourcée(s)',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
