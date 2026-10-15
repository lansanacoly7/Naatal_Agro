import datetime
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.contrib.auth import get_user_model
from django.utils import timezone

from apps.agriculture.models import Crop, Activity, Harvest, AgronomicGuide
from apps.inventory.models import StockItem
from apps.finances.models import Sale, Transaction
from apps.weather.models import WeatherData
from apps.notifications.models import Notification
from apps.markets.models import Market, Price

User = get_user_model()

DEMO_PHONE = "+221770000000"
DEMO_PASS = "DemoSenegal2026#"

class Command(BaseCommand):
    help = "Initialise un compte exploitant de démonstration centré sur Diamniadio pour la soutenance."

    def add_arguments(self, parser):
        parser.add_argument('--force', action='store_true', help="Autorise l'execution hors mode debug (jamais sur une base de production).")

    def handle(self, *args, **options):
        if not (settings.DEBUG or settings.OTP_DEMO_MODE or options['force']):
            raise CommandError("Ce compte contient des donnees FICTIVES : refuse hors DEBUG/OTP_DEMO_MODE (utilisez --force sur une base de demonstration).")
        self.stdout.write(self.style.NOTICE("[DEMO] Initialisation de l'ecosysteme de demonstration - Zone Diamniadio..."))

        # 1. Nettoyage de l'ancien compte démo s'il existe
        old_user = User.objects.filter(username=DEMO_PHONE).first()
        if old_user:
            old_user.delete()
            self.stdout.write("  - Ancien compte demo purge.")

        # 2. Création de l'utilisateur modèle à Diamniadio
        user = User.objects.create_user(
            username=DEMO_PHONE,
            phone=DEMO_PHONE,
            password=DEMO_PASS,
            first_name="Ousmane",
            last_name="Ndiaye",
            role="farmer",
            location="Diamniadio, Dakar, Sénégal",
            language="fr",
            email="ousmane.ndiaye@naatalagro.sn",
            date_of_birth=datetime.date(1985, 4, 12),
            main_crops=["Oignon", "Tomate", "Arachide"],
            privacy_accepted_at=timezone.now(),
            privacy_policy_version="1.0"
        )
        self.stdout.write(self.style.SUCCESS(f"  [OK] Exploitant cree : {user.first_name} {user.last_name} a Diamniadio ({DEMO_PHONE})"))

        # 3. Récupération des guides officiels ISRA
        guide_oignon = AgronomicGuide.objects.filter(slug='oignon').first()
        guide_tomate = AgronomicGuide.objects.filter(slug__in=['tomate', 'tomate-industrielle']).first()
        guide_arachide = AgronomicGuide.objects.filter(slug='arachide').first()

        today = datetime.date.today()

        # 4. Cultures à Diamniadio (Zone agro-urbaine et Niayes-Sud)
        # Culture 1 : Oignon Local (Niayes) — Active
        crop_oignon = Crop.objects.create(
            user=user,
            name="Oignon Local (Niayes)",
            crop_type="Oignon",
            area_size=1.5,
            location="Diamniadio (Pôle Agro-Urbain)",
            planting_date=today - datetime.timedelta(days=40),
            expected_harvest_date=today + datetime.timedelta(days=50),
            status="active",
            guide=guide_oignon
        )
        Activity.objects.create(
            crop=crop_oignon,
            activity_type="Semis et Repiquage",
            description="Mise en place des planches et repiquage des bulbilles d'oignon",
            date=today - datetime.timedelta(days=38),
            cost=25000.0
        )
        Activity.objects.create(
            crop=crop_oignon,
            activity_type="Sarclage et Binage",
            description="Élimination des adventices et aération du sol sablo-limoneux",
            date=today - datetime.timedelta(days=20),
            cost=15000.0
        )
        Activity.objects.create(
            crop=crop_oignon,
            activity_type="Fertilisation organique",
            description="Apport de compost décomposé et fumure de fond",
            date=today - datetime.timedelta(days=5),
            cost=20000.0
        )

        # Culture 2 : Tomate Maraîchère — Active
        crop_tomate = Crop.objects.create(
            user=user,
            name="Tomate Maraîchère",
            crop_type="Tomate",
            area_size=1.0,
            location="Diamniadio (Sébikotane / Niayes Sud)",
            planting_date=today - datetime.timedelta(days=25),
            expected_harvest_date=today + datetime.timedelta(days=55),
            status="active",
            guide=guide_tomate
        )
        Activity.objects.create(
            crop=crop_tomate,
            activity_type="Plantation et Tuteurage",
            description="Repiquage des plants de tomates et mise en place des tuteurs",
            date=today - datetime.timedelta(days=22),
            cost=18000.0
        )
        Activity.objects.create(
            crop=crop_tomate,
            activity_type="Irrigation goutte-à-goutte",
            description="Entretien du réseau d'irrigation et fertigation raisonnée",
            date=today - datetime.timedelta(days=10),
            cost=12000.0
        )

        # Culture 3 : Arachide 73-33 — Récoltée
        crop_arachide = Crop.objects.create(
            user=user,
            name="Arachide 73-33",
            crop_type="Arachide",
            area_size=1.0,
            location="Diamniadio (Zone Rurale Est)",
            planting_date=today - datetime.timedelta(days=110),
            expected_harvest_date=today - datetime.timedelta(days=15),
            status="harvested",
            guide=guide_arachide
        )
        Harvest.objects.create(
            user=user,
            crop=crop_arachide,
            quantity=1200.0,
            unit="kg",
            date=today - datetime.timedelta(days=15),
            notes="Excellente récolte en gousses bien remplies, séchage effectué sur meules."
        )

        self.stdout.write(self.style.SUCCESS("  [OK] 3 parcelles creees a Diamniadio (2 actives, 1 recoltee) avec activites et recolte."))

        # 5. Inventaire & Stock
        StockItem.objects.create(
            user=user,
            name="Arachide",
            quantity=800.0,
            unit="kg",
            alert_status=False,
            ai_storage_advice="Conserver les gousses dans un endroit sec, à l'abri des rongeurs et de l'humidité pour éviter les moisissures et l'aflatoxine."
        )
        StockItem.objects.create(
            user=user,
            name="Oignon Local (Niayes)",
            quantity=500.0,
            unit="kg",
            alert_status=False,
            ai_storage_advice="Stocker dans un hangar ombragé et très aéré sur des claies surélevées pour maximiser la durée de conservation marchande."
        )
        self.stdout.write(self.style.SUCCESS("  [OK] Stocks d'inventaire initialises avec conseils de stockage IA."))

        # 6. Marché d'Intérêt National (MIN) de Diamniadio & Cotations
        market_min, _ = Market.objects.update_or_create(
            name="Marché d'Intérêt National (MIN) de Diamniadio",
            defaults={
                "region": "Diamniadio",
                "location_gps": "14.7214,-17.1852",
                "rating": 4.8
            }
        )
        Price.objects.update_or_create(
            market=market_min,
            product_name="Oignon",
            date=today,
            defaults={"price": 480.00, "trend": "up"}
        )
        Price.objects.update_or_create(
            market=market_min,
            product_name="Tomate",
            date=today,
            defaults={"price": 520.00, "trend": "up"}
        )
        Price.objects.update_or_create(
            market=market_min,
            product_name="Arachide",
            date=today,
            defaults={"price": 910.00, "trend": "up"}
        )
        self.stdout.write(self.style.SUCCESS("  [OK] Marche d'Interet National (MIN) de Diamniadio synchronise avec cotations en direct."))

        # Historique de 30 jours : le compte de demo montre les courbes de prix (valeurs fictives, deterministes).
        demo_markets = [market_min] + list(Market.objects.exclude(pk=market_min.pk)[:2])
        base_prices = {"Oignon": 480.0, "Tomate": 520.0, "Arachide": 910.0}
        for m_index, market in enumerate(demo_markets):
            for name, base in base_prices.items():
                for back in range(30, 0, -1):
                    wave = ((back * 7 + m_index * 3 + len(name)) % 11 - 5) * 0.012
                    Price.objects.update_or_create(
                        market=market, product_name=name, date=today - datetime.timedelta(days=back),
                        defaults={"price": round(base * (1 + wave + m_index * 0.03), 2), "trend": "stable"},
                    )
        self.stdout.write(self.style.SUCCESS(f"  [OK] Historique de prix fictif sur 30 jours ({len(demo_markets)} marches)."))

        # 7. Ventes & Finances (Vente vers la Centrale d'Achat du MIN)
        # Vente de 400 kg d'arachide au MIN (sur les 1200 kg récoltés, reste 800 kg en stock)
        sale = Sale.objects.create(
            user=user,
            crop=crop_arachide,
            product_name="Arachide 73-33",
            quantity_sold=400.0,
            price_per_unit=600.0,
            date=today - datetime.timedelta(days=10),
            buyer="Centrale d'Achat - MIN de Diamniadio"
        )
        Transaction.objects.create(
            user=user,
            transaction_type="income",
            amount=sale.total_revenue,  # 240 000 FCFA
            date=sale.date,
            description="Vente de Arachide 73-33 au MIN de Diamniadio (400.0 kg)",
            sale=sale
        )

        # Dépenses d'exploitation à Diamniadio
        Transaction.objects.create(
            user=user,
            transaction_type="expense",
            amount=45000.0,
            date=today - datetime.timedelta(days=45),
            description="Achat de semences certifiées d'oignon et d'arachide (ISRA)"
        )
        Transaction.objects.create(
            user=user,
            transaction_type="expense",
            amount=30000.0,
            date=today - datetime.timedelta(days=42),
            description="Préparation du sol, labour motorisé et confection des planches à Diamniadio"
        )
        self.stdout.write(self.style.SUCCESS("  [OK] Transactions financieres creees (Recettes: 240 000 F, Depenses: 75 000 F, Solde: +165 000 F)."))

        # 8. Données Météo pour le Pôle de Diamniadio
        WeatherData.objects.update_or_create(
            location="Diamniadio",
            forecast_date=today,
            defaults={
                "temperature": 29.5,
                "humidity": 65.0,
                "rainfall": 0.0
            }
        )
        self.stdout.write(self.style.SUCCESS("  [OK] Meteo geolocalisee a jour pour Diamniadio (29.5 C, 65% humidite)."))

        # 9. Notifications contextuelles
        Notification.objects.create(
            user=user,
            type="harvest",
            message="Récolte de 1 200 kg d'Arachide 73-33 enregistrée avec succès dans votre stock.",
            is_read=False
        )
        Notification.objects.create(
            user=user,
            type="market",
            message="Cotation MIN Diamniadio : l'oignon local atteint 650 FCFA/kg au Marché d'Intérêt National (+8%).",
            is_read=False
        )
        Notification.objects.create(
            user=user,
            type="weather",
            message="Bulletin Météo Diamniadio : Ciel dégagé et brise marine favorable aux cultures maraîchères cette semaine.",
            is_read=True
        )
        self.stdout.write(self.style.SUCCESS("  [OK] Notifications de demonstration generees pour Diamniadio."))

        self.stdout.write("")
        self.stdout.write(self.style.SUCCESS("==========================================================="))
        self.stdout.write(self.style.SUCCESS("*** DEMO OPERATIONNELLE - PERIMETRE : DIAMNIADIO ***"))
        self.stdout.write(self.style.SUCCESS(f"   Identifiant (Telephone) : {DEMO_PHONE}"))
        self.stdout.write(self.style.SUCCESS(f"   Mot de passe            : {DEMO_PASS}"))
        self.stdout.write(self.style.SUCCESS(f"   Exploitant              : Ousmane Ndiaye (Diamniadio)"))
        self.stdout.write(self.style.SUCCESS(f"   Hub commercial          : MIN de Diamniadio (14.7214, -17.1852)"))
        self.stdout.write(self.style.SUCCESS("==========================================================="))
