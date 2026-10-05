import os
import django
import datetime
import random
from django.utils import timezone

# Configuration de Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings.base')
django.setup()

from django.contrib.auth import get_user_model
from apps.agriculture.models import Crop, Activity
from apps.markets.models import Market, Price, PreSaleOffer
from apps.weather.models import WeatherData
from apps.inventory.models import StockItem
from apps.notifications.models import Notification

User = get_user_model()

def run_seed():
    print("Demarrage du script de seed...")

    # 1. Création de l'utilisateur de test Agriculteur
    phone_number = "+221770000000"
    user, created = User.objects.get_or_create(username=phone_number, defaults={
        'phone': phone_number,
        'first_name': 'Lassana',
        'last_name': 'Coly',
        'location': 'Thiès, Sénégal',
        'role': 'farmer',
        'language': 'fr',
        'main_crops': ['Tomate', 'Oignon', 'Arachide']
    })
    
    user.set_password('password123')
    user.first_name = 'Lassana'
    user.last_name = 'Coly'
    user.location = 'Thiès, Sénégal'
    user.role = 'farmer'
    user.language = 'fr'
    user.main_crops = ['Tomate', 'Oignon', 'Arachide']
    user.save()
    print(f"Agriculteur de test configure: {phone_number} / password123")

    # Création de l'utilisateur de test Acheteur B2B
    buyer_phone = "+221780000000"
    buyer, b_created = User.objects.get_or_create(username=buyer_phone, defaults={
        'phone': buyer_phone,
        'first_name': 'Amadou',
        'last_name': 'Diallo',
        'location': 'Dakar, Sénégal',
        'role': 'buyer',
        'language': 'fr'
    })
    buyer.set_password('password123')
    buyer.first_name = 'Amadou'
    buyer.last_name = 'Diallo'
    buyer.location = 'Dakar, Sénégal'
    buyer.role = 'buyer'
    buyer.save()
    print(f"Acheteur B2B de test configure: {buyer_phone} / password123")


    # Nettoyage des anciennes données
    Crop.objects.filter(user=user).delete()
    Market.objects.all().delete()
    WeatherData.objects.all().delete()

    # 2. Création de données Météo
    today = timezone.now().date()
    WeatherData.objects.create(
        location="Thiès, Sénégal",
        temperature=32.5,
        humidity=45.0,
        rainfall=0.0,
        forecast_date=today
    )
    print("Meteo ajoutee")

    # 3. Création des Marchés
    markets_data = [
        {"name": "Marché Castors", "region": "Dakar", "lat": "14.7077", "lng": "-17.4526", "rating": 4.5},
        {"name": "Marché Sandaga", "region": "Dakar", "lat": "14.6698", "lng": "-17.4357", "rating": 4.2},
        {"name": "Marché Tilène", "region": "Dakar", "lat": "14.6853", "lng": "-17.4521", "rating": 4.0},
        {"name": "Marché de Thiaroye", "region": "Dakar", "lat": "14.7570", "lng": "-17.3751", "rating": 3.8},
        {"name": "Marché Central", "region": "Thiès", "lat": "14.7928", "lng": "-16.9267", "rating": 4.3},
    ]

    markets = {}
    for m in markets_data:
        market = Market.objects.create(name=m['name'], region=m['region'], location_gps=f"{m['lat']},{m['lng']}")
        # Simulation d'un rating sur le modele s'il n'existe pas ou utilisation custom coté frontend
        markets[m['name']] = market

    # Ajout de prix (Oignon, Tomate, Riz, Arachide)
    prices_data = [
        # Oignon
        {"market": "Marché Castors", "product": "Oignon", "price": 470.00, "trend": "up"},
        {"market": "Marché Sandaga", "product": "Oignon", "price": 450.00, "trend": "stable"},
        {"market": "Marché Tilène", "product": "Oignon", "price": 435.00, "trend": "down"},
        {"market": "Marché de Thiaroye", "product": "Oignon", "price": 410.00, "trend": "down"},
        {"market": "Marché Central", "product": "Oignon", "price": 400.00, "trend": "stable"},

        # Tomate
        {"market": "Marché Castors", "product": "Tomate", "price": 500.00, "trend": "up"},
        {"market": "Marché Sandaga", "product": "Tomate", "price": 550.00, "trend": "up"},
        {"market": "Marché Tilène", "product": "Tomate", "price": 480.00, "trend": "down"},
        {"market": "Marché de Thiaroye", "product": "Tomate", "price": 450.00, "trend": "down"},
        {"market": "Marché Central", "product": "Tomate", "price": 400.00, "trend": "stable"},

        # Arachide
        {"market": "Marché Castors", "product": "Arachide", "price": 890.00, "trend": "stable"},
        {"market": "Marché Sandaga", "product": "Arachide", "price": 950.00, "trend": "up"},
        {"market": "Marché Tilène", "product": "Arachide", "price": 860.00, "trend": "down"},
        {"market": "Marché de Thiaroye", "product": "Arachide", "price": 800.00, "trend": "down"},
        {"market": "Marché Central", "product": "Arachide", "price": 750.00, "trend": "stable"},

        # Riz
        {"market": "Marché Castors", "product": "Riz", "price": 420.00, "trend": "up"},
        {"market": "Marché Sandaga", "product": "Riz", "price": 450.00, "trend": "up"},
        {"market": "Marché Tilène", "product": "Riz", "price": 400.00, "trend": "stable"},
        {"market": "Marché de Thiaroye", "product": "Riz", "price": 380.00, "trend": "down"},
        {"market": "Marché Central", "product": "Riz", "price": 350.00, "trend": "stable"},
    ]

    for p in prices_data:
        Price.objects.create(
            market=markets[p['market']], 
            product_name=p['product'], 
            price=p['price'], 
            trend=p['trend'], 
            date=today
        )

    print("Marchés et Prix ajoutes")

    # 4. Création des Cultures
    tomato_crop = Crop.objects.create(
        user=user,
        name="Champ de Tomates",
        crop_type="Tomate",
        planting_date=today - datetime.timedelta(days=30),
        expected_harvest_date=today + datetime.timedelta(days=60),
        status="active",
        area_size=1.5,
        location="Thiès Nord"
    )

    rice_crop = Crop.objects.create(
        user=user,
        name="Riziculture",
        crop_type="Riz",
        planting_date=today - datetime.timedelta(days=10),
        expected_harvest_date=today + datetime.timedelta(days=120),
        status="attention",
        area_size=3.0,
        location="Vallée du Fleuve"
    )
    print("Cultures ajoutees")

    # 5. Création d'activités
    Activity.objects.create(
        crop=tomato_crop,
        activity_type="Arrosage",
        description="Arrosage complet du champ",
        date=today,
        cost=5000.00
    )
    Activity.objects.create(
        crop=tomato_crop,
        activity_type="Engrais",
        description="Application NPK",
        date=today - datetime.timedelta(days=5),
        cost=15000.00
    )
    print("Activites agricoles ajoutees")

    # 6. Création des Stocks
    StockItem.objects.filter(user=user).delete()
    StockItem.objects.create(
        user=user,
        name="Oignon Local (Sacs 25kg)",
        quantity=120.0,
        unit="Sacs",
        alert_status=False,
        ai_storage_advice="Conserver dans un endroit sec, ventilé et à l'abri de l'humidité du sol."
    )
    StockItem.objects.create(
        user=user,
        name="Arachide Décortiquée",
        quantity=45.0,
        unit="Sacs",
        alert_status=True,
        ai_storage_advice="Risque de charançons. Inspecter les sacs et aérer le local de stockage."
    )
    print("Stocks ajoutes")

    # 7. Création de Notifications Réelles
    Notification.objects.filter(user=user).delete()
    Notification.objects.create(
        user=user,
        type="market",
        message="Le cours de l'oignon local est en hausse de +5% sur le Marché Castors. Opportunité de vente favorable.",
        is_read=False
    )
    Notification.objects.create(
        user=user,
        type="weather",
        message="Alerte Météo : Fortes chaleurs prévues à Thiès (35°C). Pensez à irriguer tôt le matin.",
        is_read=False
    )
    print("Notifications ajoutees")

    # 8. Création d'une Offre de Pré-vente B2B
    PreSaleOffer.objects.filter(farmer=user).delete()
    PreSaleOffer.objects.create(
        farmer=user,
        product_name="Tomate Fraîche",
        quantity_kg=500.0,
        price_per_kg=400.0,
        availability_date=today + datetime.timedelta(days=20),
        location="Thiès Nord",
        status="open"
    )
    print("Offre B2B ajoutee")

    print("\nSeed termine avec succes !")
    print("=========================================")
    print("Comptes de test disponibles :")
    print(f"1. Agriculteur : {phone_number} / password123")
    print(f"2. Acheteur B2B: {buyer_phone} / password123")
    print("=========================================")

if __name__ == '__main__':
    run_seed()

