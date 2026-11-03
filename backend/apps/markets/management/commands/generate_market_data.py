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
            {"name": "Marché d'Intérêt National (MIN) de Diamniadio", "region": "Diamniadio", "gps": "14.7157,-17.2078"},
            {"name": "Marché Castors", "region": "Dakar", "gps": "14.7077,-17.4526"},
            {"name": "Marché Sandaga", "region": "Dakar", "gps": "14.6700,-17.4379"},
            {"name": "Marché Thiaroye", "region": "Dakar", "gps": "14.7564,-17.3792"},
            {"name": "Marché Central", "region": "Thiès", "gps": "14.7978,-16.9311"},
            {"name": "Marché Saint-Louis", "region": "Saint-Louis", "gps": "16.0251,-16.4973"},
            {"name": "Marché Touba", "region": "Diourbel", "gps": "14.8578,-15.8737"},
            {"name": "Marché Ziguinchor", "region": "Ziguinchor", "gps": "12.5833,-16.2719"},
            {"name": "Marché Tilène", "region": "Dakar", "gps": "14.6817,-17.4497"},
            {"name": "Marché HLM", "region": "Dakar", "gps": "14.7060,-17.4445"},
            {"name": "Marché Kermel", "region": "Dakar", "gps": "14.6705,-17.4289"},
            {"name": "Marché Pikine", "region": "Dakar", "gps": "14.7550,-17.3900"},
            {"name": "Marché Rufisque", "region": "Dakar", "gps": "14.7136,-17.2758"},
            {"name": "Marché Keur Massar", "region": "Dakar", "gps": "14.7739,-17.3147"},
            {"name": "Marché Mbour", "region": "Thiès", "gps": "14.4136,-16.9595"},
            {"name": "Marché Kaolack", "region": "Kaolack", "gps": "14.1510,-16.0730"},
            {"name": "Marché Louga", "region": "Louga", "gps": "15.6199,-16.2226"},
            {"name": "Marché Tambacounda", "region": "Tambacounda", "gps": "13.7707,-13.6673"},
            {"name": "Marché Kolda", "region": "Kolda", "gps": "12.8905,-14.9405"},
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
                elif market.region == "Diamniadio":
                    base_price *= 1.05 # MIN Diamniadio (Marché de gros national de référence)
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
