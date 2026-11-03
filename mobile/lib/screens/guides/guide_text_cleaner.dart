/// Utilitaires de nettoyage du texte des fiches techniques.
/// Élimine de manière étanche les repères de citation bruts ([1], [2]...),
/// les symboles mathématiques parasites ($), les étoiles (*) ou doubles espaces.
String cleanGuideText(String? text) {
  if (text == null || text.trim().isEmpty) return '';
  var s = text;
  // Supprime les repères [1], [2], [1, 2], [1] [2], [3, 4] etc.
  s = s.replaceAll(RegExp(r'\s*\[\s*\d+(?:\s*,\s*\d+)*\s*\]'), '');
  // Supprime les symboles markdown ou dollars parasites
  s = s.replaceAll(r'$', '');
  s = s.replaceAll(RegExp(r'\*{1,3}'), '');
  // Nettoie les doubles espaces et espaces devant ponctuation
  s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  s = s.replaceAll(RegExp(r'\s+([,.;:])'), r'$1');
  return s.trim();
}

