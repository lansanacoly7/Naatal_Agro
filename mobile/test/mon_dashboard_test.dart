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

    // Vérification : les montants réels sont bien affichés
    expect(find.text('+350 000 F'), findsOneWidget); // Solde net
    expect(find.textContaining('500 000 F'), findsWidgets); // Recettes
    expect(find.textContaining('150 000 F'), findsWidgets); // Dépenses
    expect(find.textContaining('Arachide décortiquée'), findsOneWidget);
    expect(find.textContaining('500 Kg'), findsOneWidget);

    // Vérification : les 3 sections et les boutons d'action sont présents
    expect(find.text('Mon exploitation'), findsWidgets);
    expect(find.text('Trésorerie nette'), findsOneWidget);
    expect(find.text('Stock valorisé'), findsOneWidget);
    expect(find.text('Opportunités du marché'), findsOneWidget);
    expect(find.text('Vendre'), findsOneWidget);
    expect(find.text('Noter dépense'), findsOneWidget);
    expect(find.text('Détails'), findsOneWidget);
    expect(find.text('Tout voir'), findsOneWidget);

    // Vérification : aucun faux montant en dur "2 450 000 FCFA"
    expect(find.text('2 450 000 FCFA'), findsNothing);
  });

  testWidgets('MonDashboardScreen affiche un état vide propre quand les données sont vides', (tester) async {
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

    expect(find.textContaining('Votre stock est vide'), findsOneWidget);
    expect(find.text('0 F'), findsWidgets);
    expect(find.text('Trésorerie nette'), findsOneWidget);
    expect(find.text('Stock valorisé'), findsOneWidget);
  });
}
