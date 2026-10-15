import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agriculture/data/agriculture_provider.dart';
import '../../features/agriculture/data/models/crop.dart';
import '../../ui/ui.dart';

/// Couleurs des cartes de culture (une par rang, fixes pour reconnaître une culture).
const List<Color> cropTints = [Color(0xFFF2C14E), Color(0xFF6FD3A0), Color(0xFFF4A38A), Color(0xFF9CC7E8)];
const Color cropInk = Color(0xFF17210F);

/// Texte « Récolte dans 38 jours » à partir des dates réelles de la culture.
String harvestCaption(Crop crop) {
  if (crop.status == 'harvested') return 'Récoltée';
  final days = crop.daysToHarvest;
  if (days == null) return 'Dates à renseigner';
  if (days > 1) return 'Récolte dans $days jours';
  if (days == 1) return 'Récolte demain';
  if (days == 0) return 'Récolte aujourd\'hui';
  return 'Récolte dépassée de ${-days} j';
}

/// Onglet « Cultures » : grandes cartes colorées avec l'avancement réel.
class CropsScreen extends ConsumerWidget {
  const CropsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crops = ref.watch(cropsProvider);
    final c = context.c;

    return LargeTitleScaffold(
      title: 'Mes cultures',
      eyebrow: crops.valueOrNull == null
          ? null
          : '${crops.value!.length} culture${crops.value!.length > 1 ? 's' : ''}',
      onRefresh: () async {
        ref.invalidate(cropsProvider);
        await ref.read(cropsProvider.future);
      },
      actions: [
        IconButton(
          tooltip: 'Fiches techniques',
          icon: Icon(Icons.menu_book_rounded, color: c.ink),
          onPressed: () => context.push('/agriculture/guides'),
        ),
        IconButton(
          tooltip: 'Nouvelle culture',
          icon: Icon(Icons.add_circle_rounded, color: c.accent, size: 30),
          onPressed: () => context.push('/agriculture/add'),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: crops.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Column(
                children: [
                  Skeleton(height: 168, radius: 28),
                  SizedBox(height: Space.m),
                  Skeleton(height: 168, radius: 28),
                ],
              ),
            ),
            error: (e, _) => ErrorState(
              message: 'Vos cultures n\'ont pas pu être chargées.',
              onRetry: () => ref.invalidate(cropsProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.eco_rounded,
                  title: 'Aucune culture',
                  message: 'Ajoutez une culture pour suivre son avancement, ses activités, sa récolte et son prix.',
                  actionLabel: 'Ajouter une culture',
                  onAction: () => context.push('/agriculture/add'),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Column(
                  children: [
                    for (var i = 0; i < list.length; i++)
                      Reveal(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: Space.m),
                          child: CropCard(crop: list[i], tint: cropTints[i % cropTints.length]),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Grande carte de culture colorée.
class CropCard extends StatelessWidget {
  const CropCard({super.key, required this.crop, required this.tint});

  final Crop crop;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final progress = crop.progressOrNull;
    final harvested = crop.status == 'harvested';
    final percent = harvested ? 100 : ((progress ?? 0) * 100).round();
    return PressScale(
      onTap: () => context.push('/agriculture/${crop.id}'),
      scale: 0.98,
      child: Container(
        height: 168,
        padding: const EdgeInsets.all(Space.xl),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: tint.withValues(alpha: 0.4), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(crop.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title(color: cropInk)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (crop.areaSize > 0) '${Fmt.decimal(crop.areaSize)} ha',
                      if (crop.location.isNotEmpty) crop.location,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.caption(color: cropInk.withValues(alpha: 0.75), weight: 600),
                  ),
                  const Spacer(),
                  Text(harvestCaption(crop), style: T.body(color: cropInk, weight: 700)),
                  if (crop.guideName != null && crop.guideName!.isNotEmpty)
                    Text('Fiche : ${crop.guideName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption(color: cropInk.withValues(alpha: 0.7), weight: 600)),
                ],
              ),
            ),
            const SizedBox(width: Space.m),
            ProgressRing(
              value: harvested ? 1 : (progress ?? 0),
              size: 84,
              stroke: 9,
              color: cropInk,
              track: cropInk.withValues(alpha: 0.16),
              child: Text(
                progress == null && !harvested ? '–' : '$percent%',
                style: T.number(20, color: cropInk, weight: 800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
