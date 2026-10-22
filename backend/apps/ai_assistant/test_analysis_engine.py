"""
Moteur d'analyses : chaque résultat attendu ci-dessous a été calculé À LA MAIN à partir du jeu de données de
``setUpTestData`` (voir le détail dans les commentaires), indépendamment du code testé.

Date de référence figée : jeudi 22/10/2026.
"""
import datetime

from django.contrib.auth import get_user_model
from django.test import SimpleTestCase, TestCase

from apps.agriculture.models import Activity, Crop, Harvest
from apps.ai_assistant import analysis
from apps.finances.models import Sale, Transaction
from apps.inventory.models import StockItem
from apps.markets.models import Market, Price
from apps.notifications.models import Notification

User = get_user_model()
TODAY = datetime.date(2026, 10, 22)


def d(month, day):
    return datetime.date(2026, month, day)


class ThresholdSettingsTests(SimpleTestCase):
    def test_thresholds_come_from_django_settings_with_documented_defaults(self):
        from django.conf import settings
        self.assertEqual(analysis.ANOMALY_RATIO, settings.ANALYSIS_ANOMALY_RATIO)
        self.assertEqual(analysis.ANOMALY_MIN_INCREASE, settings.ANALYSIS_ANOMALY_MIN_INCREASE)
        self.assertEqual(analysis.STOCK_CRITICAL_DAYS, settings.ANALYSIS_STOCK_CRITICAL_DAYS)
        self.assertEqual(analysis.STOCK_WARNING_DAYS, settings.ANALYSIS_STOCK_WARNING_DAYS)
        self.assertEqual(analysis.SEASON_DAYS, settings.ANALYSIS_SEASON_DAYS)
        self.assertEqual((analysis.ANOMALY_RATIO, analysis.ANOMALY_MIN_INCREASE), (1.5, 10000))
        self.assertEqual((analysis.STOCK_CRITICAL_DAYS, analysis.STOCK_WARNING_DAYS, analysis.SEASON_DAYS), (7, 14, 120))


class PeriodTests(SimpleTestCase):
    def test_named_periods(self):
        week = analysis.resolve_period('current_week', TODAY)
        self.assertEqual((week.start, week.end), (d(10, 19), d(10, 22)))  # lundi -> aujourd'hui
        last_week = analysis.resolve_period('last_week', TODAY)
        self.assertEqual((last_week.start, last_week.end), (d(10, 12), d(10, 18)))
        month = analysis.resolve_period('current_month', TODAY)
        self.assertEqual((month.start, month.end), (d(10, 1), d(10, 22)))
        last_month = analysis.resolve_period('last_month', TODAY)
        self.assertEqual((last_month.start, last_month.end), (d(9, 1), d(9, 30)))
        self.assertIn('septembre 2026', last_month.label)
        year = analysis.resolve_period('current_year', TODAY)
        self.assertEqual((year.start, year.end), (d(1, 1), d(10, 22)))
        self.assertEqual(analysis.resolve_period('last_30_days', TODAY).days, 30)

    def test_season_is_exactly_120_days_and_says_it_is_an_assumption(self):
        season = analysis.resolve_period('season', TODAY)
        self.assertEqual(season.days, 120)
        self.assertEqual(season.end, TODAY)
        self.assertIn('hypothèse', season.label)

    def test_period_phrases_fit_into_a_sentence(self):
        self.assertEqual(analysis.resolve_period('season', TODAY).on[:9], 'sur la sa')
        self.assertEqual(analysis.resolve_period('last_30_days', TODAY).on[:12], 'sur les 30 d')
        self.assertTrue(analysis.resolve_period('current_month', TODAY).on.startswith('ce mois-ci'))
        self.assertTrue(analysis.resolve_period('last_month', TODAY).on.startswith('le mois dernier'))
        self.assertTrue(analysis.resolve_period('all', TODAY).on.startswith('depuis le début'))

    def test_aliases_and_unknown_codes(self):
        self.assertEqual(analysis.resolve_period('mois_dernier', TODAY).code, 'last_month')
        self.assertEqual(analysis.resolve_period('saison', TODAY).code, 'season')
        for code in ('all', 'n_importe_quoi', '', None):
            period = analysis.resolve_period(code, TODAY)
            self.assertEqual((period.code, period.start, period.end), ('all', None, None))

    def test_month_to_date_is_compared_with_the_same_days_of_the_previous_month(self):
        month = analysis.resolve_period('current_month', TODAY)
        previous = analysis.previous_period(month, TODAY)
        self.assertEqual((previous.start, previous.end), (d(9, 1), d(9, 22)))

    def test_previous_month_clamps_to_its_length(self):
        today = datetime.date(2026, 3, 31)
        previous = analysis.previous_period(analysis.resolve_period('current_month', today), today)
        self.assertEqual((previous.start, previous.end), (datetime.date(2026, 2, 1), datetime.date(2026, 2, 28)))

    def test_previous_of_a_complete_month_is_the_whole_month_before(self):
        previous = analysis.previous_period(analysis.resolve_period('last_month', TODAY), TODAY)
        self.assertEqual((previous.start, previous.end), (d(8, 1), d(8, 31)))

    def test_previous_week_has_the_same_length(self):
        week = analysis.resolve_period('current_week', TODAY)
        previous = analysis.previous_period(week, TODAY)
        self.assertEqual((previous.start, previous.end), (d(10, 12), d(10, 15)))
        self.assertEqual(previous.days, week.days)

    def test_previous_window_has_the_same_length(self):
        for code in ('season', 'last_30_days'):
            period = analysis.resolve_period(code, TODAY)
            previous = analysis.previous_period(period, TODAY)
            self.assertEqual(previous.days, period.days)
            self.assertEqual(previous.end, period.start - datetime.timedelta(days=1))

    def test_previous_year_handles_leap_day(self):
        today = datetime.date(2028, 2, 29)
        previous = analysis.previous_period(analysis.resolve_period('current_year', today), today)
        self.assertEqual((previous.start, previous.end), (datetime.date(2027, 1, 1), datetime.date(2027, 2, 28)))

    def test_all_has_no_reference_period(self):
        self.assertIsNone(analysis.previous_period(analysis.resolve_period('all', TODAY), TODAY))


