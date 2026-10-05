from rest_framework import views, permissions
from rest_framework.response import Response
from apps.agriculture.models import Crop, Activity
from apps.markets.models import Price, Product
from apps.weather.models import WeatherData
from apps.inventory.models import StockItem
from apps.notifications.models import Notification
from django.db.models import Sum
from django.utils import timezone

class DashboardView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        user = request.user
        
        # 1. Résumé des cultures (agrégation SQL optimisée)
        active_crops = Crop.objects.filter(user=user, status='active').count()
        total_area = Crop.objects.filter(user=user).aggregate(total=Sum('area_size'))['total'] or 0.0
        
        # 2. Dernières cotations de prix des marchés
        latest_prices = Price.objects.order_by('-date')[:5].values(
            'product_name', 'price', 'trend', 'market__name'
        )
        
        # 3. Météo géolocalisée selon la région de l'utilisateur ou la plus récente
        weather_summary = {}
        user_region = user.location.split(',')[0].strip() if user.location else ''
        latest_weather = None
        if user_region:
            latest_weather = WeatherData.objects.filter(location__icontains=user_region).order_by('-forecast_date').first()
        if not latest_weather:
            latest_weather = WeatherData.objects.order_by('-forecast_date').first()

        if latest_weather:
            weather_summary = {
                'location': latest_weather.location,
                'temp': latest_weather.temperature,
                'humidity': latest_weather.humidity,
                'rainfall': latest_weather.rainfall
            }

        # 4. Éléments en stock de l'utilisateur
        stocks = StockItem.objects.filter(user=user).values(
            'id', 'name', 'quantity', 'unit', 'alert_status', 'ai_storage_advice', 'updated_at'
        )

        # 5. Calendrier des activités agricoles à venir
        today = timezone.now().date()
        upcoming_activities = Activity.objects.filter(crop__user=user, date__gte=today).order_by('date')[:5]
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
            'markets': list(latest_prices),
            'weather': weather_summary,
            'alerts': alerts_list,
            'stockItems': list(stocks),
            'calendarEvents': calendar_events,
            'featuredProducts': featured_products
        })

