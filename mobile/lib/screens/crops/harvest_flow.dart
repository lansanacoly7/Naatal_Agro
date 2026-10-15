import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/agriculture/data/agriculture_provider.dart';
import '../../features/agriculture/data/models/crop.dart';
import '../../shared/utils/data_refresh.dart';
import '../../ui/ui.dart';

/// Récolte depuis l'accueil : choisit la culture (ou ouvre directement la saisie
/// s'il n'y en a qu'une), puis demande la quantité.
Future<void> startHarvestFlow(BuildContext context, WidgetRef ref) async {
  List<Crop> crops;
  try {
    crops = await ref.read(cropsProvider.future);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vos cultures n\'ont pas pu être chargées. Réessayez.')),
      );
    }
    return;
  }
  final active = crops.where((c) => c.status != 'harvested').toList();
  if (!context.mounted) return;
  if (active.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aucune culture en cours. Ajoutez une culture avant d\'enregistrer une récolte.')),
    );
    return;
  }
  if (active.length == 1) {
    await showHarvestSheet(context, ref, active.first);
    return;
  }
  final chosen = await showNaatalSheet<Crop>(
    context,
    builder: (ctx) => _CropPicker(crops: active),
  );
  if (chosen != null && context.mounted) {
    await showHarvestSheet(context, ref, chosen);
  }
}

class _CropPicker extends StatelessWidget {
  const _CropPicker({required this.crops});

  final List<Crop> crops;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.m),
          child: Text('Quelle culture récoltez-vous ?', style: T.title(color: c.ink)),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: Space.xl),
            children: [
              GroupedList(
                children: [
                  for (final crop in crops)
                    GroupedRow(
                      leading: IconTile(icon: Icons.eco_rounded, color: c.accent),
                      title: crop.name,
                      subtitle: crop.location.isEmpty ? null : crop.location,
                      chevron: true,
                      onTap: () => Navigator.pop(context, crop),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Feuille « Enregistrer la récolte » d'une culture.
Future<void> showHarvestSheet(BuildContext context, WidgetRef ref, Crop crop) {
  return showNaatalSheet<void>(
    context,
    builder: (ctx) => _HarvestSheet(crop: crop, parentContext: context),
  );
}

class _HarvestSheet extends ConsumerStatefulWidget {
  const _HarvestSheet({required this.crop, required this.parentContext});

  final Crop crop;
  final BuildContext parentContext;

  @override
  ConsumerState<_HarvestSheet> createState() => _HarvestSheetState();
}

class _HarvestSheetState extends ConsumerState<_HarvestSheet> {
  final _quantity = TextEditingController();
  final _notes = TextEditingController();
  final _buttonKey = GlobalKey();
  String _unit = 'kg';
  bool _busy = false;
  String? _error;

  static const _units = ['kg', 'sacs', 'tonnes'];

  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Saisissez une quantité supérieure à zéro.');
      return;
    }
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null ? const Offset(200, 600) : box.localToGlobal(box.size.center(Offset.zero));
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(agricultureRepositoryProvider).harvestCrop(
            widget.crop.id,
            quantity: qty,
            unit: _unit,
            notes: _notes.text.trim(),
          );
      refreshAfterDataChange(ref);
      final queued = result['offline'] == true;
      if (!mounted) return;
      final root = widget.parentContext;
      Navigator.pop(context);
      if (root.mounted) {
        await showSuccessReveal(
          root,
          origin: origin,
          headline: '+${Fmt.decimal(qty)} $_unit',
          title: queued ? 'Récolte en attente d\'envoi' : 'Récolte enregistrée',
          details: [
            widget.crop.name,
            queued ? 'Elle sera envoyée dès le retour du réseau.' : 'Ajoutée automatiquement à votre stock.',
          ],
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'La récolte n\'a pas pu être enregistrée. Vérifiez votre réseau puis réessayez.';
      });
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
          Text('Récolter', style: T.caption(color: c.accent, weight: 700)),
          const SizedBox(height: 2),
          Text(widget.crop.name, style: T.title(color: c.ink)),
          const SizedBox(height: Space.xl),
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: T.number(34, color: c.ink),
            decoration: InputDecoration(
              hintText: '0',
              labelText: 'Quantité récoltée',
              errorText: _error,
            ),
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              for (final u in _units) ...[
                Expanded(
                  child: PressScale(
                    onTap: () => setState(() => _unit = u),
                    child: AnimatedContainer(
                      duration: Motion.base,
                      curve: Motion.out,
                      height: Hit.min,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _unit == u ? c.accent : c.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.m),
                      ),
                      child: Text(u, style: T.body(color: _unit == u ? c.onAccent : c.ink, weight: 700)),
                    ),
                  ),
                ),
                if (u != _units.last) const SizedBox(width: Space.s),
              ],
            ],
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Notes (facultatif)'),
          ),
          const SizedBox(height: Space.xl),
          KeyedSubtree(
            key: _buttonKey,
            child: PillButton(
              label: 'Enregistrer la récolte',
              icon: Icons.check_rounded,
              expand: true,
              loading: _busy,
              onPressed: _busy ? null : _submit,
            ),
          ),
          const SizedBox(height: Space.s),
          Text(
            'La quantité est ajoutée à votre stock. La culture passe en « récoltée ».',
            textAlign: TextAlign.center,
            style: T.caption(color: c.ink2, weight: 500),
          ),
        ],
      ),
    );
  }
}

/// Ouvre la fiche d'une culture depuis n'importe quel écran.
void openCrop(BuildContext context, Crop crop) => context.push('/agriculture/${crop.id}');
