import uuid
from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    ROLE_CHOICES = [
        ('farmer', 'Agriculteur'),
        ('admin', 'Administrateur'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(max_length=20, blank=True, null=True)
    location = models.CharField(max_length=255, blank=True, null=True)
    language = models.CharField(max_length=10, default='fr')
    fcm_token = models.CharField(max_length=255, blank=True, null=True, help_text="Firebase Cloud Messaging Token")
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='farmer')
    date_of_birth = models.DateField(blank=True, null=True)
    main_crops = models.JSONField(blank=True, null=True, default=list)
    
    def __str__(self):
        return f"{self.username} ({self.get_role_display()})"
