import os
import django
import datetime
from django.utils import timezone

# Configuration de Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings.base')
django.setup()

from django.contrib.auth import get_user_model
from apps.agriculture.models import Crop, Activity
from apps.markets.models import Market, Price
from apps.weather.models import WeatherData

User = get_user_model()

def run_seed():
    print("Demarrage du script de seed...")

    # 1. Création de l'utilisateur de test
    phone_number = "+221770000000"
    user, created = User.objects.get_or_create(username=phone_number, defaults={
        'phone': phone_number,
        'first_name': 'Lass',
        'last_name': 'Test',
        'location': 'Thiès, Sénégal'
    })
    
    if created:
        user.set_password('password123')
        user.save()
        print(f"Utilisateur de test cree: {phone_number} / password123")
    else:
        print(f"Utilisateur de test deja existant: {phone_number}")

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
    dakar_market = Market.objects.create(name="Marché Castors", region="Dakar", location_gps="14.7077,-17.4526")
    thies_market = Market.objects.create(name="Marché Central", region="Thiès", location_gps="14.7928,-16.9267")
    
    # Prix des marchés
    Price.objects.create(market=dakar_market, product_name="Tomate", price=450.00, trend="up", date=today)
    Price.objects.create(market=dakar_market, product_name="Oignon", price=300.00, trend="down", date=today)
    Price.objects.create(market=thies_market, product_name="Tomate", price=400.00, trend="stable", date=today)
    Price.objects.create(market=thies_market, product_name="Oignon", price=250.00, trend="up", date=today)
    print("Marches et Prix ajoutes")

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

    print("\nSeed termine avec succes !")
    print("=========================================")
    print("Identifiants de test :")
    print(f"Téléphone : {phone_number}")
    print("Mot de passe : password123")
    print("=========================================")

if __name__ == '__main__':
    run_seed()
