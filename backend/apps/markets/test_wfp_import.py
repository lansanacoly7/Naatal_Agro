import tempfile
from datetime import date, timedelta

from django.core.management import call_command
from django.test import TestCase

from .market_overview import build_overview
from .models import Market, Price, Product


def month(offset):
    return (date.today().replace(day=15) - timedelta(days=31 * offset)).isoformat()


HEADER = 'date,admin1,admin2,market,market_id,latitude,longitude,category,commodity,commodity_id,unit,priceflag,pricetype,currency,price,usdprice\n'


class ImportWfpPricesTests(TestCase):
    def setUp(self):
        Product.objects.create(name='Mil', category='CÉRÉALE', current_price=300, image_asset='mil')
        for name in ['Maïs', 'Sorgho', 'Niébé', 'Arachide Décortiquée', 'Riz', 'Oignon Local', 'Pomme de Terre', 'Tomate',
                     'Chou', 'Carotte', 'Manioc', 'Patate douce', 'Banane', 'Mangue', 'Pastèque', 'Orange', 'Fonio']:
            Product.objects.create(name=name, category='LÉGUME', current_price=100, image_asset='x')
        self.market = Market.objects.create(name='Marché Tilène', region='Dakar', location_gps='14.68,-17.46')
        self.market.refresh_from_db()
        # Prix générés d'un autre produit, à ne pas toucher ; et un prix généré de Mil, à remplacer
        Price.objects.create(market=self.market, product_name='Tomate', price=900, date=date.today())
        Price.objects.create(market=self.market, product_name='Mil', price=999, date=date.today())

    def run_import(self, rows):
        with tempfile.NamedTemporaryFile('w', suffix='.csv', delete=False, encoding='utf-8') as handle:
            handle.write(HEADER + '#date,#adm1+name,#adm2+name,#loc+market+name,#loc+market+code,#geo+lat,#geo+lon,#item+type,#item+name,#item+code,#item+unit,#item+price+flag,#item+price+type,#currency,#value,#value+usd\n')
            handle.write(''.join(rows))
        call_command('import_wfp_prices', file=handle.name, verbosity=0)

    def line(self, day, price, commodity='Millet', unit='KG', flag='actual', ptype='Retail'):
        return f'{day},Dakar,Dakar,Tilene,447,14.68,-17.46,cereals,{commodity},1,{unit},{flag},{ptype},XOF,{price},0.3\n'

    def test_official_prices_replace_generated_ones_only_where_covered(self):
        self.run_import([self.line(month(2), 300), self.line(month(1), 330), self.line(month(0), 345)])
        mil = Price.objects.filter(market=self.market, product_name='Mil')
        self.assertEqual(mil.count(), 3)
        self.assertEqual(set(mil.values_list('source', flat=True)), {'wfp'})
        self.assertTrue(Price.objects.filter(product_name='Tomate', source='generated').exists())
        self.assertEqual(Market.objects.filter(name__icontains='Tilene').count(), 0)  # rattaché au marché existant

    def test_ignores_what_is_not_a_real_retail_price_per_kilo(self):
        self.run_import([self.line(month(0), 345), self.line(month(0), 5, unit='Head'), self.line(month(1), 9, flag='forecast'),
                         self.line(month(1), 9, ptype='Wholesale'), self.line(month(1), 400, commodity='Livestock (Goat)')])
        self.assertEqual(Price.objects.filter(source='wfp').count(), 1)

    def test_import_can_be_rerun(self):
        rows = [self.line(month(1), 330), self.line(month(0), 345)]
        self.run_import(rows)
        self.run_import(rows)
        self.assertEqual(Price.objects.filter(source='wfp').count(), 2)

    def test_overview_names_the_official_source_and_keeps_a_year_of_history(self):
        self.run_import([self.line(month(i), 300 + i) for i in range(6, -1, -1)])
        mil = next(p for p in build_overview(self.market)['products'] if p['name'] == 'Mil')
        self.assertEqual(mil['source'], 'Relevé officiel PAM / ANSD')
        self.assertEqual(mil['window_days'], 365)
        self.assertEqual(len(mil['history']), 7)
        self.assertIsNone(mil['forecast'])  # relevés mensuels : pas assez pour une prévision, et on ne l'invente pas
        tomato = next(p for p in build_overview(self.market)['products'] if p['name'] == 'Tomate')
        self.assertIsNone(tomato['source'])
