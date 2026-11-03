import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../data/calendar_provider.dart';
import '../domain/season_logic.dart';
import 'calendar_widgets.dart' show CropPhoto;

/// Bandeau de l'accueil : ce qu'on sème, ce qu'on récolte et ce qu'il faut préparer ce mois-ci dans la zone de la personne.
/// Il ne montre rien tant qu'on ne connaît pas sa zone ou que le calendrier n'est pas chargé : jamais de texte inventé.
class SeasonBanner extends ConsumerWidget {
  const SeasonBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todaySeasonProvider);
    if (summary == null || summary.isEmpty) return const SizedBox.shrink();
    final c = context.c;

    // Ce qu'on fait ce mois-ci : semer d'abord, puis récolter, puis se préparer
    final (IconData icon, String verb, List<CropSeason> crops) todo = summary.sowing.isNotEmpty
        ? (Icons.grass_rounded, 'On sème', summary.sowing)
        : summary.harvesting.isNotEmpty
            ? (Icons.agriculture_rounded, 'On récolte', summary.harvesting)
            : (Icons.hourglass_top_rounded, 'Bientôt', summary.prepare);
    final shown = todo.$3.take(3).toList();
    final more = todo.$3.length - shown.length;
    final spoken = '${todo.$2} : ${shown.map((s) => s.crop.name.toLowerCase()).join(', ')}';

    return Padding(
      padding: const EdgeInsets.only(top: Space.l),
      child: PressScale(
        onTap: () => context.push('/calendar'),
        semanticLabel: 'Calendrier agricole. $spoken',
        child: Container(
          padding: const EdgeInsets.fromLTRB(Space.l, Space.m, Space.m, Space.l),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.l),
            border: Border.all(color: c.accent.withValues(alpha: 0.35), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(todo.$1, color: c.accent, size: 26),
                  const SizedBox(width: Space.s),
                  Expanded(child: Text('${todo.$2} ce mois-ci', style: T.title(color: c.ink))),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                    child: Icon(Icons.chevron_right_rounded, color: c.accent, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: Space.m),
              Row(
                children: [
                  for (final s in shown)
                    Expanded(
                      child: Column(
                        children: [
                          CropPhoto(cropKey: s.crop.key, width: 64, height: 64, radius: 32),
                          const SizedBox(height: Space.xs),
                          Text(
                            s.crop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: T.body(color: c.ink, weight: 700),
                          ),
                        ],
                      ),
                    ),
                  if (more > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: Space.s),
                      child: Text('+$more', style: T.title(color: c.ink2)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
