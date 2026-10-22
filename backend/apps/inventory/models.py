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

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.name} - {self.quantity} {self.unit} ({self.user.username})"


class StockMovement(models.Model):
    """
    Journal des mouvements d'un article de stock : chaque variation de quantité est tracée avec son motif,
    ce qui permet de répondre à « d'où vient ce stock ? » et de vérifier que les soldes sont cohérents.
    """
    TYPE_CHOICES = [('in', 'Entrée'), ('out', 'Sortie'), ('adjustment', 'Correction')]
    REASON_CHOICES = [
        ('initial', 'Stock initial'),
        ('purchase', 'Achat / réception'),
        ('harvest', 'Récolte'),
        ('sale', 'Vente'),
        ('sale_reversal', 'Vente annulée'),
        ('manual', 'Saisie manuelle'),
        ('correction', 'Correction'),
        ('removed', 'Article supprimé'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='stock_movements')
    stock_item = models.ForeignKey(StockItem, null=True, blank=True, on_delete=models.SET_NULL, related_name='movements')
    product_name = models.CharField(max_length=255, help_text="Nom de l'article au moment du mouvement")
    movement_type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    quantity = models.FloatField(help_text="Quantité déplacée (toujours positive) ; pour une correction, écart absolu")
    unit = models.CharField(max_length=50)
    balance_after = models.FloatField(help_text="Quantité en stock après le mouvement")
    reason = models.CharField(max_length=30, choices=REASON_CHOICES)
    note = models.CharField(max_length=255, blank=True, default='')
    sale = models.ForeignKey('finances.Sale', null=True, blank=True, on_delete=models.SET_NULL, related_name='stock_movements')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['stock_item', '-created_at']),
        ]

    def __str__(self):
        return f"{self.get_movement_type_display()} {self.quantity:g} {self.unit} de {self.product_name}"
