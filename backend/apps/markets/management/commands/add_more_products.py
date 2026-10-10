from django.core.management.base import BaseCommand
from apps.markets.models import Product

# (nom, catégorie, prix FCFA/kg indicatif)
PRODUCTS = [
    ("Riz", "CÉRÉALE", 450), ("Mil", "CÉRÉALE", 350), ("Maïs", "CÉRÉALE", 300),
    ("Sorgho", "CÉRÉALE", 320), ("Fonio", "CÉRÉALE", 800),
    ("Manioc", "TUBERCULE", 250), ("Patate douce", "TUBERCULE", 400),
    ("Igname", "TUBERCULE", 500), ("Carotte", "LÉGUME", 500), ("Piment", "LÉGUME", 1500),
    ("Gombo", "LÉGUME", 900), ("Poivron", "LÉGUME", 1000), ("Concombre", "LÉGUME", 450),
    ("Haricot vert", "LÉGUME", 1100), ("Laitue", "LÉGUME", 600), ("Ail", "LÉGUME", 2500),
    ("Betterave", "LÉGUME", 500), ("Courge", "LÉGUME", 350), ("Navet", "LÉGUME", 450),
    ("Citron", "FRUIT", 900), ("Orange", "FRUIT", 700), ("Banane", "FRUIT", 600),
    ("Melon", "FRUIT", 500), ("Papaye", "FRUIT", 450), ("Ananas", "FRUIT", 800),
    ("Goyave", "FRUIT", 700),
]


class Command(BaseCommand):
    help = "Ajoute des produits agricoles supplémentaires (idempotent)"

    def handle(self, *args, **kwargs):
        n = 0
        for name, cat, price in PRODUCTS:
            _, created = Product.objects.get_or_create(
                name=name,
                defaults={"category": cat, "current_price": price, "trend_percentage": 0,
                          "image_asset": "", "is_trending": False},
            )
            n += created
        self.stdout.write(self.style.SUCCESS(f"{n} produits ajoutés"))
