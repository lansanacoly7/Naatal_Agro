import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/region_locator.dart';
import '../../core/location/senegal_regions.dart';
import '../../core/router/app_router.dart';
import '../../features/agriculture/data/guides_provider.dart';
import '../../features/agriculture/data/models/agronomic_guide.dart';
import '../../features/profile/data/profile_provider.dart';
import '../../ui/ui.dart';

/// Première chose montrée après l'inscription : les cultures à suggérer, avec la région trouvée toute seule.
///
/// Une culture est mise en avant « pour votre région » seulement si sa fiche technique (sourcée) cite la zone de
/// l'agriculteur ; sinon elle reste dans « Autres cultures ». Rien n'est deviné ni inventé.
class CropSetupScreen extends ConsumerStatefulWidget {
  const CropSetupScreen({super.key});

  @override
  ConsumerState<CropSetupScreen> createState() => _CropSetupScreenState();
}

enum _Locating { searching, found, failed }

class _CropSetupScreenState extends ConsumerState<CropSetupScreen> {
  _Locating _locating = _Locating.searching;
  SenegalRegion? _region;
  final _selected = <String>{};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  Future<void> _locate() async {
    setState(() => _locating = _Locating.searching);
    // Délai maximal : si l'autorisation reste sans réponse, on propose de choisir la région plutôt que d'attendre sans fin
    final region = await ref.read(regionDetectorProvider)().timeout(const Duration(seconds: 25), onTimeout: () => null);
    if (!mounted) return;
    setState(() {
      _region = region;
      _locating = region == null ? _Locating.failed : _Locating.found;
    });
  }

  void _pickRegion() {
    showNaatalSheet<void>(
      context,
      builder: (ctx) => _RegionSheet(
        current: _region,
        onPick: (region) {
          Navigator.pop(ctx);
          setState(() {
            _region = region;
            _locating = _Locating.found;
          });
        },
      ),
    );
  }

  Future<void> _finish({required bool withCrops}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final region = _region;
      if (withCrops || region != null) {
        await ref.read(profileRepositoryProvider).updateProfile(
              location: region?.name,
              mainCrops: withCrops ? _selected.toList() : null,
            );
        ref.invalidate(profileNotifierProvider);
      }
      HapticFeedback.mediumImpact();
      await setCropSetupPending(ref, false); // le routeur envoie alors vers l'accueil
    } catch (e) {
      debugPrint('[Première culture] Enregistrement impossible : $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Enregistrement impossible. Vérifiez votre réseau, puis réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final guidesState = ref.watch(guidesNotifierProvider);
    final region = _region;

    final forRegion = <AgronomicGuide>[];
    final others = <AgronomicGuide>[];
    for (final guide in guidesState.guides) {
      if (region != null && SenegalRegions.zonesMention(region, guide.zones)) {
        forRegion.add(guide);
      } else {
        others.add(guide);
      }
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, 0),
                  child: Row(
                    children: [
                      const BrandLogo(height: 130),
                      const Spacer(),
                      ReadAloudButton(
                        text: 'Bienvenue sur Naatal Agro. Touchez les images des cultures que vous faites, puis touchez le gros bouton vert.',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.m),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Que cultivez-vous ?', style: T.largeTitle(color: c.ink)),
                              const SizedBox(height: Space.xs),
                              Text('Touchez les images', style: T.body(color: c.ink2).copyWith(fontSize: 17)),
                              const SizedBox(height: Space.l),
                              _LocationChip(state: _locating, region: region, onRetry: _locate, onPick: _pickRegion),
                            ],
                          ),
                        ),
                      ),
                      if (guidesState.isLoading && guidesState.guides.isEmpty)
                        const SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: Space.gutter),
                          sliver: SliverToBoxAdapter(child: Skeleton(height: 320, radius: 20)),
                        )
                      else if (guidesState.guides.isEmpty)
                        SliverToBoxAdapter(
                          child: ErrorState(
                            message: 'La liste des cultures n\'a pas pu être chargée.',
                            onRetry: () => ref.read(guidesNotifierProvider.notifier).loadGuides(),
                          ),
                        )
                      else ...[
                        if (forRegion.isNotEmpty) ..._section('Pour ${region!.name}', forRegion, highlight: true),
                        ..._section(forRegion.isEmpty ? 'Cultures' : 'Autres cultures', others),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, Space.l),
                  decoration: BoxDecoration(
                    color: c.bg,
                    border: Border(top: BorderSide(color: c.line.withValues(alpha: 0.6))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.s),
                          child: Text(_error!, textAlign: TextAlign.center, style: T.body(color: c.clay, weight: 700)),
                        ),
                      PillButton(
                        label: _selected.isEmpty ? 'Choisissez une culture' : 'Continuer  ·  ${_selected.length}',
                        icon: Icons.arrow_forward_rounded,
                        expand: true,
                        loading: _saving,
                        onPressed: _selected.isEmpty || _saving ? null : () => _finish(withCrops: true),
                      ),
                      PressScale(
                        onTap: _saving ? null : () => _finish(withCrops: false),
                        child: SizedBox(
                          height: Hit.primary,
                          child: Center(child: Text('Plus tard', style: T.body(color: c.ink2, weight: 700))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _section(String title, List<AgronomicGuide> guides, {bool highlight = false}) {
    if (guides.isEmpty) return const [];
    final c = context.c;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, Space.m),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              if (highlight) ...[Icon(Icons.star_rounded, color: c.gold, size: 26), const SizedBox(width: Space.s)],
              Text(title, style: T.title(color: c.ink)),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: Space.m,
            crossAxisSpacing: Space.m,
            childAspectRatio: 0.92,
          ),
          itemCount: guides.length,
          itemBuilder: (context, i) {
            final guide = guides[i];
            final selected = _selected.contains(guide.name);
            return _CropTile(
              guide: guide,
              selected: selected,
              onTap: () => setState(() {
                if (!_selected.remove(guide.name)) _selected.add(guide.name);
              }),
            );
          },
        ),
      ),
    ];
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.state, required this.region, required this.onRetry, required this.onPick});

  final _Locating state;
  final SenegalRegion? region;
  final VoidCallback onRetry;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    switch (state) {
      case _Locating.searching:
        return Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: Space.m),
            Text('Je cherche où vous êtes…', style: T.body(color: c.ink2, weight: 700)),
          ],
        );
      case _Locating.found:
        return PressScale(
          onTap: onPick,
          child: Container(
            height: Hit.primary,
            padding: const EdgeInsets.symmetric(horizontal: Space.l),
            decoration: BoxDecoration(color: c.domainMeteo.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.pill)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_rounded, color: c.domainMeteo, size: 26),
                const SizedBox(width: Space.s),
                Flexible(child: Text(region?.name ?? '', style: T.title(color: c.ink), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: Space.m),
                Icon(Icons.edit_rounded, color: c.ink2, size: 20),
              ],
            ),
          ),
        );
      case _Locating.failed:
        return Wrap(
          spacing: Space.m,
          runSpacing: Space.s,
          children: [
            PressScale(
              onTap: onRetry,
              child: _ChipButton(icon: Icons.my_location_rounded, label: 'Me localiser', color: c.accent),
            ),
            PressScale(
              onTap: onPick,
              child: _ChipButton(icon: Icons.place_rounded, label: 'Choisir ma région', color: c.domainMeteo),
            ),
          ],
        );
    }
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Hit.primary,
      padding: const EdgeInsets.symmetric(horizontal: Space.l),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: Space.s),
          Text(label, style: T.body(color: color, weight: 700)),
        ],
      ),
    );
  }
}

