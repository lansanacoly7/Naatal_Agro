/// Formats d'affichage communs : espaces entre milliers, FCFA, dates en français.
abstract final class Fmt {
  /// 185000 -> « 185 000 ».
  static String grouped(num value) {
    final negative = value < 0;
    final digits = value.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return '${negative ? '−' : ''}$buffer';
  }

  /// Nombre décimal sans zéros inutiles : 1.5 -> « 1,5 », 2.0 -> « 2 ».
  static String decimal(num value, {int digits = 1}) {
    if (value == value.roundToDouble()) return grouped(value);
    return value.toStringAsFixed(digits).replaceAll('.', ',');
  }

  static String fcfa(num value) => '${grouped(value)} FCFA';

  static const List<String> _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
    'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  static const List<String> _weekdays = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
  ];

  /// « mardi 13 octobre ».
  static String dayMonth(DateTime d) =>
      '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

  /// « 13 oct. 2026 ».
  static String shortDate(DateTime d) {
    final m = _months[d.month - 1];
    final short = m.length > 4 ? '${m.substring(0, 3)}.' : m;
    return '${d.day} $short ${d.year}';
  }

  /// « 13 oct. » (sans l'année).
  static String shortDay(DateTime d) {
    final m = _months[d.month - 1];
    final short = m.length > 4 ? '${m.substring(0, 3)}.' : m;
    return '${d.day} $short';
  }

  /// « il y a 2 jours », « aujourd'hui », « dans 38 jours ».
  static String relativeDays(DateTime d, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final a = DateTime(d.year, d.month, d.day);
    final b = DateTime(today.year, today.month, today.day);
    final diff = a.difference(b).inDays;
    if (diff == 0) return "aujourd'hui";
    if (diff == 1) return 'demain';
    if (diff == -1) return 'hier';
    if (diff > 0) return 'dans $diff jours';
    return 'il y a ${-diff} jours';
  }
}
