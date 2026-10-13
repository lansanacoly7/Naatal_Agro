import uuid
from django.db import models
from django.conf import settings
from apps.agriculture.models import Crop

class Sale(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='sales', null=True, blank=True)
    crop = models.ForeignKey(Crop, on_delete=models.SET_NULL, null=True, blank=True, related_name='sales')
    product_name = models.CharField(max_length=255, blank=True, default='')
    quantity_sold = models.FloatField(help_text="Quantité vendue")
    price_per_unit = models.DecimalField(max_digits=10, decimal_places=2)
    date = models.DateField()
    buyer = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def total_revenue(self):
        return float(self.quantity_sold) * float(self.price_per_unit)

    class Meta:
        ordering = ['-date', '-created_at']
        indexes = [
            models.Index(fields=['user', 'date']),
            models.Index(fields=['crop', 'date']),
        ]

    def save(self, *args, **kwargs):
        if not self.user and self.crop and hasattr(self.crop, 'user'):
            self.user = self.crop.user
        super().save(*args, **kwargs)

    def __str__(self):
        name = self.crop.name if self.crop else (self.product_name or "Produit")
        return f"Vente de {name} - {self.total_revenue} CFA"

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
    activity = models.OneToOneField('agriculture.Activity', null=True, blank=True, on_delete=models.CASCADE, related_name='transaction')
    sale = models.OneToOneField('finances.Sale', null=True, blank=True, on_delete=models.CASCADE, related_name='transaction')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date', '-created_at']
        indexes = [
            models.Index(fields=['user', 'transaction_type']),
        ]

    def __str__(self):
        return f"{self.get_transaction_type_display()} : {self.amount} ({self.date})"
