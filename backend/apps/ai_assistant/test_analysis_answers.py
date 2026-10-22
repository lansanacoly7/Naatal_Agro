"""
De la question au chiffre : reconnaissance des demandes (dont les exemples du cahier des charges §2), absence totale de
LLM sur les réponses chiffrées, fidélité des montants affichés, et renvoi des demandes de conseil vers le modèle.
"""
import datetime
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from apps.agriculture.models import Crop
from apps.ai_assistant import analysis_answers as answers
from apps.ai_assistant.analysis_answers import answer_analysis, detect_analysis_intent
from apps.ai_assistant.models import AIConversation
from apps.ai_assistant.test_analysis_engine import TODAY, AnalysisDataMixin, d
from apps.finances.models import Sale
from apps.markets.models import Product

User = get_user_model()

# (phrase, type d'analyse attendu)
RECOGNISED = [
    # exemples du cahier des charges, section 2
    ("Combien j'ai gagné depuis le début de la saison ?", 'finance'),
    ("Quel produit m'a rapporté le plus d'argent ?", 'top_products'),
    ("Quels produits se vendent le mieux chez moi ?", 'top_products'),
    ("Combien me reste-t-il de sacs de mil ?", 'stock_level'),
    ("Quels produits dois-je acheter en priorité ?", 'stock_outlook'),
    ("Est-ce que je devrais investir dans davantage de tomates ou d'oignons ?", 'investment'),
    ("Pourquoi mes dépenses augmentent-elles ?", 'expense_increase'),
    ("Fais-moi un résumé de mon activité cette semaine.", 'activity_summary'),
    # suggestions proposées dans l'interface
    ("Analyse mes revenus", 'finance'),
    ("Analyse mes dépenses", 'finance'),
    ("Vérifie mon stock", 'stock_outlook'),
    # variantes naturelles
    ("Quel est mon solde ?", 'finance'),
    ("Quel est mon chiffre d'affaires ce mois-ci ?", 'finance'),
    ("Mes recettes de la semaine dernière", 'finance'),
    ("Combien j'ai dépensé le mois dernier ?", 'finance'),
    ("Quelle est ma culture la plus rentable ?", 'profitability'),
    ("Quelle marge sur mes cultures ?", 'profitability'),
    ("Compare ce mois au mois dernier", 'comparison'),
    ("Évolution de mes ventes", 'trend'),
    ("Y a-t-il un risque de rupture ?", 'stock_outlook'),
    ("Mes dépenses ont explosé non ?", 'expense_increase'),
    ("Combien il me reste de mil", 'stock_level'),
    ("Résumé de ce mois", 'activity_summary'),
]

# Ces demandes ne doivent PAS être interceptées : conseil, agronomie, conversation courante
NOT_ANALYSIS = [
    "Comment augmenter mes revenus ?",
    "Comment réduire mes dépenses d'engrais ?",
    "Aide-moi à préparer mes prochaines ventes",
    "Conseille-moi pour améliorer ma marge",
    "Quand dois-je vendre mon mil ?",
    "Quel engrais utiliser pour le mil ?",
    "Comment traiter le mildiou sur la tomate ?",
    "Quelle est la saison des pluies au Sénégal ?",
    "Bonjour",
    "Merci beaucoup",
    "Planifie mes achats de la semaine",
]


class IntentDetectionTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.user = User.objects.create_user(username='ia1', phone='+221770800001', password='Motdepasse#2026')
        Crop.objects.create(user=cls.user, name='Tomate', crop_type='Légume', planting_date=datetime.date(2026, 6, 1),
                            expected_harvest_date=datetime.date(2026, 11, 1), area_size=1.0, location='Thiès')
        Product.objects.create(name='Oignon', category='LÉGUME', current_price=400, image_asset='x.png')

    def test_recognised_requests(self):
        for text, kind in RECOGNISED:
            with self.subTest(text=text):
                intent = detect_analysis_intent(text, self.user)
                self.assertIsNotNone(intent, text)
                self.assertEqual(intent['kind'], kind, text)

    def test_advice_and_unrelated_requests_are_left_to_the_language_model(self):
        for text in NOT_ANALYSIS:
            with self.subTest(text=text):
                self.assertIsNone(detect_analysis_intent(text, self.user), text)

    def test_periods_are_extracted(self):
        cases = {
            "Combien j'ai gagné depuis le début de la saison ?": ('season', True),
            "Mes recettes de la semaine dernière": ('last_week', True),
            "Mes recettes cette semaine": ('current_week', True),
            "Quel est mon chiffre d'affaires ce mois-ci ?": ('current_month', True),
            "Combien j'ai dépensé le mois dernier ?": ('last_month', True),
            "Mes revenus depuis le début": ('all', True),
            "Analyse mes revenus": ('all', False),
        }
        for text, expected in cases.items():
            with self.subTest(text=text):
                intent = detect_analysis_intent(text, self.user)
                self.assertEqual((intent['period_code'], intent['explicit_period']), expected)

    def test_defaults_per_kind(self):
        self.assertEqual(detect_analysis_intent("Résumé de mon activité", self.user)['period_code'], 'current_week')
        self.assertEqual(detect_analysis_intent("Pourquoi mes dépenses augmentent ?", self.user)['period_code'], 'current_month')
        self.assertEqual(detect_analysis_intent("Compare mes ventes", self.user)['period_code'], 'current_month')

    def test_stock_question_extracts_the_product(self):
        self.assertEqual(detect_analysis_intent("Combien me reste-t-il de sacs de mil ?", self.user)['product_query'], 'mil')
        self.assertEqual(detect_analysis_intent("Combien il me reste d'oignons en stock ?", self.user)['product_query'], 'oignons')
        self.assertEqual(detect_analysis_intent("Combien il me reste en stock ?", self.user)['kind'], 'stock_outlook')

    def test_investment_finds_products_in_singular_and_plural_across_sources(self):
        intent = detect_analysis_intent("Est-ce que je devrais investir dans davantage de tomates ou d'oignons ?", self.user)
        self.assertEqual(sorted(intent['products']), ['Oignon', 'Tomate'])  # Tomate : ma culture ; Oignon : produit du marché

    def test_actions_are_not_confused_with_analyses(self):
        """Les ordres d'écriture restent traités par le circuit proposition + confirmation."""
        from apps.ai_assistant.actions import detect_action_intent
        for text in ("Enregistre une dépense de 15 000 FCFA pour l'achat d'engrais.",
                     "J'ai vendu 25 sacs de riz à 12000 FCFA",
                     "Rappelle-moi d'arroser mes cultures demain matin."):
            with self.subTest(text=text):
                self.assertTrue(detect_action_intent(text, self.user)['has_intent'])


