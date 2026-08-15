from rest_framework import views, permissions
from rest_framework.response import Response
from apps.agriculture.models import Crop, Activity
from apps.markets.models import Price
from apps.weather.models import WeatherData
from apps.inventory.models import StockItem
from django.utils import timezone

class DashboardView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        user = request.user
        
        # 1. Crops summary
        active_crops = Crop.objects.filter(user=user, status='active').count()
        total_area = sum(c.area_size for c in Crop.objects.filter(user=user))
        
        # 2. Latest market prices (last 5)
        latest_prices = Price.objects.order_by('-date')[:5].values(
            'product_name', 'price', 'trend', 'market__name'
        )
        
        # 3. Weather for user location if available, else a default
        weather_summary = {}
        latest_weather = WeatherData.objects.order_by('-forecast_date').first()
        if latest_weather:
            weather_summary = {
                'location': latest_weather.location,
                'temp': latest_weather.temperature,
                'humidity': latest_weather.humidity,
                'rainfall': latest_weather.rainfall
            }

        # 4. Stock Items
        stocks = StockItem.objects.filter(user=user).values(
            'name', 'quantity', 'unit', 'alert_status', 'ai_storage_advice'
        )

        # 5. Calendar Events (Upcoming activities)
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

        # 6. Featured Products (Top trending in market)
        # Mocking logic for trending products for now, using latest distinct prices
        featured_products = [
            {'name': 'Oignon', 'variety': 'Violet de Galmi', 'imageAsset': 'assets/images/products/oignon.png'},
            {'name': 'Mil', 'variety': 'Souna', 'imageAsset': 'assets/images/products/mil.png'},
            {'name': 'Arachide', 'variety': 'Fleur 11', 'imageAsset': 'assets/images/products/arachide.png'},
        ]

        return Response({
            'agriculture': {
                'active_crops_count': active_crops,
                'total_area_size': total_area,
            },
            'markets': list(latest_prices),
            'weather': weather_summary,
            'alerts': [],
            'stockItems': list(stocks),
            'calendarEvents': calendar_events,
            'featuredProducts': featured_products
        })
