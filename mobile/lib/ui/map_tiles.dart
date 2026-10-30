import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'tokens.dart';

/// Fond de carte clair et lisible, façon plans routiers : routes bien visibles, peu de détails, pas de bruit.
/// Tuiles CARTO « Voyager » (données OpenStreetMap). CARTO exige une clé gratuite : sans elle, ses tuiles portent un filigrane
/// « API KEY REQUIRED ». La clé se donne à la compilation (`--dart-define-from-file=carto.env.json`, fichier hors de Git) ;
/// sans clé (tests, développement), la carte OpenStreetMap standard prend le relais. Conditions CARTO : usage non commercial,
/// 5 millions de tuiles par mois, source à citer (voir [MapCredit]).
class NaatalTileLayer extends StatelessWidget {
  const NaatalTileLayer({super.key});

  static const _cartoKey = String.fromEnvironment('CARTO_KEY');

  /// Source à citer sur la carte (OpenStreetMap, et CARTO quand son fond est utilisé).
  static String get attribution => _cartoKey.isEmpty ? '© OpenStreetMap' : '© OpenStreetMap · © CARTO';

  static String get urlTemplate => _cartoKey.isEmpty
      ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
      : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png?key=$_cartoKey';

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: urlTemplate,
      subdomains: _cartoKey.isEmpty ? const ['a', 'b', 'c'] : const ['a', 'b', 'c', 'd'],
      userAgentPackageName: 'sn.isep.naatal_agro',
      retinaMode: _cartoKey.isEmpty ? false : RetinaMode.isHighDensity(context),
      maxNativeZoom: 19,
      maxZoom: 19,
    );
  }
}

/// Mention de la source des cartes, discrète, en bas à gauche de la carte.
class MapCredit extends StatelessWidget {
  const MapCredit({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      bottom: 6,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(6)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(NaatalTileLayer.attribution, style: TextStyle(fontSize: 10, color: NaatalColors.light.ink2)),
          ),
        ),
      ),
    );
  }
}
