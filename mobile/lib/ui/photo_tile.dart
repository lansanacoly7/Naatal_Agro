import 'package:flutter/material.dart';

import 'press_scale.dart';
import 'tokens.dart';
import 'typography.dart';

/// Grande tuile avec photo plein cadre, légende courte (1 à 3 mots)
/// et dégradé sombre de lisibilité. Respecte le principe « Images d'Abord ».
class PhotoTile extends StatelessWidget {
  const PhotoTile({
    super.key,
    required this.imageAsset,
    required this.label,
    this.onTap,
    this.domainColor,
    this.icon,
    this.badge,
    this.height = 130,
    this.width,
  });

  /// Chemin de l'image (format 4:3 conseillé, dans assets/images/ui/).
  final String imageAsset;

  /// Libellé court (1 à 3 mots max, ex. « Vendre », « Récolter »).
  final String label;

  /// Action au toucher.
  final VoidCallback? onTap;

  /// Couleur d'ancrage du domaine (vert, ocre, terre cuite, bleu, etc.).
  final Color? domainColor;

  /// Icône d'appoint affichée dans la pastille du domaine.
  final IconData? icon;

  /// Mention ou compteur optionnel (ex. « 3 urgents »).
  final String? badge;

  /// Hauteur de la tuile (minimum 100 px pour une bonne lisibilité).
  final double height;

  /// Largeur de la tuile (null = prend la largeur de son conteneur / Grille).
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final accent = domainColor ?? c.accent;

    return PressScale(
      onTap: onTap,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.l),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: c.isDark ? 0.35 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.l),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo plein cadre
              Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: accent.withValues(alpha: 0.15),
                  child: Center(
                    child: Icon(icon ?? Icons.photo_size_select_actual_rounded, size: 36, color: accent),
                  ),
                ),
              ),

              // Dégradé sombre protecteur en bas pour lisibilité parfaite du texte
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.82),
                      ],
                      stops: const [0.35, 0.65, 1.0],
                    ),
                  ),
                ),
              ),

              // Pastille ou icône du domaine en haut à gauche
              if (icon != null)
                Positioned(
                  top: Space.s + 2,
                  left: Space.s + 2,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 16, color: Colors.white),
                  ),
                ),

              // Badge d'alerte / compteur en haut à droite
              if (badge != null && badge!.isNotEmpty)
                Positioned(
                  top: Space.s + 2,
                  right: Space.s + 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Text(
                      badge!,
                      style: T.caption(color: Colors.white, weight: 700),
                    ),
                  ),
                ),

              // Libellé court en bas (1 à 3 mots)
              Positioned(
                left: Space.m,
                right: Space.m,
                bottom: Space.m,
                child: Row(
                  children: [
                    // Petit point d'accent du domaine si pas d'icône
                    if (icon == null) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: Space.s),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: T.body(color: Colors.white, weight: 800).copyWith(
                          letterSpacing: 0.2,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
