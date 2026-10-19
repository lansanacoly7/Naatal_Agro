import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/data_refresh.dart';
import '../../../../ui/ui.dart';
import '../../../markets/data/markets_provider.dart';
import '../../../markets/data/models/product.dart';
import '../../../profile/data/profile_provider.dart';
import '../../data/agriculture_provider.dart';
import '../../data/guides_provider.dart';
import '../../data/models/agronomic_guide.dart';
import 'cultures_screen.dart' show guideForProduct, productImagePath;

String _plain(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');

/// Une culture que l'on peut choisir : avec fiche officielle (cycle connu) ou simple produit du catalogue.
class _Choice {
  const _Choice({required this.name, required this.category, this.guide, this.image = ''});

  final String name;
  final String category;
  final AgronomicGuide? guide;
  final String image;
}

String _capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

String _two(int n) => n.toString().padLeft(2, '0');
String _fmt(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
String _iso(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

class AddCropScreen extends ConsumerStatefulWidget {
  const AddCropScreen({super.key, this.initialGuideSlug});

  /// Fiche à présélectionner (quand on arrive depuis « Cultiver ceci »).
  final String? initialGuideSlug;

  @override
  ConsumerState<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends ConsumerState<AddCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController(text: '1.0');
  final _locationController = TextEditingController();

  _Choice? _choice;
  DateTime _planting = DateTime.now();
  DateTime? _harvest;
  bool _harvestEdited = false;
  bool _saving = false;
  String _searchQuery = '';

  AgronomicGuide? get _guide => _choice?.guide;
  int? get _minDays => _guide?.cycleDaysMin ?? _guide?.cycleDaysMax;
  int? get _maxDays => _guide?.cycleDaysMax ?? _guide?.cycleDaysMin;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileNotifierProvider).valueOrNull;
    if (profile != null && profile.location.trim().isNotEmpty) {
      _locationController.text = profile.location.trim();
    }
    final slug = widget.initialGuideSlug;
    if (slug != null) {
      ref.listenManual(guidesNotifierProvider, (_, next) {
        if (_choice != null) return;
        for (final g in next.guides) {
          if (g.slug == slug) {
            _select(_Choice(name: g.name, category: g.categoryLabel, guide: g, image: _imageFor(g.name)));
            break;
          }
        }
      }, fireImmediately: true);
    }
  }

  void _adjustArea(double delta) {
    final current = double.tryParse(_areaController.text.trim().replaceAll(',', '.')) ?? 1.0;
    final next = (current + delta).clamp(0.25, 1000.0);
    final rounded = (next * 100).round() / 100.0;
    setState(() {
      _areaController.text = rounded.toStringAsFixed(rounded.truncateToDouble() == rounded ? 1 : 2);
    });
  }

  List<_Choice> _buildChoicesList(List<AgronomicGuide> guides, List<Product> products) {
    String imageFor(AgronomicGuide g) {
      for (final p in products) {
        if (guideForProduct(p.name, [g]) != null) return productImagePath(p);
      }
      return '';
    }

    return [
      for (final g in guides) _Choice(name: g.name, category: g.categoryLabel, guide: g, image: imageFor(g)),
      for (final p in products)
        if (guideForProduct(p.name, guides) == null) _Choice(name: p.name, category: p.category.isEmpty ? '' : _capital(p.category), image: productImagePath(p)),
    ]..sort((a, b) {
        final byGuide = (b.guide != null ? 1 : 0).compareTo(a.guide != null ? 1 : 0);
        return byGuide != 0 ? byGuide : _plain(a.name).compareTo(_plain(b.name));
      });
  }

  String _imageFor(String name) {
    final products = ref.read(allProductsProvider).valueOrNull ?? const <Product>[];
    for (final p in products) {
      if (guideForProduct(p.name, [AgronomicGuide(id: '', slug: '', name: name, category: '', summary: '')]) != null) {
        return productImagePath(p);
      }
    }
    return '';
  }

  /// Choisit une culture : les dates se remplissent toutes seules à partir du cycle officiel.
  void _select(_Choice choice) {
    setState(() {
      _choice = choice;
      _nameController.text = 'Parcelle ${choice.name}';
      if (_areaController.text.trim().isEmpty) {
        _areaController.text = '1.0';
      }
      _harvestEdited = false;
      _recomputeHarvest();
    });
  }

  void _recomputeHarvest() {
    final min = _minDays;
    final max = _maxDays;
    if (min == null || max == null) {
      _harvest = null;
      return;
    }
    _harvest = _planting.add(Duration(days: ((min + max) / 2).round()));
  }

  Future<void> _pickDate(bool planting) async {
    final initial = planting ? _planting : (_harvest ?? _planting);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (planting) {
        _planting = picked;
        if (!_harvestEdited) _recomputeHarvest();
      } else {
        _harvest = picked;
        _harvestEdited = true;
      }
    });
  }

  Future<void> _openPicker() async {
    final picked = await showModalBottomSheet<_Choice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _CropPicker(),
    );
    if (picked != null) _select(picked);
  }

  Future<void> _submit() async {
    if (_choice == null) {
      _toast('Choisissez d\'abord une culture.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_harvest == null) {
      _toast('Indiquez la date de récolte prévue (cycle non documenté pour cette culture).');
      return;
    }
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'crop_type': _choice!.name,
        'area_size': double.parse(_areaController.text.trim().replaceAll(',', '.')),
        'location': _locationController.text.trim(),
        'planting_date': _iso(_planting),
        'expected_harvest_date': _iso(_harvest!),
        'status': 'active',
        if (_guide != null && _guide!.id.isNotEmpty) 'guide': _guide!.id,
      };
      await ref.read(agricultureRepositoryProvider).addCrop(data);
      refreshAfterDataChange(ref);
      if (mounted) {
        final size = MediaQuery.of(context).size;
        await showSuccessReveal(
          context,
          origin: Offset(size.width / 2, size.height * 0.8),
          headline: 'CULTURE ENREGISTRÉE',
          title: _nameController.text.trim(),
          details: [
            '${_areaController.text.trim()} ha · ${_locationController.text.trim()}',
            if (_guide?.cycleDisplay != null) 'Cycle ${_guide!.cycleDisplay!}',
            'Récolte prévue : ${_fmt(_harvest!)}',
          ],
          doneLabel: 'Voir mes cultures',
        );
        if (mounted) {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) _toast('Enregistrement impossible : ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guidesState = ref.watch(guidesNotifierProvider);
    final productsAsync = ref.watch(allProductsProvider);
    final products = productsAsync.valueOrNull ?? const <Product>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_choice == null ? 'Choisir une culture' : 'Nouvelle culture', style: const TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        actions: [
          if (_choice != null)
            TextButton(
              onPressed: () => setState(() => _choice = null),
              child: const Text('Changer', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_choice == null)
              _buildDirectPicker(guidesState.guides, products)
            else ...[
              _chosenHero(),
              const SizedBox(height: 14),
              _cycleCard(),
              const SizedBox(height: 14),
              _calendarCard(),
              const SizedBox(height: 14),
              _detailsCard(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _choice == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    child: _saving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('Enregistrer la culture'),
                  ),
                ),
              ),
            ),
    );
  }

  // Grille directe de choix des cultures « images d'abord » avec recherche
  Widget _buildDirectPicker(List<AgronomicGuide> guides, List<Product> products) {
    final all = _buildChoicesList(guides, products);
    final q = _plain(_searchQuery.trim());
    final filtered = all.where((c) => q.isEmpty || _plain(c.name).contains(q) || _plain(c.category).contains(q)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recherche rapide directe
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Rechercher : arachide, oignon, maïs, tomate...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Touchez votre culture',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Le cycle ISRA et les dates recommandées seront préremplis automatiquement.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Aucune culture trouvée avec ce nom.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, i) {
              final item = filtered[i];
              final hasGuide = item.guide != null;
              final cycle = item.guide?.cycleDisplay;

              return InkWell(
                onTap: () => _select(item),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: hasGuide ? AppColors.primary.withValues(alpha: 0.35) : Colors.grey.withValues(alpha: 0.15),
                      width: hasGuide ? 1.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item.image.isNotEmpty)
                        Image.asset(
                          item.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            child: const Icon(Icons.eco_rounded, color: AppColors.primary, size: 36),
                          ),
                        )
                      else
                        Container(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          child: const Icon(Icons.eco_rounded, color: AppColors.primary, size: 36),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.25),
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.35, 0.65, 1.0],
                          ),
                        ),
                      ),
                      if (hasGuide)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, color: Colors.white, size: 10),
                                SizedBox(width: 3),
                                Text(
                                  'ISRA',
                                  style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        right: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (cycle != null)
                              Text(
                                cycle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF6FD3A0),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // Carte de la culture choisie : photo, nom, catégorie, bouton « Changer ».
  Widget _chosenHero() {
    final c = _choice!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 130,
        child: Stack(
          fit: StackFit.expand,
          children: [
            c.image.isEmpty
                ? Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient))
                : Image.asset(c.image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient))),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.75)]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (c.category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                            child: Text(c.category.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                          ),
                        const SizedBox(height: 6),
                        Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _openPicker,
                    style: TextButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2), foregroundColor: Colors.white),
                    child: const Text('Changer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cycle officiel mis en valeur.
  Widget _cycleCard() {
    final g = _guide;
    final display = g?.cycleDisplay;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
            child: Icon(g != null ? Icons.verified_rounded : Icons.info_outline_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(display != null ? 'Cycle officiel ISRA' : 'Cycle non documenté', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(display ?? 'À renseigner par vous', style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800)),
                if (g != null) Text('${g.categoryLabel} · du semis à la récolte', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Calendrier cultural rempli automatiquement, modifiable.
  Widget _calendarCard() {
    final min = _minDays;
    final max = _maxDays;
    return _card(
      title: 'Calendrier cultural',
      icon: Icons.event_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _dateTile('Semis', _planting, () => _pickDate(true))),
              const SizedBox(width: 12),
              Expanded(child: _dateTile('Récolte prévue', _harvest, () => _pickDate(false))),
            ],
          ),
          const SizedBox(height: 10),
          if (min != null && max != null && min != max)
            Text(
              'Remplie automatiquement d\'après le cycle officiel : récolte entre le ${_fmt(_planting.add(Duration(days: min)))} et le ${_fmt(_planting.add(Duration(days: max)))}. Touchez une date pour la modifier.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.35),
            )
          else if (min != null)
            Text('Remplie automatiquement d\'après le cycle officiel. Touchez une date pour la modifier.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
          else
            Text('Pas de cycle documenté pour cette culture : choisissez vous-même la date de récolte.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(date == null ? 'À choisir' : _fmt(date), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: date == null ? AppColors.textSecondary : AppColors.textPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard() {
    return _card(
      title: 'Votre parcelle',
      icon: Icons.landscape_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nom de la parcelle'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Donnez un nom à la parcelle' : null,
          ),
          const SizedBox(height: 14),
          const Text(
            'Surface de la parcelle',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                onTap: () => _adjustArea(-0.25),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.remove_rounded, color: AppColors.primary, size: 28),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: TextFormField(
                    controller: _areaController,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      suffixText: 'ha',
                      suffixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                      return (n == null || n <= 0) ? 'Surface requise' : null;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _adjustArea(0.25),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(labelText: 'Lieu / Commune'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez le lieu' : null,
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withValues(alpha: 0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Liste déroulante avec recherche : on tape, les suggestions se filtrent.
class _CropPicker extends ConsumerStatefulWidget {
  const _CropPicker();

  @override
  ConsumerState<_CropPicker> createState() => _CropPickerState();
}

class _CropPickerState extends ConsumerState<_CropPicker> {
  String _query = '';

  List<_Choice> _choices(List<AgronomicGuide> guides, List<Product> products) {
    String imageFor(AgronomicGuide g) {
      for (final p in products) {
        if (guideForProduct(p.name, [g]) != null) return productImagePath(p);
      }
      return '';
    }

    return [
      for (final g in guides) _Choice(name: g.name, category: g.categoryLabel, guide: g, image: imageFor(g)),
      for (final p in products)
        if (guideForProduct(p.name, guides) == null) _Choice(name: p.name, category: p.category.isEmpty ? '' : _capital(p.category), image: productImagePath(p)),
    ]..sort((a, b) {
        // Les cultures au cycle officiel connu d'abord, puis l'ordre alphabétique.
        final byGuide = (b.guide != null ? 1 : 0).compareTo(a.guide != null ? 1 : 0);
        return byGuide != 0 ? byGuide : _plain(a.name).compareTo(_plain(b.name));
      });
  }

  @override
  Widget build(BuildContext context) {
    final guidesState = ref.watch(guidesNotifierProvider);
    final productsAsync = ref.watch(allProductsProvider);
    final products = productsAsync.valueOrNull ?? const <Product>[];
    final loading = (guidesState.isLoading && guidesState.guides.isEmpty) || (productsAsync.isLoading && guidesState.guides.isEmpty);
    final choices = _choices(guidesState.guides, products);
    final q = _plain(_query.trim());
    final shown = choices.where((c) => q.isEmpty || _plain(c.name).contains(q) || _plain(c.category).contains(q)).toList();
    final height = MediaQuery.sizeOf(context).height * 0.8;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(hintText: 'Rechercher : arachide, tomate, mil…', prefixIcon: Icon(Icons.search_rounded)),
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : shown.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(choices.isEmpty ? 'La liste des cultures n\'a pas pu être chargée.' : 'Aucune culture ne correspond.', style: const TextStyle(color: AppColors.textSecondary)),
                              if (choices.isEmpty)
                                TextButton(
                                  onPressed: () {
                                    ref.read(guidesNotifierProvider.notifier).loadGuides();
                                    ref.invalidate(allProductsProvider);
                                  },
                                  child: const Text('Réessayer'),
                                ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          itemCount: shown.length,
                          separatorBuilder: (_, __) => Divider(height: 1, indent: 76, color: Colors.grey.withValues(alpha: 0.12)),
                          itemBuilder: (context, i) {
                            final c = shown[i];
                            final cycle = c.guide?.cycleDisplay;
                            return ListTile(
                              onTap: () => Navigator.of(context).pop(c),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: c.image.isEmpty
                                      ? Container(color: AppColors.primary.withValues(alpha: 0.08), child: const Icon(Icons.eco_rounded, color: AppColors.primary))
                                      : Image.asset(c.image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.primary.withValues(alpha: 0.08), child: const Icon(Icons.eco_rounded, color: AppColors.primary))),
                                ),
                              ),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
                              subtitle: Text(
                                [if (c.category.isNotEmpty) c.category, cycle ?? 'cycle non documenté'].join(' · '),
                                style: TextStyle(color: cycle != null ? AppColors.primary : AppColors.textSecondary, fontSize: 12.5, fontWeight: cycle != null ? FontWeight.w700 : FontWeight.w500),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
