import 'package:flutter/material.dart';

/// Logo Naatal Agro, posé tel quel (sans fond ni cadre). On le met en valeur par sa taille.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 150});

  /// Hauteur du logo ; l'image est carrée (500 × 500).
  final double height;

  static const asset = 'assets/images/naatal_agro_logo-removebg-preview.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      height: height,
      width: height, // la place est réservée avant même que l'image soit décodée
      fit: BoxFit.contain,
      semanticLabel: 'Naatal Agro',
      errorBuilder: (context, error, stackTrace) => SizedBox(height: height, width: height),
    );
  }
}
