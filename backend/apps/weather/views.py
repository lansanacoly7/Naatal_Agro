from rest_framework import viewsets, permissions, response, status
from rest_framework.response import Response
from .models import WeatherData
from .serializers import WeatherDataSerializer
from .services import fetch_weather_for_location

class WeatherViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = WeatherData.objects.all()
    serializer_class = WeatherDataSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def list(self, request, *args, **kwargs):
        location = request.query_params.get('location', None)
        
        if location:
            # Try to fetch fresh data from OpenWeather
            weather_data = fetch_weather_for_location(location)
            if weather_data:
                serializer = self.get_serializer(weather_data)
                return Response([serializer.data])
            else:
                # Fallback to database
                queryset = self.get_queryset().filter(location__icontains=location)
                serializer = self.get_serializer(queryset, many=True)
                return Response(serializer.data)
                
        # If no location, return all
        return super().list(request, *args, **kwargs)
