import requests
from django.conf import settings
from datetime import date
from .models import WeatherData

def fetch_weather_for_location(location):
    """
    Fetch weather data from OpenWeatherMap for a given location,
    save it to the database, and return the WeatherData instance.
    """
    if not settings.OPENWEATHER_API_KEY:
        return None

    url = "https://api.openweathermap.org/data/2.5/weather"
    params = {
        'q': location,
        'appid': settings.OPENWEATHER_API_KEY,
        'units': 'metric'
    }

    try:
        response = requests.get(url, params=params)
        if response.status_code == 200:
            data = response.json()
            
            # Extract data
            temp = data['main']['temp']
            humidity = data['main']['humidity']
            # OpenWeather uses 'rain' field for last 1h/3h precipitation, default to 0 if not present
            rainfall = data.get('rain', {}).get('1h', 0.0) 
            
            # Save or update in database
            weather, created = WeatherData.objects.update_or_create(
                location=location.lower(),
                forecast_date=date.today(),
                defaults={
                    'temperature': temp,
                    'humidity': humidity,
                    'rainfall': rainfall,
                }
            )
            return weather
    except Exception as e:
        print(f"Error fetching weather: {e}")
    
    return None
