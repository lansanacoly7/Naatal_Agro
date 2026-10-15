import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/inventory/data/inventory_provider.dart';
import '../../features/inventory/data/models/stock_item.dart';
import '../../shared/utils/data_refresh.dart';
import '../../ui/ui.dart';

/// Stock : ce que l'utilisateur possède, avec le conseil de conservation s'il existe.
class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = ref.watch(inventoryNotifierProvider);
    final c = context.c;

    return LargeTitleScaffold(
      title: 'Stock',
      reserveNav: false,
      onRefresh: () => ref.read(inventoryNotifierProvider.notifier).fetchInventory(),
      bottom: Container(
        padding: EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, MediaQuery.paddingOf(context).bottom + Space.m),
        decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
        child: PillButton(
          label: 'Ajouter un produit',
          icon: Icons.add_rounded,
          expand: true,
          onPressed: () => _showAddSheet(context, ref),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: stock.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(Space.gutter),
              child: Skeleton(height: 180, radius: 20),
            ),
            error: (e, _) => ErrorState(
              message: 'Votre stock n\'a pas pu être chargé.',
              onRetry: () => ref.read(inventoryNotifierProvider.notifier).fetchInventory(),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.inventory_2_rounded,
                  title: 'Votre stock est vide',
                  message: 'Une récolte enregistrée ajoute automatiquement son stock. Vous pouvez aussi ajouter un produit à la main.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GroupedList(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Reveal(index: i, child: _StockRow(item: items[i])),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter + 4, Space.m, Space.gutter, 0),
                    child: Text(
                      'Touchez un produit pour le vendre, corriger sa quantité ou le retirer.',
                      style: T.caption(color: c.ink2, weight: 500),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showNaatalSheet<void>(context, builder: (ctx) => _AddStockSheet(parent: ref));
  }
}

class _StockRow extends ConsumerWidget {
  const _StockRow({required this.item});

  final StockItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return GroupedRow(
      leading: IconTile(icon: Icons.inventory_2_rounded, color: item.alertStatus ? c.clay : c.accent),
      title: item.name,
      subtitle: item.alertStatus ? 'Stock bas' : null,
      value: '${Fmt.decimal(item.quantity)} ${item.unit}',
      valueColor: item.alertStatus ? c.clay : c.ink,
      chevron: true,
      onTap: () => showNaatalSheet<void>(context, builder: (ctx) => _StockActions(item: item)),
    );
  }
}

class _StockActions extends ConsumerWidget {
  const _StockActions({required this.item});

  final StockItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(item.name, style: T.title(color: c.ink)),
          const SizedBox(height: 2),
          Text('${Fmt.decimal(item.quantity)} ${item.unit} en stock', style: T.body(color: c.ink2)),
          if ((item.aiStorageAdvice ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: Space.l),
            Container(
              padding: const EdgeInsets.all(Space.l),
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: c.isDark ? 0.16 : 0.09),
                borderRadius: BorderRadius.circular(Radii.m),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 18, color: c.accent),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Conseil de conservation (IA)', style: T.caption(color: c.accent, weight: 700)),
                        const SizedBox(height: 2),
                        Text(item.aiStorageAdvice!.trim(), style: T.caption(color: c.ink, weight: 500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.xl),
          PillButton(
            label: 'Vendre',
            icon: Icons.sell_rounded,
            expand: true,
            onPressed: item.quantity > 0
                ? () {
                    Navigator.pop(context);
                    context.push('/sell', extra: {'stockId': item.id});
                  }
                : null,
          ),
          const SizedBox(height: Space.s),
          PillButton(
            label: 'Corriger la quantité',
            icon: Icons.edit_rounded,
            variant: PillVariant.secondary,
            expand: true,
            onPressed: () {
              Navigator.pop(context);
              showNaatalSheet<void>(context, builder: (ctx) => _EditQuantitySheet(item: item));
            },
          ),
          const SizedBox(height: Space.s),
          PillButton(
            label: 'Retirer du stock',
            icon: Icons.delete_outline_rounded,
            variant: PillVariant.danger,
            expand: true,
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Retirer ${item.name} ?',
                message: 'Ce produit disparaît de votre stock. Vos ventes déjà enregistrées ne changent pas.',
                confirmLabel: 'Retirer',
                destructive: true,
              );
              if (!ok || !context.mounted) return;
              try {
                await ref.read(inventoryNotifierProvider.notifier).deleteStock(item.id);
                refreshAfterDataChange(ref);
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Suppression impossible. Vérifiez votre réseau.')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _EditQuantitySheet extends ConsumerStatefulWidget {
  const _EditQuantitySheet({required this.item});

  final StockItem item;

  @override
  ConsumerState<_EditQuantitySheet> createState() => _EditQuantitySheetState();
}

class _EditQuantitySheetState extends ConsumerState<_EditQuantitySheet> {
  late final TextEditingController _quantity =
      TextEditingController(text: Fmt.decimal(widget.item.quantity).replaceAll(' ', ''));
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final q = double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    if (q == null || q < 0) {
      setState(() => _error = 'Saisissez une quantité valide.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(inventoryNotifierProvider.notifier).updateQuantity(widget.item.id, q);
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
          Text('Corriger la quantité', style: T.title(color: c.ink)),
          const SizedBox(height: Space.xs),
          Text(widget.item.name, style: T.body(color: c.ink2)),
          const SizedBox(height: Space.xl),
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: T.number(32, color: c.ink),
            decoration: InputDecoration(labelText: 'Quantité en ${widget.item.unit}', errorText: _error),
          ),
          const SizedBox(height: Space.xl),
          PillButton(label: 'Enregistrer', expand: true, loading: _busy, onPressed: _busy ? null : _save),
        ],
      ),
    );
  }
}

class _AddStockSheet extends ConsumerStatefulWidget {
  const _AddStockSheet({required this.parent});

  final WidgetRef parent;

  @override
  ConsumerState<_AddStockSheet> createState() => _AddStockSheetState();
}

class _AddStockSheetState extends ConsumerState<_AddStockSheet> {
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  String _unit = 'kg';
  bool _busy = false;
  String? _error;

  static const _units = ['kg', 'sacs', 'tonnes'];

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final q = double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || q == null || q <= 0) {
      setState(() => _error = 'Indiquez le produit et une quantité supérieure à zéro.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(inventoryNotifierProvider.notifier).addStock(
            StockItem(id: '', name: name, quantity: q, unit: _unit, alertStatus: false, updatedAt: ''),
          );
      refreshAfterDataChange(ref);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Ajout impossible. Vérifiez votre réseau.';
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
          Text('Ajouter au stock', style: T.title(color: c.ink)),
          const SizedBox(height: Space.xl),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Produit', hintText: 'Ex. : Oignon'),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(labelText: 'Quantité', errorText: _error),
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
          const SizedBox(height: Space.xl),
          PillButton(label: 'Ajouter', icon: Icons.add_rounded, expand: true, loading: _busy, onPressed: _busy ? null : _save),
        ],
      ),
    );
  }
}
