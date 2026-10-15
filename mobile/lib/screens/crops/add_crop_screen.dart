import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agriculture/data/agriculture_provider.dart';
import '../../features/agriculture/data/guides_provider.dart';
import '../../features/agriculture/data/models/agronomic_guide.dart';
import '../../features/profile/data/profile_provider.dart';
import '../../shared/utils/data_refresh.dart';
import '../../ui/ui.dart';

/// Nouvelle culture. La date de récolte n'est calculée que si la fiche technique
/// donne un cycle réel ; sinon l'utilisateur la choisit (aucune durée inventée).
class AddCropScreen extends ConsumerStatefulWidget {
  const AddCropScreen({super.key});

  @override
  ConsumerState<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends ConsumerState<AddCropScreen> {
  final _name = TextEditingController();
  final _type = TextEditingController();
  final _area = TextEditingController();
  late final TextEditingController _location = TextEditingController(
    text: ref.read(profileNotifierProvider).valueOrNull?.location ?? '',
  );
  AgronomicGuide? _guide;
  DateTime? _planting;
  DateTime? _harvest;
  bool _harvestAuto = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _area.dispose();
    _location.dispose();
    super.dispose();
  }

  int? _cycleDays(AgronomicGuide g) => g.cycleDaysMax ?? g.cycleDaysMin;

  void _selectGuide(AgronomicGuide g) {
    setState(() {
      _guide = g;
      _type.text = g.name;
      if (_name.text.trim().isEmpty) _name.text = g.name;
      _recomputeHarvest();
    });
  }

  void _recomputeHarvest() {
    final g = _guide;
    final planting = _planting;
    if (g == null || planting == null) return;
    final days = _cycleDays(g);
    if (days == null) {
      _harvestAuto = false;
      return;
    }
    _harvest = planting.add(Duration(days: days));
    _harvestAuto = true;
  }

  Future<DateTime?> _pick(DateTime initial, {DateTime? first, DateTime? last}) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateTime(2020),
      lastDate: last ?? DateTime.now().add(const Duration(days: 730)),
    );
  }

  Future<void> _save() async {
    final area = double.tryParse(_area.text.trim().replaceAll(',', '.'));
    final problems = <String>[
      if (_name.text.trim().isEmpty) 'le nom',
      if (_type.text.trim().isEmpty) 'la culture',
      if (area == null || area <= 0) 'la surface',
      if (_location.text.trim().isEmpty) 'le lieu',
      if (_planting == null) 'la date de semis',
      if (_harvest == null) 'la date de récolte prévue',
    ];
    if (problems.isNotEmpty) {
      setState(() => _error = 'À compléter : ${problems.join(', ')}.');
      return;
    }
    if (!_harvest!.isAfter(_planting!)) {
      setState(() => _error = 'La récolte doit être après le semis.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String d(DateTime x) => x.toIso8601String().split('T').first;
    try {
      await ref.read(agricultureRepositoryProvider).addCrop({
        'name': _name.text.trim(),
        'crop_type': _type.text.trim(),
        'area_size': area,
        'location': _location.text.trim(),
        'planting_date': d(_planting!),
        'expected_harvest_date': d(_harvest!),
        'status': 'active',
        if (_guide != null) 'guide': _guide!.id,
      });
      refreshAfterDataChange(ref);
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Culture ajoutée.')));
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Ajout impossible. Vérifiez votre réseau puis réessayez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final guides = ref.watch(guidesNotifierProvider);
    final cycle = _guide == null ? null : _cycleDays(_guide!);

    return LargeTitleScaffold(
      title: 'Nouvelle culture',
      reserveNav: false,
      bottom: Container(
        padding: EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, MediaQuery.paddingOf(context).bottom + Space.m),
        decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: Text(_error!, textAlign: TextAlign.center, style: T.caption(color: c.clay, weight: 700)),
              ),
            PillButton(label: 'Enregistrer la culture', icon: Icons.check_rounded, expand: true, loading: _busy, onPressed: _busy ? null : _save),
          ],
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('Quelle culture ?'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: guides.isLoading && guides.guides.isEmpty
                    ? const Skeleton(height: 90, radius: 20)
                    : Wrap(
                        spacing: Space.s,
                        runSpacing: Space.s,
                        children: [
                          for (final g in guides.guides)
                            PressScale(
                              onTap: () => _selectGuide(g),
                              child: AnimatedContainer(
                                duration: Motion.base,
                                curve: Motion.out,
                                height: Hit.min,
                                padding: const EdgeInsets.symmetric(horizontal: Space.l),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _guide?.id == g.id ? c.accent : c.surface,
                                  borderRadius: BorderRadius.circular(Radii.pill),
                                  border: Border.all(color: _guide?.id == g.id ? c.accent : c.line),
                                ),
                                child: Text(g.name, style: T.caption(color: _guide?.id == g.id ? c.onAccent : c.ink, weight: 700)),
                              ),
                            ),
                        ],
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, 0),
                child: TextField(
                  controller: _type,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) {
                    if (_guide != null && _guide!.name.toLowerCase() != v.trim().toLowerCase()) {
                      setState(() => _guide = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Culture',
                    helperText: _guide == null
                        ? 'Choisissez ci-dessus pour lier la fiche technique, ou saisissez librement.'
                        : 'Fiche technique liée : ${_guide!.name}',
                  ),
                ),
              ),
              const SectionHeader('Parcelle'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Column(
                  children: [
                    TextField(controller: _name, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nom de la parcelle', hintText: 'Ex. : Champ Nord')),
                    const SizedBox(height: Space.m),
                    TextField(
                      controller: _area,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(labelText: 'Surface en hectares', hintText: 'Ex. : 1,5'),
                    ),
                    const SizedBox(height: Space.m),
                    TextField(controller: _location, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Lieu')),
                  ],
                ),
              ),
              const SectionHeader('Calendrier'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Row(
                  children: [
                    Expanded(
                      child: _DateTile(
                        label: 'Semis',
                        date: _planting,
                        onTap: () async {
                          final p = await _pick(_planting ?? DateTime.now());
                          if (p != null) {
                            setState(() {
                              _planting = p;
                              _recomputeHarvest();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: _DateTile(
                        label: 'Récolte prévue',
                        date: _harvest,
                        onTap: () async {
                          final base = _planting ?? DateTime.now();
                          final p = await _pick(_harvest ?? base.add(const Duration(days: 30)), first: base);
                          if (p != null) {
                            setState(() {
                              _harvest = p;
                              _harvestAuto = false;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter + 2, Space.s, Space.gutter, 0),
                child: Text(
                  _guide != null && cycle != null
                      ? (_harvestAuto
                          ? 'Récolte calculée avec le cycle de la fiche (jusqu\'à $cycle jours). Touchez pour la modifier.'
                          : 'Cycle de la fiche : jusqu\'à $cycle jours.')
                      : (_guide != null
                          ? 'Cette fiche ne donne pas de durée de cycle : choisissez vous-même la date de récolte prévue.'
                          : 'Choisissez la date de récolte prévue.'),
                  style: T.caption(color: c.ink2, weight: 500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.all(Space.l),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(color: date == null ? c.line : c.accent, width: date == null ? 1.2 : 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: c.accent),
                const SizedBox(width: 6),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption(color: c.ink2))),
              ],
            ),
            const SizedBox(height: Space.s),
            Text(date == null ? 'Choisir' : Fmt.shortDate(date!), style: T.body(color: date == null ? c.ink2 : c.ink, weight: 700)),
          ],
        ),
      ),
    );
  }
}
