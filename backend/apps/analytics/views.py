from rest_framework import views, permissions
from rest_framework.response import Response
from apps.agriculture.models import Crop
from apps.markets.models import Price
from apps.weather.models import WeatherData

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

        return Response({
            'agriculture': {
                'active_crops_count': active_crops,
                'total_area_size': total_area,
            },
            'markets': list(latest_prices),
            'weather': weather_summary,
            'alerts': [] # Placeholder for future
        })
