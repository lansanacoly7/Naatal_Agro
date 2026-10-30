import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/core/session/session_root.dart';

/// Données d'un compte gardées en mémoire (cultures, stock, discussion…) : représentées ici par un compteur.
final _memoryOfAccount = StateProvider<List<String>>((ref) => <String>[]);

void main() {
  testWidgets('une déconnexion vide la mémoire : le compte suivant ne voit rien du précédent', (tester) async {
    await tester.pumpWidget(
      SessionRoot(
        overrides: const [],
        child: Consumer(
          builder: (context, ref, _) {
            final items = ref.watch(_memoryOfAccount);
            return Directionality(
              textDirection: TextDirection.ltr,
              child: GestureDetector(
                onTap: () => ref.read(_memoryOfAccount.notifier).state = [...items, 'Yèbè'],
                child: Text(items.isEmpty ? 'vide' : items.join(',')),
              ),
            );
          },
        ),
      ),
    );
    expect(find.text('vide'), findsOneWidget);

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();
    expect(find.text('Yèbè'), findsOneWidget); // le premier compte a une culture

    SessionReset.bump(); // déconnexion
    await tester.pump();
    expect(find.text('vide'), findsOneWidget); // le second compte repart de zéro
    expect(find.text('Yèbè'), findsNothing);
  });
}
