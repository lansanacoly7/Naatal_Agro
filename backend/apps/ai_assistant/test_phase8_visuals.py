"""Phase 8 — graphiques : le descripteur joint aux analyses reprend exactement les chiffres du calcul déterministe."""
import datetime

from django.utils import timezone

from apps.ai_assistant.test_phase2_assistant import AssistantPhase2Base
from apps.finances.models import Sale, Transaction
from apps.inventory.services import create_stock_item


class VisualTests(AssistantPhase2Base):
    def seed(self):
        today = timezone.localdate()
        Sale.objects.create(user=self.user, product_name='Mil', quantity_sold=10, price_per_unit=1000, date=today)
        Sale.objects.create(user=self.user, product_name='Arachide', quantity_sold=5, price_per_unit=2000, date=today)
        Transaction.objects.create(user=self.user, transaction_type='expense', amount=4000, description='Engrais',
                                   category='engrais', date=today)
        Sale.objects.create(user=self.user, product_name='Mil', quantity_sold=4, price_per_unit=1000,
                            date=today - datetime.timedelta(days=35))

    def visual(self, text):
        response = self.ask(text)
        return response.data['action_data'].get('visual'), response

    def test_finance_bars_match_the_figures(self):
        self.seed()
        visual, response = self.visual("Quel est mon bilan ce mois ?")
        self.assertEqual(visual['type'], 'bars')
        values = {i['label']: i['value'] for i in visual['items']}
        self.assertEqual(values['Recettes'], 20000)
        self.assertEqual(values['Dépenses'], 4000)
        self.assertEqual(values['Résultat estimé'], 16000)
        self.assertIn("20 000 FCFA", response.data['response'])

    def test_top_products_bars(self):
        self.seed()
        visual, _ = self.visual("Quel produit rapporte le plus ?")
        self.assertEqual([i['label'] for i in visual['items']][0:2], ['Mil', 'Arachide'])  # toutes périodes : Mil 14 000, Arachide 10 000

    def test_comparison_and_trend(self):
        self.seed()
        compare, _ = self.visual("Compare ce mois au mois dernier")
        self.assertEqual(compare['type'], 'compare')
        self.assertEqual({r['label'] for r in compare['rows']}, {'Recettes', 'Dépenses', 'Résultat'})
        trend, _ = self.visual("Évolution de mes ventes")
        self.assertEqual(trend['type'], 'months')
        self.assertGreaterEqual(len(trend['items']), 2)

    def test_stock_levels(self):
        create_stock_item(self.user, 'Mil', 3, 'sac', reason='manual')
        visual, _ = self.visual("Vérifie mon stock")
        self.assertEqual(visual['type'], 'levels')
        self.assertEqual(visual['items'][0]['label'], 'Mil')

    def test_no_data_means_no_chart(self):
        visual, response = self.visual("Quel est mon bilan ce mois ?")
        self.assertIsNone(visual)
        self.assertIn("Aucune vente ni dépense", response.data['response'])

    def test_actions_and_plain_answers_carry_no_chart(self):
        response = self.ask("Mes rappels")
        self.assertNotIn('visual', response.data['action_data'])