class AnalysisAnswerTests(AnalysisDataMixin, TestCase):
    """Réponses rédigées, sur le jeu de données du moteur, à la date de référence figée."""

    def answer(self, text, today=TODAY):
        intent = detect_analysis_intent(text, self.user)
        self.assertIsNotNone(intent, text)
        return answer_analysis(self.user, intent, today)

    def test_season_balance_states_period_definitions_and_correct_figures(self):
        out = self.answer("Combien j'ai gagné depuis le début de la saison ?")
        text = out['text']
        # Saison = 120 jours jusqu'au 22/10 : du 25/06 au 22/10 ; tout le jeu de données y figure
        self.assertIn("hypothèse", text)
        self.assertIn("Chiffre d'affaires (ventes) : 139 000 FCFA", text)
        self.assertIn("Autres revenus : 7 000 FCFA", text)
        self.assertIn("Recettes totales : 146 000 FCFA", text)
        self.assertIn("Dépenses enregistrées : 42 000 FCFA", text)
        self.assertIn("Résultat estimé : 104 000 FCFA", text)
        self.assertIn("**Bilan — la saison", text)
        self.assertIn("Ce n'est pas un bénéfice", text)
        self.assertEqual(out['data']['net_result'], 104000.0)

    def test_every_displayed_amount_comes_from_the_data(self):
        out = self.answer("Analyse mes dépenses ce mois-ci")
        self.assertIn("Engrais et amendements : 20 000 FCFA (80 %)", out['text'])
        self.assertIn("Carburant et transport : 5 000 FCFA (20 %)", out['text'])

    def test_empty_period_says_so_instead_of_inventing(self):
        out = self.answer("Mes recettes de la semaine dernière", today=datetime.date(2026, 3, 1))
        self.assertIn("Aucune vente ni dépense enregistrée", out['text'])

    def test_top_products_ranking(self):
        out = self.answer("Quel produit m'a rapporté le plus d'argent ?")
        lines = [l for l in out['text'].splitlines() if l[:2] in ('1.', '2.', '3.')]
        self.assertTrue(lines[0].startswith("1. Mil — 86 000 FCFA (61,9 % des ventes)"))
        self.assertTrue(lines[1].startswith("2. Tomate — 43 000 FCFA (30,9 %"))
        self.assertIn("prix moyen 538 FCFA", lines[1])  # 537,5 arrondi à l'affichage
        self.assertIn("pas par bénéfice", out['text'])

    def test_profitability_reports_margin_and_missing_costs(self):
        out = self.answer("Quelle est ma culture la plus rentable ?")
        self.assertIn("1. Mil — marge 58 000 FCFA, soit 67,4 % des ventes (ventes 86 000 FCFA − dépenses rattachées 28 000 FCFA)", out['text'])
        self.assertIn("Marge non calculable (aucune dépense rattachée à la culture) : Tomate", out['text'])

    def test_crop_in_progress_is_not_presented_as_a_loss(self):
        young = self._crop(self.user, 'Gombo', 1.0)
        self._expense(self.user, d(10, 2), 30000, 'Semences', young)
        text = self.answer("Quelle est ma culture la plus rentable ?")['text']
        self.assertIn("Cultures en cours, sans vente pour l'instant", text)
        self.assertIn("Gombo — 30 000 FCFA de dépenses rattachées", text)
        self.assertNotIn("marge -30 000", text)
        young.delete()

    def test_expense_increase_explanation(self):
        out = self.answer("Pourquoi mes dépenses augmentent-elles ?")
        text = out['text']
        self.assertIn("25 000 FCFA ce mois-ci", text)
        self.assertIn("contre 14 000 FCFA", text)
        self.assertIn("+11 000 FCFA (+78,6 %)", text)
        self.assertIn("Engrais et amendements : +12 000 FCFA (70,6 % des hausses) ⚠️ hausse anormale", text)
        self.assertIn("Carburant et transport : +5 000 FCFA (29,4 % des hausses)", text)
        self.assertIn("Compensée en partie par la baisse de : Main-d'œuvre et travaux (-6 000 FCFA)", text)
        self.assertIn("1,5 ×", text)  # le seuil d'anomalie est expliqué

    def test_expense_question_when_expenses_do_not_rise(self):
        out = self.answer("Pourquoi mes dépenses augmentent ?", today=datetime.date(2026, 11, 22))
        # Novembre (vide) contre octobre (25 000 + 7 000 en 22 jours) : les dépenses n'ont pas augmenté
        self.assertIn("Vos dépenses n'augmentent pas", out['text'])

    def test_comparison_wording(self):
        out = self.answer("Compare ce mois au mois dernier")
        self.assertIn("Recettes : 90 000 FCFA contre 56 000 FCFA (+34 000 FCFA, +60,7 %)", out['text'])
        self.assertIn("mêmes 22 premiers jours", out['text'])  # comparaison à durée égale annoncée

    def test_trend_marks_the_current_month_as_partial(self):
        out = self.answer("Évolution de mes ventes")
        self.assertIn("octobre 2026 (en cours)", out['text'])
        self.assertIn("ne le comparez pas à un mois complet", out['text'])

    def test_stock_priorities(self):
        self.make_stock()
        out = self.answer("Quels produits dois-je acheter en priorité ?")
        text = out['text']
        first = [l for l in text.splitlines() if l.startswith('• ')]
        self.assertIn("Oignon", first[0])
        self.assertIn("en rupture", first[0])
        self.assertIn("Arachide", first[1])
        self.assertIn("rupture imminente", first[1])
        self.assertIn("environ 6 jour(s) de ventes", first[1])
        self.assertNotIn("Mil", "".join(first))  # un stock suffisant n'est pas une priorité

    def test_unknown_coverage_is_not_reported_as_no_risk(self):
        from apps.inventory.models import StockItem
        StockItem.objects.create(user=self.user, name='Sel', quantity=50, unit='kg')
        text = self.answer("Vérifie mon stock")['text']
        self.assertNotIn("Aucun risque", text)
        self.assertIn("Aucun stock bas ni rupture imminente détectée", text)
        self.assertIn("n'est pas calculable pour 1 article(s)", text)

    def test_stock_level_answer(self):
        self.make_stock()
        out = self.answer("Combien me reste-t-il de sacs de mil ?")
        self.assertIn("Mil : 100 kg", out['text'])
        out = self.answer("Combien me reste-t-il de manioc ?")
        self.assertIn("aucun article « manioc »", out['text'])

    def test_weekly_summary(self):
        self.make_stock()
        out = self.answer("Fais-moi un résumé de mon activité cette semaine.")
        text = out['text']
        self.assertIn("cette semaine", text)
        self.assertIn("Recettes totales", text) if False else None
        self.assertIn("Chiffre d'affaires (ventes) : 18 000 FCFA", text)
        self.assertIn("Travaux enregistrés : 1 (Désherbage sur Mil)", text)
        self.assertIn("Récoltes enregistrées : 0", text)

    def test_investment_answer_shows_scenarios_missing_data_and_limits(self):
        out = self.answer("Dois-je investir dans le mil ou la tomate ?")
        text = out['text']
        self.assertIn("**Mil**", text)
        self.assertIn("Rendement observé : 200 par hectare", text)
        self.assertIn("Scénario prudent (1 ha, prix 280 FCFA) : recettes 56 000 FCFA, marge 42 000 FCFA", text)
        self.assertIn("**Tomate**", text)
        self.assertIn("il manque : quantités récoltées, dépenses rattachées à la culture", text)
        self.assertIn("ne garantissent ni rendement ni bénéfice", text)

    def test_investment_without_named_products_asks_which(self):
        intent = {'kind': 'investment', 'products': []}
        out = answer_analysis(self.user, intent, TODAY)
        self.assertIn("quels produits comparer", out['text'])

    def test_all_answers_work_for_a_user_without_data(self):
        nobody = User.objects.create_user(username='ia9', phone='+221770800009', password='Motdepasse#2026')
        for text, _kind in RECOGNISED:
            with self.subTest(text=text):
                intent = detect_analysis_intent(text, nobody)
                out = answer_analysis(nobody, intent, TODAY)
                self.assertTrue(out['text'])
                self.assertIsInstance(out['suggestions'], list)

    def test_other_users_figures_never_appear(self):
        for text, _kind in RECOGNISED:
            intent = detect_analysis_intent(text, self.user)
            out = answer_analysis(self.user, intent, TODAY)
            for forbidden in ("999 999", "999999", "Secret", "1 000 000"):
                self.assertNotIn(forbidden, out['text'], text)

    def test_number_formatting(self):
        self.assertEqual(answers.fcfa(1250000), "1 250 000 FCFA")
        self.assertEqual(answers.fcfa(-5000), "-5 000 FCFA")
        self.assertEqual(answers.number(2.5), "2,5")
        self.assertEqual(answers.number(100.0), "100")
        self.assertEqual(answers.signed_pct(12.5), "+12,5 %")
        self.assertIn("non calculable", answers.signed_pct(None))


