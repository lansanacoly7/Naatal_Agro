import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/agriculture/data/models/crop.dart';
import 'package:nataal_agro/ui/ui.dart';

/// Les images qui existent vraiment dans le dossier des produits.
Set<String> existingImages() => {
      for (final f in Directory('assets/images/products').listSync())
        if (f is File) 'assets/images/products/${f.uri.pathSegments.last}',
    };

void main() {
  test('chaque culture de l\'application trouve une vraie image, avec son nom ou son type', () {
    final existing = existingImages();
    const names = [
      'Poivron', 'Bissap', 'Concombre', 'Laitue', 'Fève verte', 'Canne à sucre', 'Maïs sucré', 'Lime de Tahiti', 'Coton',
      'Sésame', 'Citrouille', 'Ail', 'Goyave', 'Igname', 'Haricot vert', 'Ananas', 'Betterave', 'Navet', 'Orange', 'Citron',
      'Oignon (Niayes)', 'Carotte (Niayes)', 'Mangue (Niayes)', 'Riz irrigué (vallée du fleuve Sénégal)',
      'Tomate industrielle (vallée du fleuve Sénégal)', 'Bissap (oseille de Guinée)', 'Laitue (salade)',
    ];
    final missing = [
      for (final n in names)
        if (!productImageCandidates([n]).any(existing.contains)) n,
    ];
    expect(missing, isEmpty, reason: 'ces cultures n\'ont aucune image : $missing');
  });

  test('un nom personnalisé retrouve l\'image par ses mots', () {
    final existing = existingImages();
    for (final n in ['Poivron rouge', 'Mil 2026', 'Mon bissap de Thiès', 'Tomate cerise']) {
      expect(productImageCandidates([n]).any(existing.contains), isTrue, reason: n);
    }
  });

  test('le type de la culture passe avant son nom', () {
    final crop = Crop(
      id: '1',
      name: 'Parcelle du fond',
      cropType: 'Poivron',
      plantingDate: '2026-10-01',
      expectedHarvestDate: '2027-01-01',
      status: 'active',
      areaSize: 1,
      location: 'Thiès',
    );
    expect(productImageCandidates(crop.imageNames).first, 'assets/images/products/poivron.png');
  });

  testWidgets('sans aucune image, une feuille s\'affiche, jamais le logo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: NaatalTheme.light, home: const Scaffold(body: SizedBox(width: 120, height: 120, child: ProductPhoto(names: ['Culture inconnue xyz'])))),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Image && w.image.toString().contains('naatal_agro_logo')), findsNothing);
  });

  testWidgets('une image qui existe est affichée en plein cadre', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: NaatalTheme.light, home: const Scaffold(body: SizedBox(width: 120, height: 120, child: ProductPhoto(names: ['Poivron rouge', 'Poivron'])))),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final image = tester.widgetList<Image>(find.byType(Image)).last; // les essais ratés restent dans l'arbre, le dernier est celui qui s'affiche
    expect(image.fit, BoxFit.cover);
    expect(image.image.toString(), contains('poivron.png'));
  });
}
