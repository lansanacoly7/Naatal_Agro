import uuid
from django.db import models
from django.conf import settings

class StockItem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='inventory')
    name = models.CharField(max_length=255)
    quantity = models.FloatField()
    unit = models.CharField(max_length=50) # kg, tonnes, sacs...
    alert_status = models.BooleanField(default=False)
    ai_storage_advice = models.TextField(blank=True, null=True, help_text="Conseils générés par l'IA")
    updated_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} - {self.quantity} {self.unit} ({self.user.username})"
