import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/inventory/data/inventory_provider.dart';
import '../../features/inventory/data/models/stock_item.dart';
import '../../shared/utils/data_refresh.dart';
import '../../ui/ui.dart';

/// Vente d'un produit du stock : quantité et prix au clavier géant, total et
/// stock restant calculés en direct, puis confirmation avec un grand bouton.
class SellScreen extends ConsumerStatefulWidget {
  const SellScreen({super.key, this.stockId});

  /// Produit du stock présélectionné (sinon l'utilisateur choisit).
  final String? stockId;

  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

enum _Field { quantity, price }

class _SellScreenState extends ConsumerState<SellScreen> {
  String _selectedId = '';
  String _quantity = '';
  String _price = '';
  _Field _field = _Field.quantity;
  bool _busy = false;
  String? _error;
  final _buttonKey = GlobalKey();

  double get _q => double.tryParse(_quantity.replaceAll(',', '.')) ?? 0;
  double get _p => double.tryParse(_price.replaceAll(',', '.')) ?? 0;

  void _digit(String d) {
    setState(() {
      final current = _field == _Field.quantity ? _quantity : _price;
      if (current.length >= 8) return;
      final next = current == '0' ? d : current + d;
      if (_field == _Field.quantity) {
        _quantity = next;
      } else {
        _price = next;
      }
      _error = null;
    });
  }

  void _delete() {
    setState(() {
      final current = _field == _Field.quantity ? _quantity : _price;
      if (current.isEmpty) return;
      final next = current.substring(0, current.length - 1);
      if (_field == _Field.quantity) {
        _quantity = next;
      } else {
        _price = next;
      }
      _error = null;
    });
  }

