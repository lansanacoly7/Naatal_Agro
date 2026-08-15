import uuid
from django.db import models
from django.conf import settings
from apps.agriculture.models import Crop

class Sale(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    crop = models.ForeignKey(Crop, on_delete=models.CASCADE, related_name='sales')
    quantity_sold = models.FloatField(help_text="Quantité vendue")
    price_per_unit = models.DecimalField(max_digits=10, decimal_places=2)
    date = models.DateField()
    buyer = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def total_revenue(self):
        return float(self.quantity_sold) * float(self.price_per_unit)

    def __str__(self):
        return f"Vente de {self.crop.name} - {self.total_revenue} CFA"

class Transaction(models.Model):
    TRANSACTION_TYPES = [
        ('income', 'Revenu'),
        ('expense', 'Dépense')
    ]
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='transactions')
    transaction_type = models.CharField(max_length=20, choices=TRANSACTION_TYPES)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    date = models.DateField()
    description = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.get_transaction_type_display()} : {self.amount} ({self.date})"
