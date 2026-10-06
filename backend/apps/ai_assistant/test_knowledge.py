import re

from django.test import SimpleTestCase, TestCase

from apps.agriculture.models import AgronomicGuide
from apps.ai_assistant.knowledge import MARKER, normalize, retrieve


class NormalizeTests(SimpleTestCase):
    def test_removes_accents_case_and_punctuation(self):
        self.assertEqual(normalize("Récolte de l'Arachide !"), 'recolte de l arachide')


class RetrievalTests(TestCase):
    """Les fiches viennent de la migration de données : on teste la recherche sur le vrai contenu."""

    def test_how_to_sow_tomato_returns_calendar_and_sowing(self):
        result = retrieve('Comment semer les tomates ?')
        self.assertEqual([g.slug for g in result.guides], ['tomate-industrielle'])
        labels = {section.label for section in result.sections}
        self.assertEqual(labels, {'Semis et calendrier'})
        text = ' '.join(section.text for section in result.sections)
        self.assertIn('contre-saison', text)
        self.assertTrue(result.sources)

    def test_fertilizer_question_returns_only_fertilization(self):
        result = retrieve("Quel engrais pour l'oignon ?")
        self.assertEqual({section.label for section in result.sections}, {'Fertilisation'})
        self.assertIn('10-10-20', result.sections[0].text)
        self.assertIn("urée", result.sections[0].text)

    def test_pests_question_returns_pest_names_and_advice(self):
        result = retrieve("Quelles maladies attaquent l'arachide ?")
        text = result.sections[0].text
        self.assertEqual(result.sections[0].label, 'Maladies et ravageurs')
        self.assertIn('Rosette', text)
        self.assertIn('Aspergillus', text)

    def test_whole_word_matching_avoids_false_positives(self):
        self.assertEqual(retrieve('Je suis au milieu du champ.').guides, [])
        self.assertEqual([g.slug for g in retrieve('Quel engrais pour le mil ?').guides], ['mil'])

    def test_alias_and_plural_are_recognized(self):
        self.assertEqual([g.slug for g in retrieve('rendement des arachides').guides], ['arachide'])
        self.assertEqual([g.slug for g in retrieve('Quand semer le souna ?').guides], ['mil'])
        self.assertEqual([g.slug for g in retrieve('Rendement du paddy').guides], ['riz-irrigue'])

    def test_no_topic_returns_the_whole_sheet(self):
        result = retrieve("Parle-moi de l'arachide")
        self.assertEqual({section.label for section in result.sections}, {'Fiche complète'})

    def test_missing_information_is_reported_not_invented(self):
        result = retrieve('Quelles maladies attaquent le riz ?')
        self.assertEqual(result.sections, [])
        self.assertEqual(len(result.missing), 1)
        self.assertEqual(result.missing[0][1], 'Maladies et ravageurs')

    def test_unknown_crop_is_agricultural_but_has_no_sheet(self):
        result = retrieve('Comment cultiver le fonio ?')
        self.assertEqual(result.guides, [])
        self.assertEqual(result.sections, [])
        self.assertTrue(result.is_agricultural)

    def test_non_agricultural_question_is_detected(self):
        self.assertFalse(retrieve('Quel temps fait-il à Dakar ?').is_agricultural)
        self.assertFalse(retrieve('Bonjour, mais je veux de l\'aide').is_agricultural)

    def test_two_crops_share_one_consistent_source_numbering(self):
        result = retrieve("Quel engrais pour l'oignon et l'arachide ?")
        self.assertEqual({g.slug for g in result.guides}, {'oignon', 'arachide'})
        numbers = [source['number'] for source in result.sources]
        self.assertEqual(len(numbers), len(set(numbers)), 'numéros de source dupliqués')
        for section in result.sections:
            for marker in MARKER.findall(section.text):
                self.assertIn(int(marker), numbers)

    def test_every_marker_in_every_section_has_a_source(self):
        for question in ('semis oignon', 'engrais arachide', 'maladies mil', 'rendement riz', 'récolte tomate',
                         'cycle arachide', 'parle-moi du mil'):
            result = retrieve(question)
            numbers = {source['number'] for source in result.sources}
            for section in result.sections:
                for marker in MARKER.findall(section.text):
                    self.assertIn(int(marker), numbers, question)
                self.assertFalse(re.search(r'\[\]', section.text))

    def test_cycle_topic_mentions_the_cycle_range(self):
        result = retrieve("Quel est le cycle de l'arachide ?")
        self.assertIn('de 80 à 125 jours', result.sections[0].text)


class NewCropsRetrievalTests(TestCase):
    def test_carrot_harvest(self):
        result = retrieve('Comment récolter les carottes ?')
        self.assertEqual([g.slug for g in result.guides], ['carotte'])
        self.assertIn('fer courbe', result.sections[0].text)

    def test_carrot_fertilizer_and_water(self):
        self.assertIn('300 kg', retrieve('Quel engrais pour la carotte ?').sections[0].text)
        self.assertIn('6 à 9 litres', retrieve("Besoins en eau de la carotte ?").sections[0].text)

    def test_sorghum_fertilization(self):
        result = retrieve('Quel engrais pour le sorgho ?')
        self.assertEqual([g.slug for g in result.guides], ['sorgho'])
        self.assertIn('15-15-15', result.sections[0].text)

    def test_mango_harvest_period_and_pests(self):
        self.assertIn('mi-juin', retrieve('Quand récolter les mangues ?').sections[0].text)
        pests = retrieve('Quels ravageurs attaquent le manguier ?').sections[0].text
        self.assertIn('Mouches des fruits', pests)

    def test_recent_millet_varieties_are_listed_with_their_source(self):
        result = retrieve('Quelles variétés de mil récentes ?')
        text = ' '.join(section.text for section in result.sections)
        self.assertIn('Souna du Baol', text)
        self.assertTrue(any('isra.sn' in source['url'] for source in result.sources))

    def test_millet_and_sorghum_are_not_confused(self):
        self.assertEqual([g.slug for g in retrieve('Engrais pour le mil').guides], ['mil'])
        self.assertEqual([g.slug for g in retrieve('Engrais pour le sorgho').guides], ['sorgho'])