class AnalysisDataMixin:
    """
    Jeu de données (utilisateur A) :
      Ventes  : Mil (culture, 2 ha)     05/10 100 × 300 = 30 000 ; 10/09 200 × 280 = 56 000
                Tomate (culture, 1 ha)  10/10  50 × 500 = 25 000 ; 20/10  30 × 600 = 18 000
                Arachide (sans culture) 01/10  10 × 1000 = 10 000
      Autre revenu : 18/10 subvention 7 000
      Dépenses : 03/10 engrais 20 000 (Mil) ; 15/10 carburant 5 000 ;
                 08/09 engrais 8 000 (Mil) ; 12/09 main-d'œuvre 6 000 ; 25/09 carburant 3 000
    """

    @classmethod
    def setUpTestData(cls):
        cls.user = User.objects.create_user(username='an1', phone='+221770700001', password='Motdepasse#2026')
        cls.other = User.objects.create_user(username='an2', phone='+221770700002', password='Motdepasse#2026')
        cls.mil = cls._crop(cls.user, 'Mil', 2.0)
        cls.tomate = cls._crop(cls.user, 'Tomate', 1.0)

        cls._sale(cls.user, cls.mil, 'Mil', d(10, 5), 100, 300)
        cls._sale(cls.user, cls.mil, 'Mil', d(9, 10), 200, 280)
        cls._sale(cls.user, cls.tomate, 'Tomate', d(10, 10), 50, 500)
        cls._sale(cls.user, cls.tomate, 'Tomate', d(10, 20), 30, 600)
        cls._sale(cls.user, None, 'Arachide', d(10, 1), 10, 1000)
        Transaction.objects.create(user=cls.user, transaction_type='income', amount=7000, date=d(10, 18), description='Subvention')

        cls._expense(cls.user, d(10, 3), 20000, "Achat d'engrais", cls.mil)
        cls._expense(cls.user, d(10, 15), 5000, 'Carburant')
        cls._expense(cls.user, d(9, 8), 8000, "Achat d'engrais", cls.mil)
        cls._expense(cls.user, d(9, 12), 6000, "Salaire des ouvriers")
        cls._expense(cls.user, d(9, 25), 3000, 'Carburant')

        Harvest.objects.create(crop=cls.mil, user=cls.user, date=d(10, 6), quantity=400, unit='kg')
        Activity.objects.create(crop=cls.mil, activity_type='Désherbage', date=d(10, 21))

        # Données d'un autre utilisateur : ne doivent JAMAIS apparaître
        other_crop = cls._crop(cls.other, 'Mil', 5.0)
        cls._sale(cls.other, other_crop, 'Mil', d(10, 10), 1000, 1000)
        cls._expense(cls.other, d(10, 10), 999999, 'Engrais', other_crop)
        StockItem.objects.create(user=cls.other, name='Secret', quantity=1, unit='kg')

    @staticmethod
    def _crop(user, name, area):
        return Crop.objects.create(user=user, name=name, crop_type='Culture', planting_date=d(6, 1),
                                   expected_harvest_date=d(11, 1), area_size=area, location='Thiès')

    @staticmethod
    def _sale(user, crop, name, date, quantity, price):
        return Sale.objects.create(user=user, crop=crop, product_name=name, quantity_sold=quantity,
                                   price_per_unit=price, date=date)

    @staticmethod
    def _expense(user, date, amount, description, crop=None):
        return Transaction.objects.create(user=user, transaction_type='expense', amount=amount, date=date,
                                          description=description, crop=crop)

    def period(self, code):
        return analysis.resolve_period(code, TODAY)

    def make_stock(self):
        for name, qty, unit in (('Mil', 100, 'kg'), ('Tomate', 30, 'kg'), ('Arachide', 2, 'kg'), ('Riz', 4, 'sacs'),
                                ('Sel', 50, 'kg'), ('Oignon', 0, 'kg')):
            StockItem.objects.create(user=self.user, name=name, quantity=qty, unit=unit)


