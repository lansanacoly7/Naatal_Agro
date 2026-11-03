"""
Importe les prix de détail officiels du Sénégal publiés par le PAM (WFP) sur HDX, relevés par l'ANSD / le CSA et repris par la FAO.

Jeu de données : « Senegal - Food Prices » (licence CC BY-IGO, mise à jour mensuelle),
https://data.humdata.org/dataset/wfp-food-prices-for-senegal

Les relevés officiels remplacent les prix générés, uniquement pour les couples (marché, produit) qu'ils couvrent ; le reste
n'est pas touché. L'import est rejouable : les anciens relevés officiels sont remplacés.
"""
import csv
import io
import unicodedata
import urllib.request
from collections import defaultdict
from datetime import date, timedelta

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.markets.models import Market, Price, Product

SOURCE = 'wfp'
DEFAULT_URL = (
    'https://data.humdata.org/dataset/77b76bc7-1edd-43f6-a5e4-784498ff6aca/resource/'
    '04ffc070-6d05-4653-a9f6-9f3f893a229e/download/wfp_food_prices_sen.csv'
)

# Produit du PAM -> produit de l'application. Les variantes importées ne sont pas mélangées aux produits locaux.
COMMODITIES = {
    'Millet': 'Mil',
    'Maize (local)': 'Maïs',
    'Sorghum': 'Sorgho',
    'Beans (niebe)': 'Niébé',
    'Groundnuts (shelled)': 'Arachide Décortiquée',
    'Rice (local)': 'Riz',
    'Onions (dry)': 'Oignon Local',
    'Potatoes': 'Pomme de Terre',
    'Tomatoes': 'Tomate',
    'Cabbage': 'Chou',
    'Carrots': 'Carotte',
    'Cassava': 'Manioc',
    'Sweet potatoes': 'Patate douce',
    'Bananas (local)': 'Banane',
    'Mangoes (local)': 'Mangue',
    'Watermelons': 'Pastèque',
    'Oranges': 'Orange',
    'Fonio': 'Fonio',
}

REGIONS = {'Thies': 'Thiès', 'Saint Louis': 'Saint-Louis', 'Kedougou': 'Kédougou', 'Sedhiou': 'Sédhiou'}
MARKET_NAMES = {'Saint-Maur': 'Boucotte'}

STABLE_BAND = 0.02  # variation mensuelle jugée « stable » en dessous de 2 %


def _key(text):
    plain = unicodedata.normalize('NFKD', text).encode('ascii', 'ignore').decode().lower().strip()
    for prefix in ('marche de ', 'marche d\'', 'marche '):
        if plain.startswith(prefix):
            plain = plain[len(prefix):]
    return plain


class Command(BaseCommand):
    help = "Importe les prix de détail officiels (PAM / ANSD) et remplace les prix générés qu'ils couvrent."

    def add_arguments(self, parser):
        parser.add_argument('--file', help='CSV déjà téléchargé (sinon téléchargement depuis HDX)')
        parser.add_argument('--months', type=int, default=24, help="Nombre de mois d'historique à importer (défaut 24)")

    def handle(self, *args, file=None, months=24, **options):
        if file:
            with open(file, encoding='utf-8-sig', newline='') as handle:
                text = handle.read()
        else:
            self.stdout.write('Téléchargement depuis HDX...')
            try:
                with urllib.request.urlopen(DEFAULT_URL, timeout=120) as response:
                    text = response.read().decode('utf-8-sig')
            except OSError as exc:
                raise CommandError(f'Téléchargement impossible : {exc}')

        lines = [row for row in csv.DictReader(io.StringIO(text)) if not row['date'].startswith('#')]
        since = date.today() - timedelta(days=months * 31)
        missing_products = [name for name in COMMODITIES.values() if not Product.objects.filter(name=name).exists()]
        if missing_products:
            raise CommandError(f'Produits absents du catalogue : {missing_products}')

        wanted = []
        for row in lines:
            if row['commodity'] not in COMMODITIES or row['unit'] != 'KG' or row['currency'] != 'XOF':
                continue
            if row['priceflag'] != 'actual' or row['pricetype'] != 'Retail':
                continue
            day = date.fromisoformat(row['date'])
            if day >= since:
                wanted.append((row, day))
        if not wanted:
            raise CommandError('Aucun relevé exploitable dans le fichier.')

        with transaction.atomic():
            Market.objects.filter(name='Marché Saint-Maur').update(name='Marché Boucotte')
            Price.objects.filter(source=SOURCE).delete()
            existing = {_key(m.name): m for m in Market.objects.all()}
            markets = {}
            created_markets = 0
            for row, _ in wanted:
                name = MARKET_NAMES.get(row['market'], row['market'])
                if name in markets:
                    continue
                market = existing.get(_key(name))
                if market is None:
                    market = Market.objects.create(
                        name=f'Marché {REGIONS.get(name, name)}',
                        region=REGIONS.get(row['admin1'], row['admin1']),
                        location_gps=f"{row['latitude']},{row['longitude']}",
                    )
                    existing[_key(name)] = market
                    created_markets += 1
                markets[name] = market

            series = defaultdict(list)
            for row, day in wanted:
                market_name = MARKET_NAMES.get(row['market'], row['market'])
                series[(market_name, COMMODITIES[row['commodity']])].append((day, float(row['price'])))

            products = {p.name: p for p in Product.objects.filter(name__in=set(COMMODITIES.values()))}
            to_create = []
            for (market_name, product_name), points in series.items():
                points.sort()
                previous = None
                for day, price in points:
                    trend = 'stable'
                    if previous:
                        change = (price - previous) / previous
                        trend = 'up' if change > STABLE_BAND else 'down' if change < -STABLE_BAND else 'stable'
                    previous = price
                    to_create.append(Price(
                        market=markets[market_name], product=products[product_name], product_name=product_name,
                        price=round(price, 2), trend=trend, date=day, source=SOURCE,
                    ))
            Price.objects.bulk_create(to_create)

            # Les relevés officiels remplacent les prix générés, couple (marché, produit) par couple
            removed = 0
            for market_name, product_name in series:
                removed += Price.objects.filter(
                    market=markets[market_name], product_name=product_name,
                ).exclude(source=SOURCE).delete()[0]

        for product in products.values():
            product.sync_live_price()
        self.stdout.write(self.style.SUCCESS(
            f'{len(to_create)} relevés officiels importés ({len(markets)} marchés dont {created_markets} créés, '
            f'{len(series)} couples marché-produit) ; {removed} prix générés remplacés.'
        ))
