import argparse
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings.local')
django.setup()

from apps.markets.models import Product

def populate(assume_yes=False):
    from core.safety import require_safe_to_erase
    require_safe_to_erase("remise a zero du catalogue de produits (efface tous les produits et leurs cotations liees)",
                          assume_yes=assume_yes)
    Product.objects.all().delete()

    products = [
        # Tendances
        {"name": "Oignon Local", "category": "LÉGUME", "price": 400, "trend": -3.0, "is_trending": True, "image": "assets/images/products/oignon_local.png"},
        {"name": "Arachide Décortiquée", "category": "CÉRÉALE", "price": 600, "trend": 0.0, "is_trending": True, "image": "assets/images/products/arachide_decortiquee.png"},
        
        # Tous les produits
        {"name": "Pomme de Terre", "category": "LÉGUME", "price": 500, "trend": -3.0, "is_trending": False, "image": "assets/images/products/pomme_de_terre.png"},
        {"name": "Pastèque", "category": "FRUIT", "price": 1500, "trend": -5.0, "is_trending": False, "image": "assets/images/products/pasteque.png"},
        {"name": "Chou", "category": "LÉGUME", "price": 400, "trend": 0.0, "is_trending": False, "image": "assets/images/products/chou.png"},
        {"name": "Tomate", "category": "LÉGUME", "price": 600, "trend": 18.0, "is_trending": False, "image": "assets/images/products/tomate.png"},
        {"name": "Aubergine", "category": "LÉGUME", "price": 700, "trend": 0.0, "is_trending": False, "image": "assets/images/products/aubergine.png"},
        {"name": "Papaye", "category": "FRUIT", "price": 800, "trend": -2.0, "is_trending": False, "image": "assets/images/products/papaye.png"},
        {"name": "Mangue", "category": "FRUIT", "price": 300, "trend": -10.0, "is_trending": False, "image": "assets/images/products/mangue.png"},
        {"name": "Niébé", "category": "CÉRÉALE", "price": 900, "trend": 0.0, "is_trending": False, "image": "assets/images/products/niebe.png"},
    ]

    for p in products:
        Product.objects.create(
            name=p['name'],
            category=p['category'],
            current_price=p['price'],
            trend_percentage=p['trend'],
            is_trending=p['is_trending'],
            image_asset=p['image']
        )
    print("Produits ajoutés avec succès !")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Catalogue de produits (developpement uniquement).")
    parser.add_argument('--yes', action='store_true', help="ne pas demander de confirmation")
    populate(assume_yes=parser.parse_args().yes)
