import uuid
from django.db import models

class Market(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    location_gps = models.CharField(max_length=255, blank=True, null=True)
    region = models.CharField(max_length=255)
    rating = models.DecimalField(max_digits=3, decimal_places=1, default=4.5)
    opening_time = models.TimeField(default='08:00:00')
    closing_time = models.TimeField(default='18:00:00')

    def __str__(self):
        return self.name

class Price(models.Model):
    TREND_CHOICES = [
        ('up', 'Up'),
        ('down', 'Down'),
        ('stable', 'Stable'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    market = models.ForeignKey(Market, on_delete=models.CASCADE, related_name='prices')
    product_name = models.CharField(max_length=255)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    trend = models.CharField(max_length=20, choices=TREND_CHOICES, default='stable')
    date = models.DateField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.product_name} at {self.market.name} - {self.price}"

class Product(models.Model):
    CATEGORY_CHOICES = [
        ('LÉGUME', 'Légume'),
        ('FRUIT', 'Fruit'),
        ('CÉRÉALE', 'Céréale'),
        ('TUBERCULE', 'Tubercule'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    category = models.CharField(max_length=50, choices=CATEGORY_CHOICES)
    current_price = models.DecimalField(max_digits=10, decimal_places=2)
    trend_percentage = models.DecimalField(max_digits=5, decimal_places=2, default=0.0)
    image_asset = models.CharField(max_length=255)
    is_trending = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

