import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agriculture/data/agriculture_provider.dart';
import '../../features/agriculture/data/models/crop.dart';
import '../../shared/utils/data_refresh.dart';
import '../../ui/ui.dart';
import 'crops_screen.dart' show cropInk, cropTints, harvestCaption;
import 'harvest_flow.dart';

/// Fiche d'une culture : avancement réel, activités, récoltes et actions.
class CropDetailScreen extends ConsumerWidget {
  const CropDetailScreen({super.key, required this.cropId});

  final String cropId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final crops = ref.watch(cropsProvider);

    return crops.when(
      loading: () => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(backgroundColor: c.bg),
        body: const Padding(padding: EdgeInsets.all(Space.gutter), child: Skeleton(height: 240, radius: 28)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(backgroundColor: c.bg),
        body: ErrorState(
          message: 'Cette culture n\'a pas pu être chargée.',
          onRetry: () => ref.invalidate(cropsProvider),
        ),
      ),
      data: (list) {
        final index = list.indexWhere((x) => x.id == cropId);
        if (index < 0) {
          return Scaffold(
            backgroundColor: c.bg,
            appBar: AppBar(backgroundColor: c.bg),
            body: EmptyState(
              icon: Icons.eco_rounded,
              title: 'Culture introuvable',
              message: 'Elle a peut-être été supprimée.',
              actionLabel: 'Retour aux cultures',
              onAction: () => context.go('/agriculture'),
            ),
          );
        }
        return _Detail(crop: list[index], tint: cropTints[index % cropTints.length]);
      },
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.crop, required this.tint});

  final Crop crop;
  final Color tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final harvested = crop.status == 'harvested';
    final progress = crop.progressOrNull;
    final planting = crop.parsedPlantingDate;
    final harvestDate = crop.parsedHarvestDate;

    return LargeTitleScaffold(
      title: crop.name,
      reserveNav: false,
      onRefresh: () async {
        ref.invalidate(cropsProvider);
        await ref.read(cropsProvider.future);
      },
      actions: [
        IconButton(
          tooltip: 'Modifier ou supprimer',
          icon: Icon(Icons.more_horiz_rounded, color: c.ink),
          onPressed: () => showNaatalSheet<void>(context, builder: (ctx) => _CropMenu(crop: crop)),
        ),
      ],
      bottom: harvested
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, MediaQuery.paddingOf(context).bottom + Space.m),
              decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
              child: PillButton(
                label: 'Enregistrer la récolte',
                icon: Icons.agriculture_rounded,
                expand: true,
                onPressed: () => showHarvestSheet(context, ref, crop),
              ),
            ),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Container(
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
                            Text(harvestCaption(crop), style: T.title(color: cropInk)),
                            const SizedBox(height: Space.s),
                            Text(
                              [
                                if (crop.areaSize > 0) '${Fmt.decimal(crop.areaSize)} ha',
                                if (crop.location.isNotEmpty) crop.location,
                                if (crop.cropType.isNotEmpty && crop.cropType != crop.name) crop.cropType,
                              ].join(' · '),
                              style: T.caption(color: cropInk.withValues(alpha: 0.78), weight: 600),
                            ),
                          ],
                        ),
                      ),
                      ProgressRing(
                        value: harvested ? 1 : (progress ?? 0),
                        size: 92,
                        stroke: 10,
                        color: cropInk,
                        track: cropInk.withValues(alpha: 0.16),
                        child: Text(
                          harvested ? '✓' : (progress == null ? '–' : '${(progress * 100).round()}%'),
                          style: T.number(22, color: cropInk, weight: 800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SectionHeader('Calendrier'),
              GroupedList(
                children: [
                  GroupedRow(
                    leading: IconTile(icon: Icons.grass_rounded, color: c.accent),
                    title: 'Semis',
                    value: planting == null ? 'À renseigner' : Fmt.shortDate(planting),
                  ),
                  GroupedRow(
                    leading: IconTile(icon: Icons.agriculture_rounded, color: c.clay),
                    title: 'Récolte prévue',
                    value: harvestDate == null ? 'À renseigner' : Fmt.shortDate(harvestDate),
                  ),
                ],
              ),
              const SectionHeader('Fiche technique'),
              if (crop.guideSlug != null && crop.guideSlug!.isNotEmpty)
                GroupedList(
                  children: [
                    GroupedRow(
                      leading: IconTile(icon: Icons.menu_book_rounded, color: c.slate),
                      title: crop.guideName ?? 'Fiche technique',
                      subtitle: 'Semis, eau, engrais, maladies, sources',
                      chevron: true,
                      onTap: () => context.push('/agriculture/guides/${crop.guideSlug}'),
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: AppCard(
                    child: Text(
                      'Aucune fiche technique liée à cette culture. Choisissez-en une à la création pour voir les conseils sourcés.',
                      style: T.body(color: c.ink2),
                    ),
                  ),
                ),
              SectionHeader(
                'Activités',
                action: harvested ? null : 'Ajouter',
                onAction: () => showNaatalSheet<void>(context, builder: (ctx) => _AddActivitySheet(crop: crop)),
              ),
              if (crop.activities.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: AppCard(
                    child: EmptyState(
                      compact: true,
                      icon: Icons.checklist_rounded,
                      title: 'Aucune activité',
                      message: 'Notez vos arrosages, engrais et traitements. Les coûts sont ajoutés à vos dépenses.',
                      actionLabel: harvested ? null : 'Ajouter une activité',
                      onAction: harvested ? null : () => showNaatalSheet<void>(context, builder: (ctx) => _AddActivitySheet(crop: crop)),
                    ),
                  ),
                )
              else
                GroupedList(
                  children: [
                    for (final a in (List<CropActivity>.from(crop.activities)
                      ..sort((x, y) => (y.parsedDate ?? DateTime(2000)).compareTo(x.parsedDate ?? DateTime(2000)))))
                      GroupedRow(
                        leading: IconTile(icon: Icons.task_alt_rounded, color: c.accent),
                        title: a.activityType,
                        subtitle: [
                          if (a.parsedDate != null) Fmt.shortDate(a.parsedDate!),
                          if (a.description.isNotEmpty) a.description,
                        ].join(' · '),
                        value: (a.cost ?? 0) > 0 ? '−${Fmt.grouped(a.cost!)} F' : null,
                        valueColor: c.clay,
                      ),
                  ],
                ),
              if (crop.harvests.isNotEmpty) ...[
                const SectionHeader('Récoltes'),
                GroupedList(
                  children: [
                    for (final h in crop.harvests)
                      GroupedRow(
                        leading: IconTile(icon: Icons.agriculture_rounded, color: c.accent),
                        title: 'Récolte',
                        subtitle: h.parsedDate == null ? null : Fmt.shortDate(h.parsedDate!),
                        value: '+${Fmt.decimal(h.quantity)} ${h.unit}',
                        valueColor: c.accent,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CropMenu extends ConsumerWidget {
  const _CropMenu({required this.crop});

  final Crop crop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(crop.name, style: T.title(color: context.c.ink)),
          const SizedBox(height: Space.xl),
          PillButton(
            label: 'Modifier la culture',
            icon: Icons.edit_rounded,
            variant: PillVariant.secondary,
            expand: true,
            onPressed: () {
              Navigator.pop(context);
              showNaatalSheet<void>(context, builder: (ctx) => _EditCropSheet(crop: crop));
            },
          ),
          const SizedBox(height: Space.s),
          PillButton(
            label: 'Supprimer la culture',
            icon: Icons.delete_outline_rounded,
            variant: PillVariant.danger,
            expand: true,
            onPressed: () async {
              final navigator = Navigator.of(context);
              final router = GoRouter.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final ok = await confirmDialog(
                context,
                title: 'Supprimer ${crop.name} ?',
                message: 'Ses activités et ses récoltes seront aussi supprimées. Cette action est définitive.',
                confirmLabel: 'Supprimer',
                destructive: true,
              );
              if (!ok) return;
              try {
                await ref.read(agricultureRepositoryProvider).deleteCrop(crop.id);
                refreshAfterDataChange(ref);
                navigator.pop();
                router.go('/agriculture');
              } catch (_) {
                messenger.showSnackBar(const SnackBar(content: Text('Suppression impossible. Vérifiez votre réseau.')));
              }
            },
          ),
        ],
      ),
    );
  }
}

class _EditCropSheet extends ConsumerStatefulWidget {
  const _EditCropSheet({required this.crop});

  final Crop crop;

  @override
  ConsumerState<_EditCropSheet> createState() => _EditCropSheetState();
}

class _EditCropSheetState extends ConsumerState<_EditCropSheet> {
  late final _name = TextEditingController(text: widget.crop.name);
  late final _area = TextEditingController(text: Fmt.decimal(widget.crop.areaSize).replaceAll(' ', ''));
  late final _location = TextEditingController(text: widget.crop.location);
  late String _status = const ['active', 'paused', 'harvested'].contains(widget.crop.status) ? widget.crop.status : 'active';
  bool _busy = false;
  String? _error;

  static const _labels = {'active': 'En cours', 'paused': 'En pause', 'harvested': 'Récoltée'};

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final area = double.tryParse(_area.text.trim().replaceAll(',', '.'));
    if (_name.text.trim().isEmpty || area == null || area <= 0) {
      setState(() => _error = 'Indiquez un nom et une surface valide.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(agricultureRepositoryProvider).updateCrop(widget.crop.id, {
        'name': _name.text.trim(),
        'area_size': area,
        'location': _location.text.trim(),
        'status': _status,
      });
      refreshAfterDataChange(ref);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Modification impossible. Vérifiez votre réseau.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Modifier la culture', style: T.title(color: c.ink)),
          const SizedBox(height: Space.l),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom')),
          const SizedBox(height: Space.m),
          TextField(
            controller: _area,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(labelText: 'Surface en hectares'),
          ),
          const SizedBox(height: Space.m),
          TextField(controller: _location, decoration: const InputDecoration(labelText: 'Lieu')),
          const SizedBox(height: Space.m),
          Row(
            children: [
              for (final entry in _labels.entries) ...[
                Expanded(
                  child: PressScale(
                    onTap: () => setState(() => _status = entry.key),
                    child: AnimatedContainer(
                      duration: Motion.base,
                      curve: Motion.out,
                      height: Hit.min,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _status == entry.key ? c.accent : c.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.m),
                      ),
                      child: Text(entry.value, style: T.caption(color: _status == entry.key ? c.onAccent : c.ink, weight: 700)),
                    ),
                  ),
                ),
                if (entry.key != 'harvested') const SizedBox(width: Space.s),
              ],
            ],
          ),
          if (_status == 'harvested' && widget.crop.status != 'harvested')
            Padding(
              padding: const EdgeInsets.only(top: Space.s),
              child: Text(
                'Pour ajouter la quantité au stock, utilisez plutôt « Enregistrer la récolte ».',
                style: T.caption(color: c.ink2, weight: 500),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.m),
              child: Text(_error!, style: T.caption(color: c.clay, weight: 700)),
            ),
          const SizedBox(height: Space.xl),
          PillButton(label: 'Enregistrer', expand: true, loading: _busy, onPressed: _busy ? null : _save),
        ],
      ),
    );
  }
}