class AnalysisEngineTests(AnalysisDataMixin, TestCase):
    """Calculs du moteur d'analyses sur le jeu de données de ``AnalysisDataMixin``."""

    # --- bilan -------------------------------------------------------------------------------------------------
    def test_current_month_summary(self):
        s = analysis.financial_summary(self.user, self.period('current_month'))
        # CA = 30 000 + 25 000 + 18 000 + 10 000 = 83 000 ; recettes = 83 000 + 7 000 ; dépenses = 20 000 + 5 000
        self.assertEqual((s['sales_revenue'], s['other_income'], s['total_revenue']), (83000.0, 7000.0, 90000.0))
        self.assertEqual((s['expenses_total'], s['net_result']), (25000.0, 65000.0))
        self.assertEqual((s['sales_count'], s['expenses_count']), (4, 2))
        categories = {c['category']: c for c in s['expenses_by_category']}
        self.assertEqual((categories['engrais']['amount'], categories['engrais']['share_pct']), (20000.0, 80.0))
        self.assertEqual((categories['carburant_transport']['amount'], categories['carburant_transport']['share_pct']), (5000.0, 20.0))
        self.assertEqual(s['expenses_by_category'][0]['category'], 'engrais')  # trié par montant décroissant

    def test_all_time_summary_never_double_counts_sale_income(self):
        s = analysis.financial_summary(self.user, self.period('all'))
        # CA = 83 000 + 56 000 ; la transaction « revenu » créée pour chaque vente ne doit pas être recomptée
        self.assertEqual(s['sales_revenue'], 139000.0)
        self.assertEqual(s['total_revenue'], 146000.0)
        self.assertEqual(s['expenses_total'], 42000.0)  # 20+5+8+6+3

    def test_sale_income_transactions_are_not_added_twice(self):
        sale = self._sale(self.user, None, 'Riz', d(10, 21), 10, 100)
        Transaction.objects.create(user=self.user, transaction_type='income', amount=1000, date=d(10, 21),
                                   description='Vente de riz', sale=sale)
        s = analysis.financial_summary(self.user, self.period('current_week'))
        self.assertEqual(s['total_revenue'], 18000.0 + 1000.0)  # vente tomate 20/10 + vente riz, sans doublon
        sale.delete()

    def test_empty_period_is_flagged(self):
        august = analysis.Period('custom', 'août 2026', d(8, 1), d(8, 31))  # aucune donnée en août dans le jeu de test
        s = analysis.financial_summary(self.user, august)
        self.assertFalse(s['has_data'])
        self.assertEqual((s['total_revenue'], s['expenses_total'], s['net_result']), (0.0, 0.0, 0.0))

    def test_legacy_expense_without_category_counts_as_other(self):
        tx = self._expense(self.user, d(10, 22), 1000, 'Divers')
        Transaction.objects.filter(pk=tx.pk).update(category='')
        s = analysis.financial_summary(self.user, self.period('current_week'))
        self.assertEqual(s['expenses_by_category'][0]['category'], 'autre')
        tx.delete()

    def test_definitions_never_mix_up_net_result_and_profit(self):
        s = analysis.financial_summary(self.user, self.period('all'))
        self.assertIn("n'est pas un bénéfice", s['definitions']['resultat_estime'])

    # --- comparaison -------------------------------------------------------------------------------------------
    def test_month_to_date_versus_same_days_of_previous_month(self):
        c = analysis.compare_periods(self.user, self.period('current_month'), TODAY)
        # Référence 01/09 -> 22/09 : CA 56 000 ; dépenses 8 000 + 6 000 = 14 000 (le carburant du 25/09 est exclu)
        self.assertTrue(c['comparable'])
        self.assertEqual(c['revenue'], {'current': 90000.0, 'previous': 56000.0, 'delta': 34000.0, 'delta_pct': 60.7})
        self.assertEqual(c['expenses'], {'current': 25000.0, 'previous': 14000.0, 'delta': 11000.0, 'delta_pct': 78.6})
        self.assertEqual(c['net_result'], {'current': 65000.0, 'previous': 42000.0, 'delta': 23000.0, 'delta_pct': 54.8})
        by_cat = {e['category']: e for e in c['expense_categories']}
        self.assertEqual((by_cat['engrais']['delta'], by_cat['engrais']['anomaly']), (12000.0, True))   # 20 000 >= 1,5 × 8 000 et +12 000
        self.assertEqual((by_cat['carburant_transport']['delta'], by_cat['carburant_transport']['anomaly']), (5000.0, False))  # < 10 000
        self.assertEqual(by_cat['main_oeuvre']['delta'], -6000.0)

    def test_comparison_with_empty_reference_has_no_fake_percentage(self):
        c = analysis.compare_periods(self.user, self.period('last_month'), TODAY)  # référence : août, sans donnée
        self.assertFalse(c['previous_has_data'])
        self.assertIsNone(c['revenue']['delta_pct'])  # division par zéro : jamais d'infini ni de 100 % inventé

    def test_all_cannot_be_compared(self):
        c = analysis.compare_periods(self.user, self.period('all'), TODAY)
        self.assertFalse(c['comparable'])
        self.assertIn('durée précise', c['note'])

    def test_expense_drivers_use_gross_increases_and_show_offsets(self):
        data = analysis.expense_drivers(self.user, self.period('current_month'), TODAY)
        self.assertTrue(data['increase'])
        shares = {x['category']: x['share_of_increase_pct'] for x in data['drivers']}
        # hausses brutes : engrais +12 000 et carburant +5 000 = 17 000
        self.assertEqual(shares, {'engrais': 70.6, 'carburant_transport': 29.4})
        self.assertAlmostEqual(sum(shares.values()), 100.0, places=1)
        self.assertEqual([o['category'] for o in data['offsets']], ['main_oeuvre'])
        self.assertEqual([b['amount'] for b in data['biggest_expenses']], [20000.0, 5000.0])

    def test_expense_drivers_when_expenses_fall(self):
        data = analysis.expense_drivers(self.user, self.period('last_month'), TODAY)
        # 25/09 inclus : dépenses de septembre 17 000 contre août 0 -> hausse ; on vérifie plutôt le cas inverse
        reverse = analysis.expense_drivers(self.user, analysis.Period('x', 'x', d(8, 1), d(8, 31)), TODAY)
        self.assertFalse(reverse['comparable'])  # un code inconnu n'a pas de référence
        self.assertTrue(data['increase'])

    # --- produits ----------------------------------------------------------------------------------------------
    def test_product_ranking_all_time(self):
        data = analysis.product_performance(self.user, self.period('all'))
        names = [p['name'] for p in data['products']]
        self.assertEqual(names, ['Mil', 'Tomate', 'Arachide'])
        mil, tomate, arachide = data['products']
        self.assertEqual((mil['revenue'], mil['quantity'], mil['share_pct']), (86000.0, 300.0, 61.9))
        self.assertEqual((tomate['revenue'], tomate['avg_unit_price'], tomate['min_unit_price'], tomate['max_unit_price']),
                         (43000.0, 537.5, 500.0, 600.0))
        self.assertEqual((arachide['revenue'], arachide['share_pct']), (10000.0, 7.2))
        self.assertEqual(data['total_revenue'], 139000.0)

    def test_product_ranking_is_period_specific(self):
        data = analysis.product_performance(self.user, self.period('last_month'))
        self.assertEqual([(p['name'], p['revenue']) for p in data['products']], [('Mil', 56000.0)])

    def test_product_names_group_regardless_of_case_and_accents(self):
        self._sale(self.user, None, 'mil', d(10, 22), 1, 10)  # sans culture, casse différente
        data = analysis.product_performance(self.user, self.period('current_week'))
        self.assertEqual(sorted(p['name'] for p in data['products']), ['Tomate', 'mil'])
        Sale.objects.filter(product_name='mil').delete()

    # --- rentabilité -------------------------------------------------------------------------------------------
    def test_profitability_only_when_costs_are_linked(self):
        data = analysis.crop_profitability(self.user)
        by_name = {c['name']: c for c in data['crops']}
        mil = by_name['Mil']
        # ventes 86 000 − dépenses rattachées (20 000 + 8 000) = 58 000, soit 67,4 % des ventes
        self.assertEqual((mil['revenue'], mil['linked_costs'], mil['margin'], mil['margin_rate_pct']), (86000.0, 28000.0, 58000.0, 67.4))
        self.assertTrue(mil['costs_known'])
        tomate = by_name['Tomate']
        self.assertIsNone(tomate['margin'])  # aucune dépense rattachée : pas de marge inventée
        self.assertFalse(tomate['costs_known'])
        self.assertEqual((mil['status'], tomate['status']), ('ok', 'no_costs'))
        self.assertEqual(data['missing_costs'], ['Tomate'])
        self.assertEqual([c['name'] for c in data['crops']], ['Mil', 'Tomate'])  # marges connues d'abord

    def test_profitability_ignores_other_users(self):
        mil = {c['name']: c for c in analysis.crop_profitability(self.user)['crops']}['Mil']
        self.assertNotEqual(mil['linked_costs'], 999999.0 + 28000.0)
        self.assertEqual(mil['area_ha'], 2.0)

    def test_crop_with_costs_but_no_sales_is_in_progress_not_a_loss(self):
        young = self._crop(self.user, 'Gombo', 1.0)
        self._expense(self.user, d(10, 2), 30000, 'Semences', young)
        data = analysis.crop_profitability(self.user)
        gombo = {c['name']: c for c in data['crops']}['Gombo']
        self.assertEqual((gombo['status'], gombo['margin'], gombo['margin_rate_pct']), ('no_sales', None, None))
        self.assertEqual(gombo['linked_costs'], 30000.0)
        self.assertEqual(data['awaiting_sales'], ['Gombo'])
        self.assertNotIn('Gombo', data['missing_costs'])
        young.delete()

    def test_negative_margin_is_reported_as_such(self):
        loss = self._crop(self.user, 'Piment', 1.0)
        self._expense(self.user, d(10, 2), 50000, 'Semences', loss)
        self._sale(self.user, loss, 'Piment', d(10, 20), 10, 1000)
        piment = {c['name']: c for c in analysis.crop_profitability(self.user)['crops']}['Piment']
        self.assertEqual((piment['status'], piment['margin'], piment['margin_rate_pct']), ('ok', -40000.0, -400.0))
        loss.delete()

    # --- évolution ---------------------------------------------------------------------------------------------
    def test_monthly_trend(self):
        data = analysis.monthly_trend(self.user, months=2, today=TODAY)
        sept, octo = data['months']
        self.assertEqual((sept['month'], sept['revenue'], sept['expenses'], sept['net_result'], sept['partial']),
                         ('2026-09', 56000.0, 17000.0, 39000.0, False))
        self.assertEqual((octo['month'], octo['revenue'], octo['expenses'], octo['net_result'], octo['partial']),
                         ('2026-10', 90000.0, 25000.0, 65000.0, True))
        self.assertIn('partiel', data['note'])

    def test_trend_spans_year_boundary(self):
        data = analysis.monthly_trend(self.user, months=3, today=datetime.date(2027, 1, 15))
        self.assertEqual([m['month'] for m in data['months']], ['2026-11', '2026-12', '2027-01'])

    # --- stocks ------------------------------------------------------------------------------------------------
    def test_stock_outlook_levels_and_order(self):
        self.make_stock()
        data = analysis.stock_outlook(self.user, TODAY)
        # Fenêtre du 24/09 au 22/10. Ventes : Mil 100, Tomate 80, Arachide 10 (la vente de mil du 10/09 est hors fenêtre)
        by_name = {i['name']: i for i in data['items']}
        self.assertEqual((by_name['Oignon']['level'], by_name['Oignon']['cover_days']), ('rupture', None))
        self.assertEqual((by_name['Arachide']['level'], by_name['Arachide']['cover_days']), ('critique', 6.0))    # 2 / (10/30)
        self.assertEqual((by_name['Tomate']['level'], by_name['Tomate']['cover_days']), ('attention', 11.2))      # 30 / (80/30) = 11,25, arrondi à 11,2
        self.assertEqual(by_name['Riz']['level'], 'bas')       # pas de vente, quantité <= 5
        self.assertEqual(by_name['Sel']['level'], 'inconnu')   # pas de vente, quantité > 5 : couverture non calculable
        self.assertEqual((by_name['Mil']['level'], by_name['Mil']['cover_days']), ('ok', 30.0))                   # 100 / (100/30)
        self.assertEqual([i['name'] for i in data['items']], ['Oignon', 'Arachide', 'Tomate', 'Riz', 'Sel', 'Mil'])
        self.assertEqual([i['name'] for i in data['priorities']], ['Oignon', 'Arachide', 'Tomate', 'Riz'])
        self.assertIn('même unité', data['assumption'])

    def test_stock_level_lookup_matches_by_words_and_is_isolated(self):
        self.make_stock()
        self.assertEqual([i['name'] for i in analysis.stock_level(self.user, 'mil', TODAY)['items']], ['Mil'])
        self.assertEqual(analysis.stock_level(self.user, 'secret', TODAY)['items'], [])
        self.assertEqual(analysis.stock_level(self.user, '', TODAY)['items'], [])

    # --- résumé ------------------------------------------------------------------------------------------------
    def test_weekly_summary(self):
        self.make_stock()
        Notification.objects.create(user=self.user, type='reminder', message='Arroser',
                                    scheduled_for=datetime.datetime(2030, 1, 1, 7, tzinfo=datetime.timezone.utc))
        data = analysis.activity_summary(self.user, self.period('current_week'), TODAY)
        # Semaine du 19 au 22/10 : seule la vente de tomate du 20/10 (18 000) ; désherbage du 21/10 ; récolte du 06/10 hors période
        self.assertEqual((data['finance']['total_revenue'], data['finance']['expenses_total']), (18000.0, 0.0))
        self.assertEqual([p['name'] for p in data['top_products']], ['Tomate'])
        self.assertEqual(data['activities']['count'], 1)
        self.assertEqual(data['activities']['recent'][0]['type'], 'Désherbage')
        self.assertEqual(data['harvests']['count'], 0)
        self.assertTrue(data['stock_priorities'])
        self.assertEqual([r['message'] for r in data['upcoming_reminders']], ['Arroser'])

    # --- comparaison de cultures ------------------------------------------------------------------------------------
    def test_investment_scenarios_come_only_from_observed_data(self):
        market = Market.objects.create(name='Castors', region='Dakar')
        Price.objects.create(market=market, product_name='Tomate', price=520, date=d(10, 21))
        other = Market.objects.create(name='Tilène', region='Dakar')
        Price.objects.create(market=other, product_name='Tomate', price=480, date=d(10, 21))

        data = analysis.crop_comparison(self.user, ['Mil', 'Tomate'])
        mil, tomate = data['products']

        # Mil : 400 kg récoltés / 2 ha = 200 par hectare ; dépenses rattachées 28 000 / 2 ha = 14 000 par hectare
        self.assertEqual((mil['yield_per_ha'], mil['cost_per_ha']), (200.0, 14000.0))
        self.assertEqual(mil['own_prices'], {'min': 280.0, 'avg': 290.0, 'max': 300.0})
        self.assertEqual(mil['scenarios']['prudent'], {'unit_price': 280.0, 'revenue_per_ha': 56000.0, 'margin_per_ha': 42000.0})
        self.assertEqual(mil['scenarios']['intermédiaire']['margin_per_ha'], 44000.0)
        self.assertEqual(mil['scenarios']['favorable']['margin_per_ha'], 46000.0)
        self.assertEqual(mil['missing'], [])

        # Tomate : prix connus (vos ventes + marché 500 en moyenne le 21/10) mais ni récoltes ni coûts rattachés
        self.assertEqual(tomate['market_price'], {'date': '2026-10-21', 'avg': 500.0, 'min': 480.0, 'max': 520.0, 'markets': 2})
        self.assertIsNone(tomate['scenarios'])  # pas de rendement : aucun scénario inventé
        self.assertEqual(tomate['missing'], ['quantités récoltées', 'dépenses rattachées à la culture'])
        self.assertIn('ne garantissent ni rendement ni bénéfice', data['limits'])

    def test_unknown_product_lists_what_is_missing(self):
        (product,) = analysis.crop_comparison(self.user, ['manioc'])['products']
        self.assertIsNone(product['scenarios'])
        self.assertIn('aucune culture enregistrée pour ce produit', product['missing'])
        self.assertIn('prix de vente ou prix de marché', product['missing'])

    # --- synthèse pour le LLM ----------------------------------------------------------------------------------
    def test_context_digest_is_certified_compact_and_isolated(self):
        self.make_stock()
        digest = analysis.context_digest(self.user, TODAY)
        month = digest['ce_mois']
        self.assertEqual((month['recettes_fcfa'], month['depenses_fcfa'], month['resultat_estime_fcfa']), (90000.0, 25000.0, 65000.0))
        self.assertEqual(digest['top_produits_depuis_le_debut'][0], {'produit': 'Mil', 'ca_fcfa': 86000.0, 'quantite': 300.0})
        self.assertEqual(digest['marge_par_culture'][0]['culture'], 'Mil')
        gap = month['ecart_vs_previous_month']
        self.assertEqual((gap['recettes_pct'], gap['depenses_pct']), (60.7, 78.6))
        self.assertEqual(gap['categories_en_hausse_anormale'], ['Engrais et amendements'])
        self.assertNotIn('Secret', str(digest))
        self.assertNotIn('999999', str(digest))
        self.assertIn('pas un bénéfice', str(digest['definitions']))

    def test_other_users_data_never_leaks_into_any_analysis(self):
        everything = [
            analysis.financial_summary(self.user, self.period('all')),
            analysis.product_performance(self.user, self.period('all')),
            analysis.crop_profitability(self.user),
            analysis.monthly_trend(self.user, 3, TODAY),
            analysis.stock_outlook(self.user, TODAY),
            analysis.activity_summary(self.user, self.period('all'), TODAY),
            analysis.crop_comparison(self.user, ['Mil']),
            analysis.context_digest(self.user, TODAY),
        ]
        blob = str(everything)
        for forbidden in ('999999', 'Secret', '1000000', '5.0'):
            self.assertNotIn(forbidden, blob, forbidden)

    def test_user_without_any_data_gets_empty_but_valid_results(self):
        nobody = User.objects.create_user(username='an3', phone='+221770700003', password='Motdepasse#2026')
        self.assertFalse(analysis.financial_summary(nobody, self.period('all'))['has_data'])
        self.assertEqual(analysis.product_performance(nobody, self.period('all'))['products'], [])
        self.assertEqual(analysis.crop_profitability(nobody)['crops'], [])
        self.assertFalse(analysis.monthly_trend(nobody, 3, TODAY)['has_data'])
        self.assertEqual(analysis.stock_outlook(nobody, TODAY)['items'], [])
        analysis.context_digest(nobody, TODAY)  # ne doit pas lever d'exception