  Future<void> _confirm(StockItem item) async {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null ? const Offset(200, 700) : box.localToGlobal(box.size.center(Offset.zero));
    final qty = _q;
    final total = qty * _p;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final queued = await ref.read(inventoryNotifierProvider.notifier).recordSale(
            productName: item.name,
            quantity: qty,
            unitPrice: _p,
          );
      refreshAfterDataChange(ref);
      if (!mounted) return;
      setState(() => _busy = false);
      final remaining = item.quantity - qty;
      await showSuccessReveal(
        context,
        origin: origin,
        headline: Fmt.fcfa(total),
        title: queued ? 'Vente en attente d\'envoi' : 'Vente enregistrée',
        details: [
          '${item.name} · ${Fmt.decimal(qty)} ${item.unit}',
          queued
              ? 'Elle sera envoyée dès le retour du réseau.'
              : 'Stock restant : ${Fmt.decimal(remaining)} ${item.unit}',
        ],
      );
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'La vente n\'a pas pu être enregistrée. Vérifiez votre réseau puis réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final stock = ref.watch(inventoryProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Vendre', style: T.title(color: c.ink)),
      ),
      body: stock.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Space.gutter),
          child: Skeleton(height: 220, radius: 24),
        ),
        error: (e, _) => ErrorState(
          message: 'Votre stock n\'a pas pu être chargé.',
          onRetry: () => ref.invalidate(inventoryProvider),
        ),
        data: (items) {
          final sellable = items.where((i) => i.quantity > 0).toList();
          if (sellable.isEmpty) {
            return EmptyState(
              icon: Icons.inventory_2_rounded,
              title: 'Rien à vendre',
              message: 'Votre stock est vide. Enregistrez une récolte ou ajoutez un produit au stock pour pouvoir le vendre.',
              actionLabel: 'Ouvrir le stock',
              onAction: () => context.pushReplacement('/stock'),
            );
          }
          final preferred = widget.stockId ?? _selectedId;
          final item = sellable.firstWhere((i) => i.id == preferred, orElse: () => sellable.first);
          return _body(context, item, sellable);
        },
      ),
    );
  }

  Widget _body(BuildContext context, StockItem item, List<StockItem> all) {
    final c = context.c;
    final q = _q;
    final total = q * _p;
    final over = q > item.quantity;
    final ready = q > 0 && _p > 0 && !over;
    final remaining = item.quantity - q;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.s, Space.gutter, Space.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductSelector(
                  item: item,
                  canChange: all.length > 1,
                  onTap: () async {
                    final chosen = await showNaatalSheet<StockItem>(
                      context,
                      builder: (ctx) => _StockPicker(items: all, selectedId: item.id),
                    );
                    if (chosen != null) {
                      setState(() {
                        _selectedId = chosen.id;
                        _quantity = '';
                        _error = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: Space.m),
                Row(
                  children: [
                    Expanded(
                      child: _FieldTile(
                        label: 'Quantité vendue',
                        value: _quantity.isEmpty ? '0' : _quantity,
                        unit: item.unit,
                        selected: _field == _Field.quantity,
                        isError: over,
                        onTap: () => setState(() => _field = _Field.quantity),
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: _FieldTile(
                        label: 'Prix par ${item.unit.endsWith('s') ? item.unit.substring(0, item.unit.length - 1) : item.unit}',
                        value: _price.isEmpty ? '0' : Fmt.grouped(_p),
                        unit: 'F',
                        selected: _field == _Field.price,
                        onTap: () => setState(() => _field = _Field.price),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.m),
                _TotalCard(total: total, over: over, available: item.quantity, unit: item.unit, remaining: remaining, hasQuantity: q > 0),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.m),
                    child: Text(_error!, style: T.caption(color: c.clay, weight: 700)),
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, MediaQuery.paddingOf(context).bottom + Space.m),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NumericKeypad(onDigit: _digit, onDelete: _delete),
              const SizedBox(height: Space.m),
              KeyedSubtree(
                key: _buttonKey,
                child: PillButton(
                  label: 'Confirmer la vente',
                  icon: Icons.check_rounded,
                  expand: true,
                  loading: _busy,
                  onPressed: ready && !_busy ? () => _confirm(item) : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductSelector extends StatelessWidget {
  const _ProductSelector({required this.item, required this.canChange, required this.onTap});

  final StockItem item;
  final bool canChange;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AppCard(
      onTap: canChange ? onTap : null,
      padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
      child: Row(
        children: [
          IconTile(icon: Icons.inventory_2_rounded, color: c.accent),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(color: c.ink, weight: 700)),
                Text('${Fmt.decimal(item.quantity)} ${item.unit} en stock', style: T.caption(color: c.ink2, weight: 500)),
              ],
            ),
          ),
          if (canChange) Icon(Icons.unfold_more_rounded, color: c.ink2),
        ],
      ),
    );
  }
}

class _StockPicker extends StatelessWidget {
  const _StockPicker({required this.items, required this.selectedId});

  final List<StockItem> items;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.m),
          child: Text('Quel produit vendez-vous ?', style: T.title(color: c.ink)),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: Space.xl),
            children: [
              GroupedList(children: [
                for (final i in items)
                  GroupedRow(
                    leading: IconTile(icon: Icons.inventory_2_rounded, color: c.accent),
                    title: i.name,
                    value: '${Fmt.decimal(i.quantity)} ${i.unit}',
                    trailing: i.id == selectedId ? Icon(Icons.check_circle_rounded, color: c.accent) : null,
                    onTap: () => Navigator.pop(context, i),
                  ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.selected,
    required this.onTap,
    this.isError = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool selected;
  final bool isError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final border = isError ? c.clay : (selected ? c.accent : c.line);
    return PressScale(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.out,
        padding: const EdgeInsets.symmetric(horizontal: Space.l, vertical: Space.m),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(color: border, width: selected || isError ? 2 : 1.2),
          boxShadow: selected
              ? [BoxShadow(color: c.accent.withValues(alpha: 0.16), blurRadius: 0, spreadRadius: 4)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption(color: c.ink2, weight: 600)),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: T.number(28, color: isError ? c.clay : c.ink)),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(unit, style: T.caption(color: c.ink2, weight: 700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.total,
    required this.over,
    required this.available,
    required this.unit,
    required this.remaining,
    required this.hasQuantity,
  });

  final double total;
  final bool over;
  final double available;
  final String unit;
  final double remaining;
  final bool hasQuantity;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colors = over
        ? [const Color(0xFF7A2E19), const Color(0xFFA4472B)]
        : [c.heroTop, c.heroBottom];
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.out,
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xl),
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(over ? 'Stock insuffisant' : 'Total de la vente', style: T.caption(color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedNumber(
                          value: total,
                          duration: Motion.base,
                          style: T.number(38, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text('FCFA', style: T.caption(color: Colors.white.withValues(alpha: 0.85), weight: 700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(over ? 'Vous avez' : 'Il restera', style: T.caption(color: Colors.white.withValues(alpha: 0.85))),
              Text(
                over ? '${Fmt.decimal(available)} $unit' : '${Fmt.decimal(hasQuantity ? remaining : available)} $unit',
                style: T.figure(color: Colors.white, weight: 800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
