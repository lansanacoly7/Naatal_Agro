from django.contrib import admin

from .models import WeatherData


@admin.register(WeatherData)
class WeatherDataAdmin(admin.ModelAdmin):
    list_display = ('location', 'temperature', 'humidity', 'rainfall', 'forecast_date')
    list_filter = ('location', 'forecast_date')
    search_fields = ('location',)
    date_hierarchy = 'forecast_date'
