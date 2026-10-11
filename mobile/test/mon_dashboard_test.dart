import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/dashboard/presentation/screens/mon_dashboard_screen.dart';
import 'package:nataal_agro/features/finances/data/finances_provider.dart';
import 'package:nataal_agro/features/finances/data/models/financial_summary.dart';
import 'package:nataal_agro/features/inventory/data/inventory_provider.dart';
import 'package:nataal_agro/features/inventory/data/models/stock_item.dart';

void main() {
  testWidgets('MonDashboardScreen affiche les vraies données de finances et de stock', (tester) async {
    final fakeSummary = FinancialSummary(
      totalRevenue: 500000.0,
      totalExpenses: 150000.0,
      balance: 350000.0,
    );

    final fakeStock = [
      StockItem(
        id: 's1',
        name: 'Arachide décortiquée',
        quantity: 500.0,
        unit: 'Kg',
        alertStatus: false,
        updatedAt: '2026-10-10',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financialSummaryProvider.overrideWith((ref) async => fakeSummary),
          inventoryProvider.overrideWith((ref) async => fakeStock),
        ],
        child: const MaterialApp(
          home: MonDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Vérification : les montants du mock sont bien affichés
    expect(find.text('500 000 FCFA'), findsNWidgets(2)); // totalRevenue (card principale + carte revenu)
    expect(find.text('Solde net : 350 000 FCFA'), findsOneWidget);
    expect(find.text('150 000 FCFA'), findsOneWidget); // dépenses
    expect(find.text('Arachide décortiquée'), findsOneWidget);
    expect(find.text('500 Kg'), findsOneWidget);

    // Vérification : l'ancien faux montant en dur "2 450 000 FCFA" n'existe plus
    expect(find.text('2 450 000 FCFA'), findsNothing);
  });

  testWidgets('MonDashboardScreen affiche un état vide propre quand le stock est vide', (tester) async {
    final fakeSummary = FinancialSummary(
      totalRevenue: 0.0,
      totalExpenses: 0.0,
      balance: 0.0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financialSummaryProvider.overrideWith((ref) async => fakeSummary),
          inventoryProvider.overrideWith((ref) async => <StockItem>[]),
        ],
        child: const MaterialApp(
          home: MonDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Aucun produit en stock actuellement'), findsOneWidget);
    expect(find.text('Ajouter un stock'), findsOneWidget);
  });
}
