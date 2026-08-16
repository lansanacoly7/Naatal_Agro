import uuid
from django.db import models
from django.contrib.auth.models import AbstractUser

class User(AbstractUser):
    ROLE_CHOICES = [
        ('farmer', 'Agriculteur'),
        ('buyer', 'Acheteur B2B'),
    ]

    REGION_CHOICES = [
        ('dakar', 'Dakar'),
        ('thies', 'Thiès'),
        ('saint_louis', 'Saint-Louis'),
        ('kaolack', 'Kaolack'),
        ('ziguinchor', 'Ziguinchor'),
        ('tambacounda', 'Tambacounda'),
        ('kolda', 'Kolda'),
        ('matam', 'Matam'),
        ('kaffrine', 'Kaffrine'),
        ('kedougou', 'Kédougou'),
        ('louga', 'Louga'),
        ('fatick', 'Fatick'),
        ('sedhiou', 'Sédhiou'),
        ('diourbel', 'Diourbel'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(max_length=20, blank=True, null=True)
    location = models.CharField(max_length=255, blank=True, null=True)
    language = models.CharField(max_length=10, default='fr')
    fcm_token = models.CharField(max_length=255, blank=True, null=True, help_text="Firebase Cloud Messaging Token")
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='farmer')
    region = models.CharField(max_length=50, choices=REGION_CHOICES, blank=True, null=True)
    primary_crops = models.JSONField(default=list, blank=True, help_text="Liste des cultures principales (ex: ['riz', 'arachide'])")

    def __str__(self):
        return f"{self.username} ({self.get_role_display()})"