/// Photo de la culture (comme dans le catalogue des produits), nom en grand, coche quand elle est choisie.
class _CropTile extends StatelessWidget {
  const _CropTile({required this.guide, required this.selected, required this.onTap});

  final AgronomicGuide guide;
  final bool selected;
  final VoidCallback onTap;

  static const _images = {
    'arachide': 'arachide.png',
    'aubergine': 'aubergine.png',
    'carotte': 'carotte.png',
    'chou': 'chou.png',
    'gombo': 'gombo.png',
    'mangue': 'mangue.png',
    'manioc': 'manioc.png',
    'melon': 'melon.png',
    'mais': 'mais.png',
    'mil': 'mil.png',
    'niebe': 'niebe.png',
    'oignon': 'oignon_local.png',
    'patate-douce': 'patate_douce.png',
    'piment': 'piment.png',
    'pomme-de-terre': 'pomme_de_terre.png',
    'riz-irrigue': 'riz.png',
    'sorgho': 'sorgho.png',
    'tomate-industrielle': 'tomate.png',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final file = _images[guide.slug];
    return PressScale(
      onTap: onTap,
      semanticLabel: guide.name,
      child: AnimatedContainer(
        duration: Motion.fast,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(color: selected ? c.accent : c.line, width: selected ? 3.5 : 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.3 : 0.06), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.l - 2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (file != null)
                Image.asset(
                  'assets/images/products/$file',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _fallback(c),
                )
              else
                _fallback(c),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB3000000)],
                  ),
                ),
              ),
              Positioned(
                left: Space.m,
                right: Space.m,
                bottom: Space.m,
                child: Text(
                  guide.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: T.title(color: Colors.white),
                ),
              ),
              Positioned(
                top: Space.s,
                right: Space.s,
                child: AnimatedContainer(
                  duration: Motion.fast,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? c.accent : Colors.black.withValues(alpha: 0.28),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: selected ? Icon(Icons.check_rounded, color: c.onAccent, size: 26) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback(NaatalColors c) => Container(
        color: c.domainCultures.withValues(alpha: 0.18),
        child: Icon(Icons.grass_rounded, size: 56, color: c.domainCultures),
      );
}

class _RegionSheet extends StatelessWidget {
  const _RegionSheet({required this.current, required this.onPick});

  final SenegalRegion? current;
  final ValueChanged<SenegalRegion> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Votre région', style: T.title(color: c.ink)),
          const SizedBox(height: Space.l),
          Wrap(
            spacing: Space.m,
            runSpacing: Space.m,
            children: [
              for (final region in SenegalRegions.all)
                PressScale(
                  onTap: () => onPick(region),
                  child: Container(
                    height: Hit.primary,
                    padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: region.name == current?.name ? c.accent : c.surface,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(color: region.name == current?.name ? c.accent : c.line, width: 1.5),
                    ),
                    child: Text(
                      region.name,
                      style: T.body(color: region.name == current?.name ? c.onAccent : c.ink, weight: 700),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
