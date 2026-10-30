import '../../../ui/format.dart';
import '../data/models/crop_calendar.dart';

/// Photo d'une culture (images du catalogue des produits) ; `null` si on n'en a pas : l'écran montre alors une icône.
String? calendarCropImage(String key) {
  const files = {
    'mil': 'mil.png',
    'sorgho': 'sorgho.png',
    'mais': 'mais.png',
    'riz': 'riz.png',
    'fonio': 'fonio.png',
    'manioc': 'manioc.png',
    'pomme-de-terre': 'pomme_de_terre.png',
    'patate-douce': 'patate_douce.png',
    'niebe': 'niebe.png',
    'arachide': 'arachide.png',
    'chou': 'chou.png',
    'carotte': 'carotte.png',
    'concombre': 'concombre.png',
    'aubergine': 'aubergine.png',
    'salade': 'laitue.png',
    'melon': 'melon.png',
    'oignon': 'oignon_local.png',
    'citrouille': 'citrouille.png',
    'tomate': 'tomate.png',
    'navet': 'navet.png',
    'pasteque': 'pasteque.png',
    'banane': 'banane.png',
    'mangue': 'mangue.png',
    'lime': 'lime_de_tahiti.png',
    'gombo': 'gombo.png',
    'piment': 'piment.png',
    'bissap': 'bissap.png',
    'coton': 'coton.png',
    'canne-a-sucre': 'canne_a_sucre.png',
    'sesame': 'sesame.png',
    'feve': 'feve_verte.png',
  };
  final file = files[key];
  return file == null ? null : 'assets/images/products/$file';
}

/// Fiche technique de l'application qui correspond à la culture (elle sert à ajouter la culture), si elle existe.
String? calendarGuideSlug(String key) {
  const slugs = {
    'arachide': 'arachide',
    'aubergine': 'aubergine',
    'bissap': 'bissap',
    'carotte': 'carotte',
    'chou': 'chou',
    'gombo': 'gombo',
    'mangue': 'mangue',
    'manioc': 'manioc',
    'mais': 'mais',
    'melon': 'melon',
    'mil': 'mil',
    'niebe': 'niebe',
    'oignon': 'oignon',
    'patate-douce': 'patate-douce',
    'piment': 'piment',
    'pomme-de-terre': 'pomme-de-terre',
    'riz': 'riz-irrigue',
    'sorgho': 'sorgho',
  };
  return slugs[key];
}

const monthNames = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
const monthShort = ['Janv.', 'Févr.', 'Mars', 'Avr.', 'Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.', 'Nov.', 'Déc.'];

String categoryLabel(String category) => switch (category) {
      'cereale' => 'Céréales',
      'legume' => 'Légumes',
      'legumineuse' => 'Légumineuses',
      'tubercule' => 'Tubercules',
      'fruit' => 'Fruits',
      'industrielle' => 'Cultures industrielles',
      _ => 'Autres',
    };

/// « 1 sept. » : un repère annuel écrit en français.
String monthDayLabel(MonthDay d) => Fmt.shortDay(DateTime(2026, d.month, d.day));

/// « du 1 sept. au 31 oct. »
String spanLabel(Span span) => 'du ${monthDayLabel(span.start)} au ${monthDayLabel(span.end)}';

/// Période de semis d'une variante, en toutes lettres.
String sowingText(CalendarWindow w) {
  if (w.allYear) return 'Toute l\'année';
  if (w.sow != null) return spanLabel(w.sow!);
  return w.periodText;
}

/// Période de récolte d'une variante, en toutes lettres : celle que la source donne en mots est reprise telle quelle.
String harvestText(CalendarWindow w) {
  if (w.harvest == null) return '';
  return w.periodText.isNotEmpty && w.sow == null ? w.periodText.toLowerCase() : spanLabel(w.harvest!);
}

/// « 90 à 100 jours ».
String? cycleText(CalendarWindow w) {
  final a = w.cycleMin, b = w.cycleMax;
  if (a == null && b == null) return null;
  if (a == null || b == null || a == b) return '${a ?? b} jours';
  return '$a à $b jours';
}