class BatchTwoCropsTests(TestCase):
    """Fiches issues du bilan ISRA/ITA/CIRAD : recherche, contenu clé et absence de produits périmés."""

    def test_potato_planting_periods_and_density(self):
        result = retrieve('Quand planter la pomme de terre ?')
        self.assertEqual([g.slug for g in result.guides], ['pomme-de-terre'])
        text = result.sections[0].text
        self.assertIn('octobre-novembre', text)
        self.assertIn('55 500', text)

    def test_the_word_terre_alone_does_not_select_potatoes(self):
        self.assertEqual(retrieve('Comment préparer la terre avant le semis ?').guides, [])

    def test_cabbage_variants_share_one_guide(self):
        for question in ('Engrais pour le chou-fleur', 'Engrais pour les choux', 'Engrais pour le chou chinois'):
            with self.subTest(question=question):
                self.assertEqual([g.slug for g in retrieve(question).guides], ['chou'])

    def test_cabbage_fertilization_gives_the_three_types(self):
        text = retrieve('Quel engrais pour le chou ?').sections[0].text
        for expected in ('Chou pommé', 'Chou chinois', 'Chou-fleur', '10-10-20'):
            self.assertIn(expected, text)

    def test_maize_is_found_with_or_without_the_accent(self):
        self.assertEqual([g.slug for g in retrieve('Quel engrais pour le maïs ?').guides], ['mais'])
        self.assertEqual([g.slug for g in retrieve('Quel engrais pour le mais ?').guides], ['mais'])
        self.assertEqual([g.slug for g in retrieve('Quand semer le maïs ?').guides], ['mais'])

    def test_the_conjunction_mais_never_selects_maize(self):
        for question in ("Bonjour, mais je veux de l'aide", "J'ai essayé mais ça ne marche pas", 'Mais où est mon profil ?'):
            with self.subTest(question=question):
                self.assertEqual(retrieve(question).guides, [])

    def test_cowpea_sowing_rule_and_spacing(self):
        result = retrieve('Comment semer le niébé ?')
        self.assertEqual([g.slug for g in result.guides], ['niebe'])
        text = ' '.join(section.text for section in result.sections)
        self.assertIn('15 mm', text)
        self.assertIn('50 × 25', text)

    def test_cowpea_storage_pest_is_documented(self):
        self.assertIn('Bruche', retrieve('Comment protéger le niébé des bruches ?').sections[0].text)

    def test_rice_now_has_water_fertilization_and_harvest(self):
        self.assertIn('5 à 15 cm', retrieve('Hauteur d eau pour le riz').sections[0].text)
        self.assertIn('18-46-0', retrieve('Quel engrais pour le riz ?').sections[0].text)
        harvest = retrieve('Quand récolter le riz ?')
        self.assertEqual({section.label for section in harvest.sections}, {'Récolte et conservation'})
        self.assertIn('40 jours', harvest.sections[0].text)

    def test_millet_has_senegalese_fertilizer_history_and_sowing_date(self):
        self.assertIn('14-7-7', retrieve('Quel engrais pour le mil ?').sections[0].text)
        self.assertIn('10 juin', ' '.join(s.text for s in retrieve('Quand semer le mil ?').sections))

    def test_every_new_crop_is_reachable_by_its_common_name(self):
        expected = {
            'aubergines': 'aubergine', 'le piment': 'piment', 'du gombo': 'gombo', 'la patate douce': 'patate-douce',
            'le manioc': 'manioc', 'le melon': 'melon', 'le bissap': 'bissap', 'la pomme de terre': 'pomme-de-terre',
        }
        for phrase, slug in expected.items():
            with self.subTest(phrase=phrase):
                self.assertEqual([g.slug for g in retrieve(f'Rendement de {phrase}').guides], [slug])

    def test_outdated_pesticide_names_are_not_served(self):
        banned = ('endosulfan', 'carbofuran', 'carbosulfan', 'diméthoate', 'dimethoate', 'deltaméthrine', 'chlorpyriphos',
                  'malathion', 'propanil', 'atrazine', 'mancozèbe', 'manèbe', 'chlorothalonil', 'fénitrothion')
        for slug in ('pomme-de-terre', 'chou', 'aubergine', 'piment', 'gombo', 'patate-douce', 'manioc', 'melon',
                     'bissap', 'mais', 'niebe', 'riz-irrigue', 'mil'):
            guide = AgronomicGuide.objects.get(slug=slug)
            blob = ' '.join([guide.summary, guide.calendar, guide.soil_and_sowing, guide.water_needs, guide.fertilization,
                             guide.harvest, guide.yield_info] + [p['advice'] for p in guide.pests_diseases]).lower()
            for name in banned:
                self.assertNotIn(name, blob, f'{slug} : produit {name} cité')
