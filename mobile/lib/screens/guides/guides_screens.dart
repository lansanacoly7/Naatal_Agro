import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agriculture/data/guides_provider.dart';
import '../../features/agriculture/data/models/agronomic_guide.dart';
import '../../ui/ui.dart';
import '../markets/markets_data.dart';

const _categories = [
  ('all', 'Toutes'),
  ('legume', 'Légumes'),
  ('cereale', 'Céréales'),
  ('legumineuse', 'Légumineuses'),
  ('fruit', 'Fruits'),
];

/// Fiches techniques : cultures du Sénégal, avec leurs sources.
class GuidesListScreen extends ConsumerStatefulWidget {
  const GuidesListScreen({super.key});

  @override
  ConsumerState<GuidesListScreen> createState() => _GuidesListScreenState();
}

class _GuidesListScreenState extends ConsumerState<GuidesListScreen> {
  String _category = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final state = ref.watch(guidesNotifierProvider);
    final shown = state.guides.where((g) {
      if (_category != 'all' && g.category.toLowerCase() != _category) return false;
      final q = _query.trim().toLowerCase();
      return q.isEmpty || g.name.toLowerCase().contains(q) || g.scientificName.toLowerCase().contains(q);
    }).toList();

    return LargeTitleScaffold(
      title: 'Fiches techniques',
      eyebrow: state.guides.isEmpty ? null : '${state.guides.length} cultures',
      reserveNav: false,
      onRefresh: () => ref.read(guidesNotifierProvider.notifier).loadGuides(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.isFromCache) const StatusStrip(text: 'Fiches enregistrées sur votre téléphone (hors ligne).', icon: Icons.offline_pin_rounded),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(hintText: 'Rechercher une culture', prefixIcon: Icon(Icons.search_rounded)),
                ),
              ),
              SizedBox(
                height: 62,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.m),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: Space.s),
                  itemBuilder: (context, i) {
                    final (key, label) = _categories[i];
                    final selected = _category == key;
                    return PressScale(
                      onTap: () => setState(() => _category = key),
                      child: AnimatedContainer(
                        duration: Motion.base,
                        curve: Motion.out,
                        padding: const EdgeInsets.symmetric(horizontal: Space.l),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? c.accent : c.surface,
                          borderRadius: BorderRadius.circular(Radii.pill),
                          border: Border.all(color: selected ? c.accent : c.line),
                        ),
                        child: Text(label, style: T.caption(color: selected ? c.onAccent : c.ink, weight: 700)),
                      ),
                    );
                  },
                ),
              ),
              if (state.isLoading && state.guides.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(horizontal: Space.gutter), child: Skeleton(height: 240, radius: 20))
              else if (state.error != null && state.guides.isEmpty)
                ErrorState(message: state.error!, onRetry: () => ref.read(guidesNotifierProvider.notifier).loadGuides())
              else if (shown.isEmpty)
                const EmptyState(icon: Icons.search_off_rounded, title: 'Aucune fiche', message: 'Aucune culture ne correspond à votre recherche.')
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = (constraints.maxWidth - Space.m) / 2;
                      return Wrap(
                        spacing: Space.m,
                        runSpacing: Space.m,
                        children: [
                          for (var i = 0; i < shown.length; i++)
                            SizedBox(
                              width: cardWidth,
                              child: Reveal(
                                index: i,
                                child: _GuidePhotoCard(
                                  guide: shown[i],
                                  onTap: () => context.push('/agriculture/guides/${shown[i].slug}'),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: Space.xxl),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuidePhotoCard extends StatelessWidget {
  const _GuidePhotoCard({required this.guide, required this.onTap});

  final AgronomicGuide guide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final img = productImageForName(guide.name);
    return PressScale(
      onTap: onTap,
      child: Container(
        height: 184,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(color: c.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: c.isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: c.surfaceAlt,
                padding: const EdgeInsets.all(Space.m),
                child: Image.asset(
                  img,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(Icons.eco_rounded, size: 40, color: c.accent),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.m),
              color: c.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    guide.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.body(color: c.ink, weight: 800),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: c.isDark ? 0.25 : 0.1),
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Text(
                          guide.cycleDisplay ?? guide.categoryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.caption(color: c.accent, weight: 700),
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
}

/// Détail d'une fiche : chaque rubrique vide est signalée « non documentée ».
class GuideDetailScreen extends ConsumerWidget {
  const GuideDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final state = ref.watch(guideDetailProvider(slug));
    final guide = state.guide;

    return LargeTitleScaffold(
      title: guide?.name ?? 'Fiche',
      eyebrow: guide?.categoryLabel,
      reserveNav: false,
      onRefresh: () => ref.read(guideDetailProvider(slug).notifier).loadGuide(),
      bottom: guide == null
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, MediaQuery.paddingOf(context).bottom + Space.m),
              decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
              child: PillButton(
                label: 'Cultiver ${guide.name}',
                icon: Icons.add_rounded,
                expand: true,
                onPressed: () => context.push('/agriculture/add', extra: guide.slug),
              ),
            ),
      slivers: [
        SliverToBoxAdapter(
          child: Builder(builder: (context) {
            if (state.isLoading && guide == null) {
              return const Padding(padding: EdgeInsets.all(Space.gutter), child: Skeleton(height: 260, radius: 24));
            }
            if (guide == null) {
              return ErrorState(
                message: state.error ?? 'Cette fiche n\'a pas pu être chargée.',
                onRetry: () => ref.read(guideDetailProvider(slug).notifier).loadGuide(),
              );
            }
            final img = productImageForName(guide.name);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.isFromCache) const StatusStrip(text: 'Fiche enregistrée sur votre téléphone (hors ligne).', icon: Icons.offline_pin_rounded),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(Radii.xl),
                      border: Border.all(color: c.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: c.isDark ? 0.25 : 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 160,
                          color: c.surfaceAlt,
                          padding: const EdgeInsets.all(Space.l),
                          child: Image.asset(
                            img,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(Icons.eco_rounded, size: 64, color: c.accent),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(Space.xl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (guide.scientificName.isNotEmpty)
                                Text(
                                  guide.scientificName,
                                  style: T.caption(color: c.ink2).copyWith(fontStyle: FontStyle.italic),
                                ),
                              const SizedBox(height: Space.xs),
                              Text(
                                guide.summary.isEmpty ? 'Présentation non documentée dans nos sources.' : guide.summary,
                                style: T.body(color: c.ink),
                              ),
                              const SizedBox(height: Space.m),
                              Wrap(
                                spacing: Space.s,
                                runSpacing: Space.s,
                                children: [
                                  if (guide.cycleDisplay != null)
                                    _GuideChip(icon: Icons.timer_outlined, text: 'Cycle : ${guide.cycleDisplay}', color: c.accent),
                                  _GuideChip(icon: Icons.menu_book_rounded, text: '${guide.sources.length} source${guide.sources.length > 1 ? 's' : ''}', color: c.slate),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Space.l),
                GuideSections(guide: guide),
                const SizedBox(height: Space.xxl),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _GuideChip extends StatelessWidget {
  const _GuideChip({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: c.isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: T.caption(color: color, weight: 700)),
        ],
      ),
    );
  }
}

class _Section extends StatefulWidget {
  const _Section({required this.title, required this.text, required this.icon});

  final String title;
  final String text;
  final IconData icon;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final documented = widget.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.s),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            PressScale(
              onTap: documented ? () => setState(() => _open = !_open) : null,
              scale: 0.99,
              child: Padding(
                padding: const EdgeInsets.all(Space.l),
                child: Row(
                  children: [
                    IconTile(icon: widget.icon, color: documented ? c.accent : c.ink2.withValues(alpha: 0.5), size: 34),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: T.body(color: c.ink, weight: 700)),
                          if (!documented) Text('Non documenté dans nos sources', style: T.caption(color: c.ink2, weight: 500)),
                        ],
                      ),
                    ),
                    if (documented) AnimatedRotation(turns: _open ? 0.5 : 0, duration: Motion.base, child: Icon(Icons.expand_more_rounded, color: c.ink2)),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.out,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.l),
                      child: SelectableText(widget.text.trim(), style: T.body(color: c.ink).copyWith(height: 1.5)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _PestsSection extends StatefulWidget {
  const _PestsSection({required this.items});

  final List<PestDiseaseItem> items;

  @override
  State<_PestsSection> createState() => _PestsSectionState();
}

class _PestsSectionState extends State<_PestsSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final documented = widget.items.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.s),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            PressScale(
              onTap: documented ? () => setState(() => _open = !_open) : null,
              scale: 0.99,
              child: Padding(
                padding: const EdgeInsets.all(Space.l),
                child: Row(
                  children: [
                    IconTile(icon: Icons.bug_report_rounded, color: documented ? c.clay : c.ink2.withValues(alpha: 0.5), size: 34),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Maladies et ravageurs', style: T.body(color: c.ink, weight: 700)),
                          if (!documented) Text('Non documenté dans nos sources', style: T.caption(color: c.ink2, weight: 500)),
                        ],
                      ),
                    ),
                    if (documented) AnimatedRotation(turns: _open ? 0.5 : 0, duration: Motion.base, child: Icon(Icons.expand_more_rounded, color: c.ink2)),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.out,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.l),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final p in widget.items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Space.m),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: T.body(color: c.ink, weight: 700)),
                                  const SizedBox(height: 2),
                                  SelectableText(p.advice, style: T.body(color: c.ink2).copyWith(height: 1.45)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rubriques d'une fiche technique (zones, calendrier, sol, eau, fertilisation, ravageurs,
/// récolte, rendement, limites, sources) : utilisées par la fiche d'une culture.
class GuideSections extends StatelessWidget {
  const GuideSections({super.key, required this.guide});

  final AgronomicGuide guide;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(title: 'Zones de culture', text: guide.zones, icon: Icons.map_rounded),
        _Section(title: 'Calendrier', text: guide.calendar, icon: Icons.event_rounded),
        _Section(title: 'Sol et semis', text: guide.soilAndSowing, icon: Icons.grass_rounded),
        _Section(title: 'Eau', text: guide.waterNeeds, icon: Icons.water_drop_rounded),
        _Section(title: 'Fertilisation', text: guide.fertilization, icon: Icons.science_rounded),
        _PestsSection(items: guide.pestsDiseases),
        _Section(title: 'Récolte', text: guide.harvest, icon: Icons.agriculture_rounded),
        _Section(title: 'Rendement', text: guide.yieldInfo, icon: Icons.bar_chart_rounded),
        if (guide.limitations.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s, Space.gutter, 0),
            child: Container(
              padding: const EdgeInsets.all(Space.l),
              decoration: BoxDecoration(color: c.clay.withValues(alpha: c.isDark ? 0.18 : 0.1), borderRadius: BorderRadius.circular(Radii.l)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: c.clay),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('À vérifier', style: T.body(color: c.clay, weight: 800)),
                        const SizedBox(height: 2),
                        Text(guide.limitations.trim(), style: T.caption(color: c.ink, weight: 500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SectionHeader('Sources'),
        if (guide.sources.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text('Aucune source enregistrée.', style: T.body(color: c.ink2)),
          )
        else
          GroupedList(
            children: [
              for (var i = 0; i < guide.sources.length; i++)
                GroupedRow(
                  leading: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                    child: Text('${i + 1}', style: T.number(16, color: c.accent)),
                  ),
                  title: guide.sources[i].title,
                  subtitle: [
                    if (guide.sources[i].publisher.isNotEmpty) guide.sources[i].publisher,
                    if (guide.sources[i].year.isNotEmpty) guide.sources[i].year,
                    if (!guide.sources[i].isSenegal) 'Référence hors Sénégal, à adapter',
                  ].join(' · '),
                  trailing: guide.sources[i].url.isEmpty ? null : Icon(Icons.copy_rounded, size: 18, color: c.ink2),
                  onTap: guide.sources[i].url.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: guide.sources[i].url));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien de la source copié.')));
                          }
                        },
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter + 4, Space.m, Space.gutter, 0),
          child: Text('Confirmez toujours les doses et produits avec un conseiller agricole (ANCAR, SAED).', style: T.caption(color: c.ink2, weight: 500)),
        ),
      ],
    );
  }
}
