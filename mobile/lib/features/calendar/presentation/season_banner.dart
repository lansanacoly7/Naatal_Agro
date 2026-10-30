import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../data/calendar_provider.dart';
import '../domain/season_logic.dart';

/// Bandeau de l'accueil : ce qu'on sème, ce qu'on récolte et ce qu'il faut préparer ce mois-ci dans la zone de la personne.
/// Il ne montre rien tant qu'on ne connaît pas sa zone ou que le calendrier n'est pas chargé : jamais de texte inventé.
class SeasonBanner extends ConsumerWidget {
  const SeasonBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(todaySeasonProvider);
    if (summary == null || summary.isEmpty) return const SizedBox.shrink();
    final c = context.c;

    String names(List<CropSeason> list) => list.take(2).map((s) => s.crop.name.toLowerCase()).join(', ');

    // Une seule ligne : ce qu'on fait ce mois-ci (semer d'abord, puis récolter, puis se préparer)
    final (IconData, String) line = summary.sowing.isNotEmpty
        ? (Icons.grass_rounded, 'On sème : ${names(summary.sowing)}')
        : summary.harvesting.isNotEmpty
            ? (Icons.agriculture_rounded, 'On récolte : ${names(summary.harvesting)}')
            : (Icons.hourglass_top_rounded, 'Bientôt : ${names(summary.prepare)}');

    return Padding(
      padding: const EdgeInsets.only(top: Space.l),
      child: PressScale(
        onTap: () => context.push('/calendar'),
        semanticLabel: 'Calendrier agricole. ${line.$2}',
        child: Container(
          padding: const EdgeInsets.all(Space.l),
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(Radii.l),
            border: Border.all(color: c.accent, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(Radii.m)),
                child: Icon(line.$1, color: c.onAccent, size: 34),
              ),
              const SizedBox(width: Space.m),
              Expanded(child: Text(line.$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title(color: c.ink))),
              Icon(Icons.chevron_right_rounded, color: c.ink, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
