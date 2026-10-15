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

    class Meta:
        ordering = ['name']

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
    product = models.ForeignKey('Product', on_delete=models.SET_NULL, null=True, blank=True, related_name='market_prices')
    product_name = models.CharField(max_length=255)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    trend = models.CharField(max_length=20, choices=TREND_CHOICES, default='stable')
    date = models.DateField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date', 'product_name']
        indexes = [
            models.Index(fields=['market', 'product_name']),
            models.Index(fields=['product', '-date']),
        ]

    def __str__(self):
        return f"{self.product_name} at {self.market.name} - {self.price}"

    def save(self, *args, **kwargs):
        if not self.product_id and self.product_name:
            matching = Product.objects.filter(name__iexact=self.product_name.strip()).first()
            if matching:
                self.product = matching
        super().save(*args, **kwargs)
        if self.product:
            try:
                self.product.sync_live_price()
            except Exception:
                pass


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

    class Meta:
        ordering = ['name']
        indexes = [
            models.Index(fields=['category']),
        ]

    def __str__(self):
        return self.name

    def sync_live_price(self):
        """Met à jour current_price et trend_percentage à partir des cotations réelles enregistrées."""
        from django.db.models import Avg, Q
        latest_prices = Price.objects.filter(
            Q(product=self) | Q(product_name__iexact=self.name)
        ).order_by('-date')
        if not latest_prices.exists():
            return
        
        latest_date = latest_prices.first().date
        avg_latest = latest_prices.filter(date=latest_date).aggregate(Avg('price'))['price__avg']
        if avg_latest is not None:
            self.current_price = round(avg_latest, 2)
            previous_prices = latest_prices.filter(date__lt=latest_date)
            if previous_prices.exists():
                prev_date = previous_prices.first().date
                avg_prev = previous_prices.filter(date=prev_date).aggregate(Avg('price'))['price__avg']
                if avg_prev and avg_prev > 0:
                    diff_pct = ((float(avg_latest) - float(avg_prev)) / float(avg_prev)) * 100
                    self.trend_percentage = round(diff_pct, 1)
            self.save(update_fields=['current_price', 'trend_percentage'])


