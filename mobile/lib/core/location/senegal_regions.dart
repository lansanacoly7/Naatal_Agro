/// Les 14 régions du Sénégal : chef-lieu (position approximative) et zones agricoles qui les recouvrent.
///
/// Sert à deviner la région de l'agriculteur à partir de sa position, et à retrouver les cultures dont les fiches
/// techniques citent sa zone. Aucune donnée n'est inventée : les zones viennent du texte sourcé des fiches.
class SenegalRegion {
  const SenegalRegion(this.name, this.lat, this.lon, this.zoneKeywords);

  final String name;

  /// Position du chef-lieu (degrés).
  final double lat;
  final double lon;

  /// Mots (sans accent, en minuscules) qui désignent cette région ou une zone agricole qui la recouvre.
  final List<String> zoneKeywords;
}

abstract final class SenegalRegions {
  static const all = <SenegalRegion>[
    SenegalRegion('Dakar', 14.7167, -17.4677, ['dakar', 'niayes']),
    SenegalRegion('Thiès', 14.7910, -16.9359, ['thies', 'niayes', 'bassin arachidier']),
    SenegalRegion('Louga', 15.6140, -16.2240, ['louga', 'niayes', 'bassin arachidier']),
    SenegalRegion('Saint-Louis', 16.0179, -16.4896, ['saint-louis', 'vallee du fleuve']),
    SenegalRegion('Matam', 15.6559, -13.2554, ['matam', 'vallee du fleuve']),
    SenegalRegion('Diourbel', 14.6550, -16.2310, ['diourbel', 'bassin arachidier']),
    SenegalRegion('Fatick', 14.3390, -16.4110, ['fatick', 'sine-saloum', 'bassin arachidier']),
    SenegalRegion('Kaolack', 14.1510, -16.0730, ['kaolack', 'sine-saloum', 'bassin arachidier']),
    SenegalRegion('Kaffrine', 14.1050, -15.5500, ['kaffrine', 'sine-saloum', 'bassin arachidier']),
    SenegalRegion('Tambacounda', 13.7708, -13.6673, ['tambacounda', 'senegal-oriental']),
    SenegalRegion('Kédougou', 12.5605, -12.1747, ['kedougou', 'senegal-oriental']),
    SenegalRegion('Kolda', 12.8830, -14.9500, ['kolda', 'casamance']),
    SenegalRegion('Sédhiou', 12.7080, -15.5570, ['sedhiou', 'casamance']),
    SenegalRegion('Ziguinchor', 12.5833, -16.2719, ['ziguinchor', 'casamance']),
  ];

  /// Minuscules et sans accents, pour comparer « Thiès », « THIES » et « Thies Region ».
  static String normalize(String text) {
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyyo';
    final lower = text.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      buffer.write(index >= 0 ? to[index] : char);
    }
    return buffer.toString();
  }

  /// Région dont le nom apparaît dans [text] (ex. « Dakar Region », « Thiès »), sinon `null`.
  static SenegalRegion? fromName(String text) {
    final cleaned = normalize(text);
    for (final region in all) {
      if (cleaned.contains(normalize(region.name))) return region;
    }
    return null;
  }

  /// Chef-lieu le plus proche d'une position. Approximatif près des frontières entre régions.
  static SenegalRegion nearest(double lat, double lon) {
    SenegalRegion best = all.first;
    var bestDistance = double.infinity;
    for (final region in all) {
      final dLat = region.lat - lat;
      final dLon = (region.lon - lon) * 0.96; // un degré de longitude est un peu plus court qu'un de latitude à 15° N
      final distance = dLat * dLat + dLon * dLon;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = region;
      }
    }
    return best;
  }

  /// Vrai si le texte des zones de culture d'une fiche cite cette région (ou une zone agricole qui la recouvre).
  static bool zonesMention(SenegalRegion region, String zonesText) {
    final cleaned = normalize(zonesText);
    if (cleaned.trim().isEmpty) return false;
    return region.zoneKeywords.any(cleaned.contains);
  }
}
