import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/agriculture/data/models/agronomic_guide.dart';

void main() {
  group('AgronomicGuide Model', () {
    test('AgronomicGuide.fromJson désérialise fidèlement une fiche complète', () {
      final json = {
        'id': 'guide-uuid-1',
        'slug': 'niebe',
        'name': 'Niébé',
        'scientific_name': 'Vigna unguiculata',
        'category': 'legumineuse',
        'summary': 'Légumineuse vivrière majeure au Sénégal.',
        'zones': 'Bassin arachidier, Nord et Centre.',
        'cycle_days_min': 60,
        'cycle_days_max': 75,
        'calendar': 'Semis en juillet dès les premières pluies utiles.',
        'soil_and_sowing': 'Sols légers, sablonneux.',
        'water_needs': '300 à 450 mm bien répartis.',
        'fertilization': 'Fumure organique de fond.',
        'pests_diseases': [
          {'name': 'Pucerons (Aphis craccivora)', 'advice': 'Surveillance précoce et biopesticides.'},
        ],
        'harvest': 'Récolte des gousses sèches en 2 à 3 passages.',
        'yield_info': '800 à 1 200 kg/ha en bonnes conditions.',
        'limitations': 'Sensible aux attaques de bruches au stockage.',
        'sources': [
          {
            'number': 1,
            'title': 'Fiche technique Niébé ISRA',
            'publisher': 'ISRA / CNRA Bambey',
            'year': '2019',
            'url': 'https://isra.sn/niebe',
            'scope': 'senegal',
          },
          {
            'number': 2,
            'title': 'Guide FAO légumineuses tropicales',
            'publisher': 'FAO',
            'year': '2016',
            'url': 'https://fao.org/legumes',
            'scope': 'west_africa',
          },
        ],
        'updated_at': '2026-10-10T12:00:00Z',
      };

      final guide = AgronomicGuide.fromJson(json);

      expect(guide.slug, 'niebe');
      expect(guide.name, 'Niébé');
      expect(guide.scientificName, 'Vigna unguiculata');
      expect(guide.categoryLabel, 'Légumineuse');
      expect(guide.cycleDisplay, '60 à 75 jours');
      expect(guide.pestsDiseases, hasLength(1));
      expect(guide.pestsDiseases.first.name, 'Pucerons (Aphis craccivora)');
      expect(guide.sources, hasLength(2));
      expect(guide.sources.first.isSenegal, isTrue);
      expect(guide.sources.last.isSenegal, isFalse);
    });

    test('AgronomicGuide gère les champs facultatifs sans inventer de fausses données', () {
      final json = {
        'id': 'guide-uuid-2',
        'slug': 'pomme-de-terre',
        'name': 'Pomme de terre',
        'category': 'legume',
        'summary': 'Culture de contre-saison fraîche.',
        'sources': [],
      };

      final guide = AgronomicGuide.fromJson(json);

      expect(guide.scientificName, '');
      expect(guide.cycleDisplay, isNull);
      expect(guide.zones, '');
      expect(guide.calendar, '');
      expect(guide.pestsDiseases, isEmpty);
      expect(guide.sources, isEmpty);
      expect(guide.categoryLabel, 'Légume');
    });

    test('Cycle unique formatte "X jours" au lieu de "X à X jours"', () {
      final json = {
        'id': 'guide-uuid-3',
        'slug': 'culture-test',
        'name': 'Culture Test',
        'category': 'cereale',
        'summary': 'Test cycle identique',
        'cycle_days_min': 90,
        'cycle_days_max': 90,
      };

      final guide = AgronomicGuide.fromJson(json);
      expect(guide.cycleDisplay, '90 jours');
      expect(guide.categoryLabel, 'Céréale');
    });
  });
}