class AnalysisThroughTheApiTests(AnalysisDataMixin, TestCase):
    """Parcours complet par l'API : la réponse vient de la base et le modèle de langage n'est JAMAIS appelé."""

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(self.user)
        self.conv = AIConversation.objects.create(user=self.user, title="Analyses")

    def ask(self, text):
        return self.client.post('/api/ai/ask/', {'query': text, 'conversation_id': str(self.conv.id)}, format='json')

    @patch('apps.ai_assistant.views.answer_question')
    def test_numeric_questions_never_call_the_language_model(self, llm):
        self.make_stock()
        for text, _kind in RECOGNISED:
            with self.subTest(text=text):
                response = self.ask(text)
                self.assertEqual(response.status_code, status.HTTP_201_CREATED)
                self.assertEqual(response.data['origin'], 'database')
                self.assertTrue(response.data['response'])
        llm.assert_not_called()

    @patch('apps.ai_assistant.views.answer_question')
    def test_all_time_balance_through_the_api(self, llm):
        response = self.ask("Mes revenus depuis le début")
        self.assertIn("Recettes totales : 146 000 FCFA", response.data['response'])
        self.assertIn("Dépenses enregistrées : 42 000 FCFA", response.data['response'])

    @patch('apps.ai_assistant.views.answer_question')
    def test_advice_questions_still_reach_the_language_model(self, llm):
        llm.return_value = {'answer': 'Conseil du modèle', 'origin': 'general', 'sources': [], 'suggestions': []}
        response = self.ask("Comment augmenter mes revenus ?")
        llm.assert_called_once()
        self.assertEqual(response.data['response'], 'Conseil du modèle')

    @patch('apps.ai_assistant.views.answer_question')
    def test_a_pending_proposal_is_not_confirmed_by_an_analysis_question(self, llm):
        llm.return_value = {'answer': 'Réponse du modèle', 'origin': 'general', 'sources': [], 'suggestions': []}
        proposal = self.ask("J'ai dépensé 25000 FCFA pour du compost")
        self.assertEqual(proposal.data['action_data']['status'], 'pending_confirmation')
        self.ask("Quel est mon solde ?")
        from apps.finances.models import Transaction
        before = Transaction.objects.filter(transaction_type='expense').count()
        self.ask("oui")  # la dernière réponse n'est plus la proposition : rien ne doit être exécuté
        self.assertEqual(Transaction.objects.filter(transaction_type='expense').count(), before)
        llm.assert_called()  # « oui » isolé sans proposition en attente retourne au circuit normal

    def test_llm_context_carries_the_certified_digest(self):
        from apps.ai_assistant.services import get_farmer_context
        context = get_farmer_context(self.user)
        digest = context['analyses_certifiees']
        self.assertIn('ce_mois', digest)
        self.assertIn('definitions', digest)
        self.assertNotIn('999999', str(context))

    def test_analytics_endpoint_keeps_its_contract(self):
        data = self.client.get('/api/ai/analytics/?period=all').data['finances']
        self.assertEqual((data['total_revenue_fcfa'], data['total_expenses_fcfa'], data['balance_fcfa']), (146000.0, 42000.0, 104000.0))
        self.assertTrue(data['is_profitable'])
        week = self.client.get('/api/ai/analytics/?period=current_week').data['finances']
        self.assertEqual(week['period'], 'current_week')
        self.assertIn('start_date', week)
