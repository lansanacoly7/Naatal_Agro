import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/agriculture/data/guides_provider.dart';
import '../../features/agriculture/data/models/agronomic_guide.dart';
import '../../ui/ui.dart';
import 'guide_text_cleaner.dart';
import 'guide_videos.dart';

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
                padding: EdgeInsets.zero,
                child: Image.asset(
                  img,
                  fit: BoxFit.cover,
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
                          padding: EdgeInsets.zero,
                          child: Image.asset(
                            img,
                            fit: BoxFit.cover,
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
                                  cleanGuideText(guide.scientificName),
                                  style: T.caption(color: c.ink2).copyWith(fontStyle: FontStyle.italic),
                                ),
                              const SizedBox(height: Space.xs),
                              Text(
                                guide.summary.isEmpty ? 'Présentation non documentée dans nos sources.' : cleanGuideText(guide.summary),
                                style: T.body(color: c.ink).copyWith(height: 1.5),
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

class _AudioGuideBar extends StatefulWidget {
  const _AudioGuideBar({required this.guide});

  final AgronomicGuide guide;

  @override
  State<_AudioGuideBar> createState() => _AudioGuideBarState();
}

class _AudioGuideBarState extends State<_AudioGuideBar> {
  FlutterTts? _tts;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      final tts = FlutterTts();
      await tts.setLanguage('fr-FR');
      await tts.setSpeechRate(0.48);
      await tts.setVolume(1.0);
      tts.setCompletionHandler(() {
        if (mounted) setState(() => _isPlaying = false);
      });
      tts.setCancelHandler(() {
        if (mounted) setState(() => _isPlaying = false);
      });
      tts.setErrorHandler((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
      _tts = tts;
    } catch (_) {}
  }

  Future<void> _togglePlay() async {
    if (_tts == null) return;
    if (_isPlaying) {
      await _tts?.stop();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      if (mounted) setState(() => _isPlaying = true);
      final g = widget.guide;
      final textToSpeak = [
        'Fiche technique de ${g.name}.',
        if (g.summary.isNotEmpty) cleanGuideText(g.summary),
        if (g.calendar.isNotEmpty) 'Calendrier : ${cleanGuideText(g.calendar)}',
        if (g.soilAndSowing.isNotEmpty) 'Sol et semis : ${cleanGuideText(g.soilAndSowing)}',
        if (g.waterNeeds.isNotEmpty) 'Arrosage et besoins en eau : ${cleanGuideText(g.waterNeeds)}',
        if (g.harvest.isNotEmpty) 'Récolte : ${cleanGuideText(g.harvest)}',
      ].join(' ');
      try {
        await _tts?.speak(textToSpeak);
      } catch (_) {
        if (mounted) setState(() => _isPlaying = false);
      }
    }
  }

  @override
  void dispose() {
    _tts?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
        decoration: BoxDecoration(
          color: _isPlaying
              ? c.accent.withValues(alpha: c.isDark ? 0.25 : 0.12)
              : c.surface,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(
            color: _isPlaying ? c.accent : c.line,
            width: _isPlaying ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: c.isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isPlaying ? c.accent : c.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.volume_up_rounded : Icons.headphones_rounded,
                color: _isPlaying ? Colors.white : c.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isPlaying ? 'Lecture audio en cours...' : 'Écouter la fiche (vocal)',
                    style: T.body(color: _isPlaying ? c.accent : c.ink, weight: 700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isPlaying ? 'Appuyez pour mettre en pause' : 'Idéal pour écouter les conseils au champ',
                    style: T.caption(color: c.ink2, weight: 500),
                  ),
                ],
              ),
            ),
            PillButton(
              label: _isPlaying ? 'Arrêter' : 'Écouter',
              icon: _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
              compact: true,
              variant: _isPlaying ? PillVariant.secondary : PillVariant.primary,
              onPressed: _togglePlay,
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoGuideCard extends StatelessWidget {
  const _VideoGuideCard({required this.video});

  final GuideVideoInfo video;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: c.isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFF064E3B), const Color(0xFF047857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(Radii.xl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final uri = Uri.parse(video.url);
              try {
                if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  await launchUrl(uri);
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Impossible d\'ouvrir la vidéo.')),
                  );
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(Space.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 5),
                            Text(
                              'TUTORIEL VIDÉO',
                              style: T.caption(color: Colors.white, weight: 800),
                            ),
                          ],
                        ),
                      ),
                      if (video.duration.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(Radii.pill),
                          ),
                          child: Text(
                            video.duration,
                            style: T.caption(color: Colors.white70, weight: 700),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.m),
                  Text(
                    video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        video.channel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.s),
                  Text(
                    video.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: Space.m),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Color(0xFF064E3B), size: 18),
                            const SizedBox(width: 4),
                            const Text(
                              'Voir sur YouTube',
                              style: TextStyle(
                                color: Color(0xFF064E3B),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatefulWidget {
  const _Section({
    required this.title,
    required this.text,
    required this.icon,
    this.color,
  });

  final String title;
  final String text;
  final IconData icon;
  final Color? color;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cleaned = cleanGuideText(widget.text);
    final documented = cleaned.trim().isNotEmpty;
    final accentColor = widget.color ?? c.accent;

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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: documented ? accentColor.withValues(alpha: c.isDark ? 0.25 : 0.12) : c.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.m),
                      ),
                      child: Icon(
                        widget.icon,
                        color: documented ? accentColor : c.ink2.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: T.body(color: c.ink, weight: 700)),
                          if (!documented)
                            Text('Non documenté dans nos sources', style: T.caption(color: c.ink2, weight: 500)),
                        ],
                      ),
                    ),
                    if (documented)
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: Motion.base,
                        child: Icon(Icons.expand_more_rounded, color: c.ink2),
                      ),
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
                      child: _buildFormattedText(context, cleaned, accentColor),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedText(BuildContext context, String text, Color accentColor) {
    final c = context.c;
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines) ...[
          if (line.trim().startsWith('-') || line.trim().startsWith('•'))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7, right: 8),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: SelectableText(
                      line.replaceFirst(RegExp(r'^[-•]\s*'), '').trim(),
                      style: T.body(color: c.ink).copyWith(height: 1.55),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectableText(
                line.trim(),
                style: T.body(color: c.ink).copyWith(height: 1.55),
              ),
            ),
        ],
      ],
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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: documented ? c.clay.withValues(alpha: c.isDark ? 0.25 : 0.12) : c.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.m),
                      ),
                      child: Icon(
                        Icons.bug_report_rounded,
                        color: documented ? c.clay : c.ink2.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Maladies et ravageurs', style: T.body(color: c.ink, weight: 700)),
                          if (!documented)
                            Text('Non documenté dans nos sources', style: T.caption(color: c.ink2, weight: 500)),
                        ],
                      ),
                    ),
                    if (documented)
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: Motion.base,
                        child: Icon(Icons.expand_more_rounded, color: c.ink2),
                      ),
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
                            Container(
                              margin: const EdgeInsets.only(bottom: Space.m),
                              padding: const EdgeInsets.all(Space.m),
                              decoration: BoxDecoration(
                                color: c.surfaceAlt,
                                borderRadius: BorderRadius.circular(Radii.m),
                                border: Border.all(color: c.line),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, size: 16, color: c.clay),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          cleanGuideText(p.name),
                                          style: T.body(color: c.ink, weight: 700),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    cleanGuideText(p.advice),
                                    style: T.caption(color: c.ink2).copyWith(height: 1.45),
                                  ),
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

