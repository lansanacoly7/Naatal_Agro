import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/finances/data/finances_provider.dart';
import '../../features/finances/data/models/financial_summary.dart';
import '../../shared/utils/data_refresh.dart';
import '../../ui/ui.dart';
import '../markets/markets_data.dart';

/// Finances : solde, revenus, dépenses et historique des opérations.
/// Chaque vente enregistrée apparaît ici comme un revenu.
class FinancesScreen extends ConsumerStatefulWidget {
  const FinancesScreen({super.key, this.openAdd});

  /// `income` ou `expense` : ouvre directement la saisie d'une opération.
  final String? openAdd;

  @override
  ConsumerState<FinancesScreen> createState() => _FinancesScreenState();
}

enum _Filter { all, income, expense }

class _FinancesScreenState extends ConsumerState<FinancesScreen> {
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    if (widget.openAdd != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAdd(widget.openAdd == 'income' ? 'income' : 'expense');
      });
    }
  }

  void _openAdd(String type) {
    showNaatalSheet<void>(context, builder: (ctx) => _AddTransactionSheet(initialType: type));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final summary = ref.watch(financialSummaryProvider);
    final txs = ref.watch(transactionsNotifierProvider);

    return LargeTitleScaffold(
      title: 'Finances',
      reserveNav: false,
      onRefresh: () async {
        ref.invalidate(financialSummaryProvider);
        await ref.read(transactionsNotifierProvider.notifier).fetchTransactions();
      },
      bottom: Container(
        padding: EdgeInsets.fromLTRB(Space.gutter, Space.m, Space.gutter, MediaQuery.paddingOf(context).bottom + Space.m),
        decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.line))),
        child: Row(
          children: [
            Expanded(
              child: PillButton(
                label: 'Revenu',
                icon: Icons.south_west_rounded,
                variant: PillVariant.secondary,
                expand: true,
                onPressed: () => _openAdd('income'),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: PillButton(
                label: 'Dépense',
                icon: Icons.north_east_rounded,
                expand: true,
                onPressed: () => _openAdd('expense'),
              ),
            ),
          ],
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: summary.when(
                  loading: () => const Skeleton(height: 168, radius: 28),
                  error: (e, _) => ErrorState(
                    compact: true,
                    message: 'Le bilan n\'a pas pu être chargé.',
                    onRetry: () => ref.invalidate(financialSummaryProvider),
                  ),
                  data: (s) => _BalanceHero(summary: s),
                ),
              ),
              const SizedBox(height: Space.l),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: _FilterBar(value: _filter, onChanged: (f) => setState(() => _filter = f)),
              ),
              const SizedBox(height: Space.m),
              txs.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Skeleton(height: 180, radius: 20),
                ),
                error: (e, _) => ErrorState(
                  message: 'L\'historique n\'a pas pu être chargé.',
                  onRetry: () => ref.read(transactionsNotifierProvider.notifier).fetchTransactions(),
                ),
                data: (list) {
                  final shown = list.where((t) {
                    return switch (_filter) {
                      _Filter.all => true,
                      _Filter.income => t.type == 'income',
                      _Filter.expense => t.type == 'expense',
                    };
                  }).toList();
                  if (shown.isEmpty) {
                    return EmptyState(
                      imageAsset: 'assets/images/ui/ui_depenses.jpg',
                      icon: Icons.receipt_long_rounded,
                      title: list.isEmpty ? 'Aucune opération' : 'Rien dans cette catégorie',
                      message: list.isEmpty
                          ? 'Vos ventes apparaissent ici automatiquement. Ajoutez aussi vos dépenses et autres revenus.'
                          : 'Changez de filtre pour voir les autres opérations.',
                    );
                  }
                  return GroupedList(
                    children: [
                      for (var i = 0; i < shown.length; i++)
                        Reveal(index: i, child: _TransactionRow(item: shown[i])),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.summary});

  final FinancialSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AuroraBackground(
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Solde depuis le début', style: T.caption(color: Colors.white.withValues(alpha: 0.85))),
            const SizedBox(height: Space.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedNumber(value: summary.balance, style: T.number(46, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text('FCFA', style: T.caption(color: Colors.white.withValues(alpha: 0.85), weight: 700)),
                ),
              ],
            ),
            const SizedBox(height: Space.l),
            Row(
              children: [
                Expanded(child: _HeroFlow(label: 'Revenus', value: summary.totalRevenue, icon: Icons.south_west_rounded, color: c.mint)),
                const SizedBox(width: Space.m),
                Expanded(child: _HeroFlow(label: 'Dépenses', value: summary.totalExpenses, icon: Icons.north_east_rounded, color: const Color(0xFFF4A38A))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroFlow extends StatelessWidget {
  const _HeroFlow({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final double value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Glass(
      style: GlassStyle.onHero,
      radius: Radii.m,
      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.m),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: Space.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: T.caption(color: Colors.white.withValues(alpha: 0.85), weight: 500)),
                Text(Fmt.grouped(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.figure(color: Colors.white, weight: 800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final _Filter value;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const labels = {_Filter.all: 'Tout', _Filter.income: 'Revenus', _Filter.expense: 'Dépenses'};
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.m)),
      child: Row(
        children: [
          for (final f in _Filter.values)
            Expanded(
              child: PressScale(
                onTap: () => onChanged(f),
                scale: 0.98,
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.out,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == f ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.s),
                    boxShadow: value == f ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))] : null,
                  ),
                  child: Text(labels[f]!, style: T.caption(color: value == f ? c.ink : c.ink2, weight: 700)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.item});

  final TransactionItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final income = item.type == 'income';
    final date = DateTime.tryParse(item.date);

    final descLower = item.description.toLowerCase();
    String? matchedCrop;
    for (final crop in const [
      'oignon', 'arachide', 'tomate', 'piment', 'mais', 'maïs', 'mil', 'manioc', 'riz', 'chou', 'carotte'
    ]) {
      if (descLower.contains(crop)) {
        matchedCrop = crop == 'maïs' ? 'mais' : crop;
        break;
      }
    }

    Widget leading;
    if (matchedCrop != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(Radii.m),
        child: Container(
          width: 44,
          height: 44,
          color: (income ? c.accent : c.clay).withValues(alpha: c.isDark ? 0.2 : 0.1),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              productImageForName(matchedCrop),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => IconTile(
                icon: income ? Icons.south_west_rounded : Icons.north_east_rounded,
                color: income ? c.accent : c.clay,
              ),
            ),
          ),
        ),
      );
    } else {
      leading = IconTile(
        icon: income ? Icons.south_west_rounded : Icons.north_east_rounded,
        color: income ? c.accent : c.clay,
      );
    }

    return GroupedRow(
      minHeight: 60,
      leading: leading,
      title: item.description,
      subtitle: date == null ? null : Fmt.shortDate(date),
      value: '${income ? '+' : '−'}${Fmt.grouped(item.amount)} F',
      valueColor: income ? c.accent : c.clay,
    );
  }
}

class _AddTransactionSheet extends ConsumerStatefulWidget {
  const _AddTransactionSheet({required this.initialType});

  final String initialType;

  @override
  ConsumerState<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  late String _type = widget.initialType;
  bool _busy = false;
  String? _error;

  static const _quickIncomes = ['Vente directe', 'Avance récolte', 'Subvention', 'Aide de campagne'];
  static const _quickExpenses = ['Engrais NPK', 'Semences', 'Carburant / Transport', 'Main d\'œuvre', 'Traitement'];

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.').replaceAll(' ', ''));
    if (amount == null || amount <= 0 || _description.text.trim().isEmpty) {
      setState(() => _error = 'Saisissez un montant et une description.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(transactionsNotifierProvider.notifier).addTransaction(
            TransactionItem(
              id: '',
              type: _type,
              amount: amount,
              date: DateTime.now().toIso8601String().split('T').first,
              description: _description.text.trim(),
            ),
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
    final income = _type == 'income';
    final accent = income ? c.accent : c.clay;
    final suggestions = income ? _quickIncomes : _quickExpenses;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nouvelle opération', style: T.title(color: c.ink)),
          const SizedBox(height: Space.l),
          Row(
            children: [
              for (final t in const ['income', 'expense']) ...[
                Expanded(
                  child: PressScale(
                    onTap: () => setState(() => _type = t),
                    child: AnimatedContainer(
                      duration: Motion.base,
                      curve: Motion.out,
                      height: Hit.min,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _type == t ? (t == 'income' ? c.accent : c.clay) : c.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.m),
                      ),
                      child: Text(
                        t == 'income' ? 'Revenu' : 'Dépense',
                        style: T.body(color: _type == t ? (t == 'income' ? c.onAccent : Colors.white) : c.ink, weight: 700),
                      ),
                    ),
                  ),
                ),
                if (t == 'income') const SizedBox(width: Space.s),
              ],
            ],
          ),
          const SizedBox(height: Space.l),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]'))],
            style: T.number(32, color: accent),
            decoration: const InputDecoration(labelText: 'Montant en FCFA', hintText: '0'),
          ),
          const SizedBox(height: Space.m),
          Text('Suggestions rapides', style: T.caption(color: c.ink2, weight: 700)),
          const SizedBox(height: Space.s),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in suggestions) ...[
                  PressScale(
                    onTap: () {
                      setState(() {
                        _description.text = s;
                        _error = null;
                      });
                    },
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: Space.s),
                      decoration: BoxDecoration(
                        color: _description.text == s ? accent.withValues(alpha: c.isDark ? 0.25 : 0.12) : c.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.m),
                        border: Border.all(color: _description.text == s ? accent : Colors.transparent, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        s,
                        style: T.caption(
                          color: _description.text == s ? accent : c.ink,
                          weight: _description.text == s ? 800 : 600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.s),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.m),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: income ? 'Ex. : aide, vente directe' : 'Ex. : engrais, semences',
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
