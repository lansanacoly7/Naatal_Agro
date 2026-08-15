import time
from django.core.management.base import BaseCommand
from apps.weather.models import WeatherData
from apps.weather.services import fetch_weather_for_location
from django.conf import settings
from apps.agriculture.models import Crop

class Command(BaseCommand):
    help = 'Mise à jour des données météo pour les régions des cultures actives'

    def handle(self, *args, **kwargs):
        self.stdout.write("Début de la synchronisation météo...")

        if not getattr(settings, 'OPENWEATHER_API_KEY', None):
            self.stdout.write(self.style.WARNING("ATTENTION: OPENWEATHER_API_KEY n'est pas configurée."))
            self.stdout.write("Génération de données météo fictives (mode dégradé)...")
            # Mode dégradé: si pas de clé, on simule pour que l'app fonctionne.
            from datetime import date
            import random
            today = date.today()
            locations = list(set(Crop.objects.values_list('location', flat=True)))
            if not locations:
                locations = ["Thiès, Sénégal", "Dakar, Sénégal", "Saint-Louis, Sénégal"]
                
            for loc in locations:
                if loc:
                    WeatherData.objects.update_or_create(
                        location=loc.lower(),
                        forecast_date=today,
                        defaults={
                            'temperature': round(random.uniform(22.0, 38.0), 1),
                            'humidity': round(random.uniform(30.0, 80.0), 1),
                            'rainfall': round(random.choice([0.0, 0.0, 0.0, 5.0, 12.0]), 1),
                        }
                    )
            self.stdout.write(self.style.SUCCESS("Météo fictive générée avec succès !"))
            return

        # Vraie récupération depuis l'API
        locations = list(set(Crop.objects.values_list('location', flat=True)))
        if not locations:
            locations = ["Thiès, Sénégal", "Dakar, Sénégal"]

        success_count = 0
        for loc in locations:
            if not loc:
                continue
            
            weather = fetch_weather_for_location(loc)
            if weather:
                success_count += 1
                self.stdout.write(f"Météo mise à jour pour {loc}: {weather.temperature}°C, Humidité: {weather.humidity}%")
            else:
                self.stdout.write(self.style.ERROR(f"Échec de la mise à jour pour {loc}"))
                
            time.sleep(1) # Rate limiting pour les APIs gratuites

        self.stdout.write(self.style.SUCCESS(f"Synchronisation météo terminée. {success_count}/{len(locations)} mises à jour."))
