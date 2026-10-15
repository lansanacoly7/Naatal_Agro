from datetime import timedelta
from rest_framework import views, permissions
from rest_framework.response import Response
from apps.agriculture.models import Crop, Activity
from apps.markets.models import Price, Product
from apps.weather.models import WeatherData
from apps.inventory.models import StockItem
from apps.notifications.models import Notification
from django.db.models import Max, Q, Sum
from django.utils import timezone

def _user_product_names(user):
    """Noms (en minuscules) des produits que l'utilisateur cultive ou suit."""
    names = set()
    for crop_name, crop_type in Crop.objects.filter(user=user).values_list('name', 'crop_type'):
        names.update({(crop_name or '').strip().lower(), (crop_type or '').strip().lower()})
    names.update(str(c).strip().lower() for c in (user.main_crops or []))
    return sorted(n for n in names if len(n) >= 3)


def _prices_for_user_products(user, limit=6):
    """
    Dernier relevé de prix de chaque produit de l'utilisateur : moyenne des marchés à la date
    du relevé le plus récent, avec l'évolution par rapport au relevé d'au moins 7 jours avant.
    Renvoie une liste vide si l'utilisateur ne cultive rien ou si aucun prix n'existe.

    Nombre de requêtes constant (indépendant du nombre de cultures) : une pour les dates, une pour les relevés.
    """
    names = _user_product_names(user)[:12]
    if not names:
        return []
    name_filter = Q()
    for name in names:
        name_filter |= Q(product_name__icontains=name)

    latest_by_product = {
        row['product_name']: row['d']
        for row in Price.objects.filter(name_filter).values('product_name').annotate(d=Max('date'))
    }
    if not latest_by_product:
        return []

    oldest_needed = min(latest_by_product.values()) - timedelta(days=21)
    rows = Price.objects.filter(
        name_filter, product_name__in=list(latest_by_product), date__gte=oldest_needed,
    ).values_list('product_name', 'market_id', 'price', 'date')

    grouped = {}
    for product_name, market_id, price, day in rows:
        grouped.setdefault(product_name, {}).setdefault(day, []).append((market_id, float(price)))

    results = []
    for product_name in sorted(latest_by_product):
        latest = latest_by_product[product_name]
        today_rows = grouped.get(product_name, {}).get(latest, [])
        if not today_rows:
            continue
        prices = [p for _, p in today_rows]
        average = sum(prices) / len(prices)
        older_days = [d for d in grouped[product_name] if d <= latest - timedelta(days=7)]
        change = None
        if older_days:
            older_prices = [p for _, p in grouped[product_name][max(older_days)]]
            older_average = sum(older_prices) / len(older_prices)
            if older_average:
                change = round((average - older_average) / older_average * 100, 1)
        markets_count = len({m for m, _ in today_rows})
        results.append({
            'product_name': product_name,
            'price': round(average, 2),
            'min_price': min(prices),
            'max_price': max(prices),
            'markets_count': markets_count,
            'date': latest.isoformat(),
            'change_percent': change,
            'trend': 'up' if (change or 0) > 1 else 'down' if (change or 0) < -1 else 'stable',
            'market__name': f"{markets_count} marché{'s' if markets_count > 1 else ''}",
        })
        if len(results) >= limit:
            break
    return results


class DashboardView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        user = request.user
        
        # 1. Résumé des cultures (agrégation SQL optimisée)
        active_crops = Crop.objects.filter(user=user, status='active').count()
        total_area = Crop.objects.filter(user=user).aggregate(total=Sum('area_size'))['total'] or 0.0
        
        # 2. Prix des cultures de l'utilisateur (relevés les plus récents, tous marchés confondus)
        latest_prices = _prices_for_user_products(user)

        # 3. Météo de la région de l'utilisateur uniquement (jamais celle d'une autre région)
        weather_summary = {}
        user_region = user.location.split(',')[0].strip() if user.location else ''
        latest_weather = None
        if user_region:
            latest_weather = WeatherData.objects.filter(location__icontains=user_region).order_by('-forecast_date').first()

        if latest_weather:
            weather_summary = {
                'location': latest_weather.location,
                'temp': latest_weather.temperature,
                'humidity': latest_weather.humidity,
                'rainfall': latest_weather.rainfall,
                'date': latest_weather.forecast_date.isoformat(),
            }

        # 4. Éléments en stock de l'utilisateur
        stocks = StockItem.objects.filter(user=user).values(
            'id', 'name', 'quantity', 'unit', 'alert_status', 'ai_storage_advice', 'updated_at'
        )

        # 5. Calendrier des activités agricoles à venir
        today = timezone.now().date()
        upcoming_activities = Activity.objects.filter(crop__user=user, date__gte=today).select_related('crop').order_by('date')[:5]
        calendar_events = []
        for act in upcoming_activities:
            calendar_events.append({
                'title': act.activity_type,
                'description': act.description,
                'date': act.date.strftime("%d\n%b").upper(),
                'phase': act.crop.name
            })

        # 6. Produits tendance en temps réel issus du modèle Product
        trending_products = Product.objects.filter(is_trending=True)[:5]
        if not trending_products.exists():
            trending_products = Product.objects.all()[:5]

        featured_products = [
            {
                'id': str(p.id),
                'name': p.name,
                'category': p.category,
                'price': float(p.current_price),
                'trend_percentage': float(p.trend_percentage),
                'imageAsset': p.image_asset,
            }
            for p in trending_products
        ]

        # 7. Alertes réelles non lues de l'utilisateur
        unread_notifications = Notification.objects.filter(user=user, is_read=False).order_by('-created_at')[:5]
        alerts_list = [
            {
                'id': str(n.id),
                'type': n.type,
                'message': n.message,
                'created_at': n.created_at.isoformat(),
            }
            for n in unread_notifications
        ]

        return Response({
            'agriculture': {
                'active_crops_count': active_crops,
                'total_area_size': float(total_area),
            },
            'markets': latest_prices,
            'weather': weather_summary,
            'alerts': alerts_list,
            'stockItems': list(stocks),
            'calendarEvents': calendar_events,
            'featuredProducts': featured_products
        })