class _PillTag extends StatelessWidget {
  const _PillTag({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _VarietiesSection extends StatefulWidget {
  const _VarietiesSection({required this.varieties, required this.cropName});

  final List<CropVariety> varieties;
  final String cropName;

  @override
  State<_VarietiesSection> createState() => _VarietiesSectionState();
}

class _VarietiesSectionState extends State<_VarietiesSection> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final count = widget.varieties.length;
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.s),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            PressScale(
              onTap: () => setState(() => _open = !_open),
              scale: 0.99,
              child: Padding(
                padding: const EdgeInsets.all(Space.l),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF15803D).withValues(alpha: c.isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(Radii.m),
                      ),
                      child: const Icon(
                        Icons.park_rounded,
                        color: Color(0xFF15803D),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Variétés cultivées au Sénégal', style: T.body(color: c.ink, weight: 700)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: c.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(Radii.pill),
                                ),
                                child: Text('$count', style: T.caption(color: c.accent, weight: 800)),
                              ),
                            ],
                          ),
                          Text('Choix de semences certifiées selon votre zone', style: T.caption(color: c.ink2, weight: 500)),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: Motion.base,
                      child: Icon(Icons.expand_more_rounded, color: c.ink2),
                    ),
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
                          for (final v in widget.varieties)
                            Container(
                              margin: const EdgeInsets.only(bottom: Space.m),
                              padding: const EdgeInsets.all(Space.m),
                              decoration: BoxDecoration(
                                color: c.surfaceAlt,
                                borderRadius: BorderRadius.circular(Radii.m),
                                border: Border.all(color: c.line),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          v.name,
                                          style: T.body(color: c.ink, weight: 800).copyWith(fontSize: 16),
                                        ),
                                      ),
                                      if (v.cycle.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF15803D).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(Radii.pill),
                                          ),
                                          child: Text(
                                            v.cycle,
                                            style: T.caption(color: const Color(0xFF15803D), weight: 700),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (v.season.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today_rounded, size: 13, color: c.ink2),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            v.season,
                                            style: T.caption(color: c.ink2, weight: 600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (v.characteristics.isNotEmpty) ...[
                                    const SizedBox(height: Space.s),
                                    Text(
                                      v.characteristics,
                                      style: T.body(color: c.ink).copyWith(fontSize: 13.5, height: 1.45),
                                    ),
                                  ],
                                  if (v.yieldPotential.isNotEmpty || v.zones.isNotEmpty) ...[
                                    const SizedBox(height: Space.s),
                                    Wrap(
                                      spacing: Space.s,
                                      runSpacing: 4,
                                      children: [
                                        if (v.yieldPotential.isNotEmpty)
                                          _PillTag(
                                            icon: Icons.trending_up_rounded,
                                            label: 'Rendement : ' + v.yieldPotential,
                                            color: const Color(0xFF0F766E),
                                          ),
                                        if (v.zones.isNotEmpty)
                                          _PillTag(
                                            icon: Icons.place_rounded,
                                            label: v.zones,
                                            color: const Color(0xFFD97706),
                                          ),
                                      ],
                                    ),
                                  ],
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

class GuideSections extends StatelessWidget {
  const GuideSections({super.key, required this.guide});

  final AgronomicGuide guide;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final videoInfo = guide.video != null
        ? GuideVideoInfo(
            title: guide.video!.title,
            channel: guide.video!.channel,
            url: guide.video!.url,
            duration: guide.video!.duration,
          )
        : findVideoForCrop(guide.slug);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0. Barre de lecture vocale pour les utilisateurs peu alphabétisés
        _AudioGuideBar(guide: guide),
        const SizedBox(height: Space.m),

        // 1. Vidéo explicative pratique
        if (videoInfo != null) ...[
          _VideoGuideCard(video: videoInfo),
          const SizedBox(height: Space.m),
        ],

        // 1 bis. Variétés cultivées au Sénégal (Sélection et conseil d'investissement)
        if (guide.varieties.isNotEmpty) ...[
          _VarietiesSection(varieties: guide.varieties, cropName: guide.name),
          const SizedBox(height: Space.s),
        ],

        // 2. Rubriques de la fiche avec design soigné
        _Section(
          title: 'Zones de culture',
          text: guide.zones,
          icon: Icons.map_rounded,
          color: const Color(0xFF0F766E), // Teal
        ),
        _Section(
          title: 'Calendrier & Cycle',
          text: guide.calendar,
          icon: Icons.event_rounded,
          color: const Color(0xFFD97706), // Amber
        ),
        _Section(
          title: 'Sol, préparation et semis',
          text: guide.soilAndSowing,
          icon: Icons.grass_rounded,
          color: const Color(0xFF16A34A), // Green
        ),
        _Section(
          title: 'Besoins en eau & Irrigation',
          text: guide.waterNeeds,
          icon: Icons.water_drop_rounded,
          color: const Color(0xFF0284C7), // Blue
        ),
        _Section(
          title: 'Fertilisation & Fumure',
          text: guide.fertilization,
          icon: Icons.science_rounded,
          color: const Color(0xFF7C3AED), // Purple
        ),
        _PestsSection(items: guide.pestsDiseases),
        _Section(
          title: 'Récolte & Conservation',
          text: guide.harvest,
          icon: Icons.agriculture_rounded,
          color: const Color(0xFFEA580C), // Orange
        ),
        _Section(
          title: 'Rendements observés',
          text: guide.yieldInfo,
          icon: Icons.bar_chart_rounded,
          color: const Color(0xFF059669), // Emerald
        ),
        if (cleanGuideText(guide.limitations).trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s, Space.gutter, 0),
            child: Container(
              padding: const EdgeInsets.all(Space.l),
              decoration: BoxDecoration(
                color: c.clay.withValues(alpha: c.isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(Radii.l),
                border: Border.all(color: c.clay.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: c.clay),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Points d\'attention & vigilance', style: T.body(color: c.clay, weight: 800)),
                        const SizedBox(height: 2),
                        Text(
                          cleanGuideText(guide.limitations).trim(),
                          style: T.caption(color: c.ink, weight: 500),
                        ),
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
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${i + 1}', style: T.number(16, color: c.accent)),
                  ),
                  title: cleanGuideText(guide.sources[i].title),
                  subtitle: [
                    if (guide.sources[i].publisher.isNotEmpty) cleanGuideText(guide.sources[i].publisher),
                    if (guide.sources[i].year.isNotEmpty) cleanGuideText(guide.sources[i].year),
                    if (!guide.sources[i].isSenegal) 'Référence régionale hors Sénégal',
                  ].join(' · '),
                  trailing: guide.sources[i].url.isEmpty ? null : Icon(Icons.copy_rounded, size: 18, color: c.ink2),
                  onTap: guide.sources[i].url.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: guide.sources[i].url));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lien de la source copié.')),
                            );
                          }
                        },
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter + 4, Space.m, Space.gutter, 0),
          child: Text(
            'Recommandations basées sur la recherche agronomique (ISRA, ANCAR, FAO). Adaptez toujours à votre sol.',
            style: T.caption(color: c.ink2, weight: 500),
          ),
        ),
      ],
    );
  }
}
