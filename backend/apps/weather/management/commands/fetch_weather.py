import time

from django.core.management.base import BaseCommand

from apps.agriculture.models import Crop
from apps.weather.services import (
    AmbiguousPlace,
    OutsideSenegal,
    UnknownPlace,
    WeatherUnavailable,
    weather_for_place,
)


class Command(BaseCommand):
    help = (
        "Relève la météo réelle (Open-Meteo) des lieux où les agriculteurs ont des cultures et l'enregistre. "
        "Aucune valeur n'est jamais inventée : un lieu sans réponse est simplement signalé."
    )

    def handle(self, *args, **kwargs):
        locations = sorted({loc.strip() for loc in Crop.objects.values_list('location', flat=True) if loc and loc.strip()})
        if not locations:
            self.stdout.write('Aucune culture avec un lieu : rien à relever.')
            return

        done = 0
        for location in locations:
            try:
                report = weather_for_place(location)
            except AmbiguousPlace:
                self.stdout.write(self.style.WARNING(f'{location} : plusieurs lieux portent ce nom, précisez la région (ex. « {location}, Dakar »).'))
            except (UnknownPlace, OutsideSenegal) as exc:
                self.stdout.write(self.style.WARNING(f'{location} : {exc}'))
            except WeatherUnavailable:
                self.stdout.write(self.style.ERROR(f'{location} : la source météo ne répond pas.'))
            else:
                done += 1
                current = report['current']
                self.stdout.write(f"{location} : {current['temperature']} °C, humidité {current['humidity']} %")
            time.sleep(0.5)  # on ménage la source gratuite

        self.stdout.write(self.style.SUCCESS(f'Météo relevée pour {done} lieu(x) sur {len(locations)}.'))
