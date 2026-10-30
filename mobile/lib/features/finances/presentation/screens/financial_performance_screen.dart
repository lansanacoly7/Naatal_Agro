import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/finances_provider.dart';
import '../../data/models/financial_summary.dart';
import '../../../../shared/utils/data_refresh.dart';

import '../../../../ui/ui.dart';
class FinancialPerformanceScreen extends ConsumerWidget {
  const FinancialPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(financialSummaryProvider);
    final transactionsState = ref.watch(transactionsNotifierProvider);

    return Scaffold(
      backgroundColor: context.c.bg,
      appBar: AppBar(
        title: Text('Performances Financières', style: TextStyle(color: context.c.ink, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.c.ink),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financialSummaryProvider);
          ref.invalidate(transactionsNotifierProvider);
        },
        color: context.c.accent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              summaryAsync.when(
                data: (summary) => _buildSummaryCards(context, summary),
                loading: () => Center(child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: context.c.accent),
                )),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 36),
                        const SizedBox(height: 8),
                        Text('Erreur de chargement du résumé : $e', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(financialSummaryProvider),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text('Historique des Transactions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.c.ink)),
              const SizedBox(height: 16),
              transactionsState.when(
                data: (transactions) {
                  if (transactions.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: context.c.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.c.line),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune transaction enregistrée',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.c.ink),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ajoutez vos revenus ou dépenses avec le bouton + ci-dessous.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.c.ink2, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: transactions.map((t) => _buildTransactionCard(context, t)).toList(),
                  );
                },
                loading: () => Center(child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: context.c.accent),
                )),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 36),
                        const SizedBox(height: 8),
                        Text('Erreur transactions : $e', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(transactionsNotifierProvider),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionDialog(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, FinancialSummary summary) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Column(
            children: [
              const Text('SOLDE ACTUEL', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${summary.balance.toStringAsFixed(0)} CFA', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_downward, color: Colors.green),
                    const SizedBox(height: 8),
                    Text('REVENUS', style: TextStyle(color: context.c.ink2, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('${summary.totalRevenue.toStringAsFixed(0)} CFA', style: TextStyle(color: context.c.ink, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: context.c.surface, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.arrow_upward, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('DÉPENSES', style: TextStyle(color: context.c.ink2, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text('${summary.totalExpenses.toStringAsFixed(0)} CFA', style: TextStyle(color: context.c.ink, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildTransactionCard(BuildContext context, TransactionItem t) {
    final isIncome = t.type == 'income';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.c.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isIncome ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(isIncome ? Icons.add : Icons.remove, color: isIncome ? Colors.green : Colors.red, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(t.date, style: TextStyle(color: context.c.ink2, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${t.amount.toStringAsFixed(0)} CFA',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isIncome ? Colors.green : Colors.red),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, WidgetRef ref) {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String type = 'income';
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isIncome = type == 'income';
            final accent = isIncome ? context.c.accent : AppColors.error;

            Widget typeButton(String value, String label, IconData icon) {
              final selected = type == value;
              final color = value == 'income' ? context.c.accent : AppColors.error;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setSheetState(() => type = value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? color : context.c.bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 20, color: selected ? Colors.white : context.c.ink2),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : context.c.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Nouvelle transaction',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enregistrez une recette ou une dépense.',
                      style: TextStyle(color: context.c.ink2),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        typeButton('income', 'Revenu', Icons.south_west_rounded),
                        const SizedBox(width: 10),
                        typeButton('expense', 'Dépense', Icons.north_east_rounded),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: accent),
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: 'CFA',
                        errorText: errorText,
                        fillColor: context.c.bg,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Description (ex : vente de tomates)',
                        prefixIcon: Icon(Icons.notes_rounded),
                        fillColor: context.c.bg,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: accent),
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;
                        if (amount <= 0 || descController.text.trim().isEmpty) {
                          setSheetState(() => errorText = 'Saisissez un montant et une description');
                          return;
                        }
                        final newItem = TransactionItem(
                          id: '',
                          type: type,
                          amount: amount,
                          date: DateTime.now().toIso8601String().split('T')[0],
                          description: descController.text.trim(),
                        );
                        try {
                          await ref.read(transactionsNotifierProvider.notifier).addTransaction(newItem);
                        } catch (_) {
                          setSheetState(() => errorText = 'Enregistrement impossible. Vérifiez votre connexion.');
                          return;
                        }
                        // Résumé, tableau de bord et profil sont rechargés avec la nouvelle transaction
                        refreshAfterDataChange(ref);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      child: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
