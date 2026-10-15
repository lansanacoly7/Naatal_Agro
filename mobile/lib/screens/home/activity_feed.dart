import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/agriculture/data/agriculture_provider.dart';
import '../../features/finances/data/finances_provider.dart';

enum ActivityKind { harvest, income, expense }

/// Un événement du journal d'exploitation : récolte, revenu ou dépense.
class ActivityEvent {
  const ActivityEvent({
    required this.kind,
    required this.title,
    required this.date,
    this.amount,
    this.quantity,
    this.unit,
  });

  final ActivityKind kind;
  final String title;
  final DateTime date;

  /// Montant en FCFA (revenu ou dépense).
  final double? amount;

  /// Quantité récoltée.
  final double? quantity;
  final String? unit;
}

/// Journal d'exploitation : les vraies récoltes et transactions, les plus récentes d'abord.
/// Aucune donnée n'est inventée : liste vide tant que rien n'est enregistré.
final activityFeedProvider = Provider.autoDispose<AsyncValue<List<ActivityEvent>>>((ref) {
  final transactions = ref.watch(transactionsNotifierProvider);
  final crops = ref.watch(cropsProvider);

  if (transactions.isLoading && crops.isLoading) return const AsyncValue.loading();
  final error = transactions.error ?? crops.error;
  if (error != null && !transactions.hasValue && !crops.hasValue) {
    return AsyncValue.error(error, StackTrace.current);
  }

  final events = <ActivityEvent>[];
  for (final t in transactions.valueOrNull ?? const []) {
    final date = DateTime.tryParse(t.date);
    if (date == null) continue;
    events.add(ActivityEvent(
      kind: t.type == 'income' ? ActivityKind.income : ActivityKind.expense,
      title: t.description,
      date: date,
      amount: t.amount,
    ));
  }
  for (final crop in crops.valueOrNull ?? const []) {
    for (final h in crop.harvests) {
      final date = h.parsedDate;
      if (date == null) continue;
      events.add(ActivityEvent(
        kind: ActivityKind.harvest,
        title: 'Récolte · ${crop.name}',
        date: date,
        quantity: h.quantity,
        unit: h.unit,
      ));
    }
  }
  events.sort((a, b) => b.date.compareTo(a.date));
  return AsyncValue.data(events);
});
