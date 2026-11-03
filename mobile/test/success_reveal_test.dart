import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/ui/success_reveal.dart';

void main() {
  testWidgets('showSuccessReveal displays headline, title, details and done button',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showSuccessReveal(
                    context,
                    origin: const Offset(200, 400),
                    headline: '75 000 FCFA',
                    title: 'Vente enregistrée',
                    details: [
                      'Parcelle Arachide · 50 kg',
                      'Stock restant : 50 kg',
                    ],
                    doneLabel: 'Terminer',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    // Tap to open success reveal
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    // Verify elements are displayed
    expect(find.text('75 000 FCFA'), findsOneWidget);
    expect(find.text('Vente enregistrée'), findsOneWidget);
    expect(find.text('Parcelle Arachide · 50 kg'), findsOneWidget);
    expect(find.text('Stock restant : 50 kg'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);

    // Tap Terminer to dismiss
    await tester.tap(find.text('Terminer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Success screen dismissed, back to home
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('75 000 FCFA'), findsNothing);
  });
}
