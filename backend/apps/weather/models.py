import uuid
from django.db import models

class WeatherData(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    location = models.CharField(max_length=255)
    temperature = models.FloatField()
    humidity = models.FloatField()
    rainfall = models.FloatField(help_text="Précipitations en mm")
    forecast_date = models.DateField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = "Weather data"

    def __str__(self):
        return f"Weather in {self.location} on {self.forecast_date}"
