import 'package:flutter/material.dart';

import 'tokens.dart';

/// Variantes d'un même produit qui partagent l'image du produit de base (« Riz irrigué » → riz, etc.).
const _imageAliases = {
  'riz_irrigue': 'riz',
  'tomate_industrielle': 'tomate',
  'laitue_salade': 'laitue',
  'bissap_oseille_de_guinee': 'bissap',
};

/// Chemin de l'image de produit : `assets/images/products/{slug}.png`.
/// La précision entre parenthèses est ignorée (« Oignon (Niayes) » → oignon) et les variantes connues reprennent l'image du produit de base.
String productImageForName(String name) {
  final clean = name
      .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c')
      .trim();
  final raw = clean.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  final slug = _imageAliases[raw] ?? raw;
  return 'assets/images/products/$slug.png';
}

/// Images possibles pour une culture, de la plus précise à la plus large : le nom entier, puis chacun de ses mots
/// (« Poivron rouge » → poivron_rouge, puis poivron ; « Mil 2026 » → mil).
List<String> productImageCandidates(Iterable<String> names) {
  final out = <String>[];
  void add(String path) {
    if (!out.contains(path)) out.add(path);
  }

  for (final name in names) {
    if (name.trim().isEmpty) continue;
    add(productImageForName(name));
    for (final word in name.split(RegExp(r'[\s(),/-]+'))) {
      if (word.length >= 3) add(productImageForName(word));
    }
  }
  return out;
}

/// Photo d'un produit ou d'une culture, en plein cadre. Essaie chaque image possible tour à tour ; si aucune n'existe encore,
/// affiche une feuille sur fond doux (jamais le logo de l'application).
class ProductPhoto extends StatelessWidget {
  const ProductPhoto({super.key, required this.names, this.fit = BoxFit.cover, this.placeholder});

  /// Noms à essayer, dans l'ordre (type de culture, nom donné par la personne…).
  final List<String> names;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final candidates = productImageCandidates(names);
    Widget fallback() =>
        placeholder ??
        Container(
          color: context.c.surfaceAlt,
          alignment: Alignment.center,
          child: Icon(Icons.eco_rounded, color: context.c.accent, size: 44),
        );

    Widget attempt(int i) {
      if (i >= candidates.length) return fallback();
      return Image.asset(
        candidates[i],
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => attempt(i + 1),
      );
    }

    return attempt(0);
  }
}
