import random
from datetime import timedelta
from django.utils import timezone
from django.core.management.base import BaseCommand
from apps.markets.models import Market, Price, Product

class Command(BaseCommand):
    help = 'Génère des données de prix fictives mais réalistes pour les marchés sénégalais'

    def handle(self, *args, **kwargs):
        self.stdout.write("Génération des données de marché...")

        # 1. Définition des marchés réels/réalistes
        markets_data = [
            {"name": "Marché Castors", "region": "Dakar", "gps": "14.7077,-17.4526"},
            {"name": "Marché Sandaga", "region": "Dakar", "gps": "14.6710,-17.4380"},
            {"name": "Marché Thiaroye", "region": "Dakar", "gps": "14.7570,-17.3820"},
            {"name": "Marché Central", "region": "Thiès", "gps": "14.7928,-16.9267"},
            {"name": "Marché Saint-Louis", "region": "Saint-Louis", "gps": "16.0326,-16.4818"},
            {"name": "Marché Touba", "region": "Diourbel", "gps": "14.8620,-15.8820"},
            {"name": "Marché Ziguinchor", "region": "Ziguinchor", "gps": "12.5833,-16.2719"},
            {"name": "Marché Tilène", "region": "Dakar", "gps": "14.6853,-17.4521"},
            {"name": "Marché HLM", "region": "Dakar", "gps": "14.7110,-17.4540"},
            {"name": "Marché Kermel", "region": "Dakar", "gps": "14.6700,-17.4310"},
            {"name": "Marché Pikine", "region": "Dakar", "gps": "14.7550,-17.3900"},
            {"name": "Marché Rufisque", "region": "Dakar", "gps": "14.7160,-17.2730"},
            {"name": "Marché Keur Massar", "region": "Dakar", "gps": "14.7840,-17.3190"},
            {"name": "Marché Mbour", "region": "Thiès", "gps": "14.4198,-16.9640"},
            {"name": "Marché Kaolack", "region": "Kaolack", "gps": "14.1510,-16.0730"},
            {"name": "Marché Louga", "region": "Louga", "gps": "15.6144,-16.2287"},
            {"name": "Marché Tambacounda", "region": "Tambacounda", "gps": "13.7707,-13.6673"},
            {"name": "Marché Kolda", "region": "Kolda", "gps": "12.8939,-14.9410"},
            {"name": "Marché Richard-Toll", "region": "Saint-Louis", "gps": "16.4625,-15.7006"},
        ]

        markets = []
        for m_data in markets_data:
            market, _ = Market.objects.get_or_create(
                name=m_data['name'],
                defaults={'region': m_data['region'], 'location_gps': m_data['gps']}
            )
            markets.append(market)

        # 2. Produits
        products = list(Product.objects.all())
        if not products:
            self.stdout.write(self.style.ERROR("Aucun produit trouvé. Veuillez d'abord lancer seed.py ou populate_products.py."))
            return

        # 3. Génération des prix (historique sur 30 jours)
        Price.objects.all().delete()
        today = timezone.now().date()
        
        prices_to_create = []

        for market in markets:
            for product in products:
                base_price = float(product.current_price)
                # Appliquer une variation régionale
                if market.region == "Dakar":
                    base_price *= 1.15 # Plus cher à Dakar
                elif market.region == "Ziguinchor" and product.category == "FRUIT":
                    base_price *= 0.80 # Moins cher dans le sud
                elif market.region == "Thiès":
                    base_price *= 0.90 

                current_price = base_price
                
                # Générer l'historique
                for i in range(30, -1, -1):
                    target_date = today - timedelta(days=i)
                    
                    # Variation aléatoire entre -2% et +2% par jour
                    variation = random.uniform(-0.02, 0.02)
                    current_price = current_price * (1 + variation)
                    
                    # Déterminer la tendance
                    trend = "stable"
                    if variation > 0.005:
                        trend = "up"
                    elif variation < -0.005:
                        trend = "down"

                    prices_to_create.append(
                        Price(
                            market=market,
                            product_name=product.name,
                            price=round(current_price, 2),
                            trend=trend,
                            date=target_date
                        )
                    )

        # Bulk create for performance
        Price.objects.bulk_create(prices_to_create)

        self.stdout.write(self.style.SUCCESS(f"{len(prices_to_create)} enregistrements de prix générés avec succès pour {len(markets)} marchés."))