class _AddActivitySheet extends ConsumerStatefulWidget {
  const _AddActivitySheet({required this.crop});

  final Crop crop;

  @override
  ConsumerState<_AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends ConsumerState<_AddActivitySheet> {
  static const _types = ['Arrosage', 'Engrais', 'Traitement', 'Désherbage', 'Autre'];
  String _type = _types.first;
  final _description = TextEditingController();
  final _cost = TextEditingController();
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final cost = _cost.text.trim().isEmpty ? null : double.tryParse(_cost.text.trim().replaceAll(',', '.'));
    if (_cost.text.trim().isNotEmpty && (cost == null || cost < 0)) {
      setState(() => _error = 'Coût invalide.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(agricultureRepositoryProvider).addActivity(
            cropId: widget.crop.id,
            type: _type,
            date: _date.toIso8601String().split('T').first,
            description: _description.text.trim(),
            cost: cost,
          );
      refreshAfterDataChange(ref);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Enregistrement impossible. Vérifiez votre réseau.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nouvelle activité', style: T.title(color: c.ink)),
          const SizedBox(height: 2),
          Text(widget.crop.name, style: T.body(color: c.ink2)),
          const SizedBox(height: Space.l),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final t in _types)
                PressScale(
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.out,
                    height: Hit.min,
                    padding: const EdgeInsets.symmetric(horizontal: Space.l),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _type == t ? c.accent : c.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(t, style: T.caption(color: _type == t ? c.onAccent : c.ink, weight: 700)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.l),
          PressScale(
            onTap: _pickDate,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: Space.l),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.m),
                border: Border.all(color: c.line, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 20, color: c.accent),
                  const SizedBox(width: Space.m),
                  Text(Fmt.shortDate(_date), style: T.body(color: c.ink, weight: 600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Détail (facultatif)'),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _cost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              labelText: 'Coût en FCFA (facultatif)',
              helperText: 'Un coût est ajouté automatiquement à vos dépenses.',
              errorText: _error,
            ),
          ),
          const SizedBox(height: Space.xl),
          PillButton(label: 'Enregistrer', expand: true, loading: _busy, onPressed: _busy ? null : _save),
        ],
      ),
    );
  }
}
