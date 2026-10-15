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
    privacy_accepted_at = models.DateTimeField(blank=True, null=True, help_text="Date d'acceptation de la politique de confidentialité")
    privacy_policy_version = models.CharField(max_length=20, blank=True, default='', help_text='Version de la politique acceptée')
    
    def __str__(self):
        return f"{self.username} ({self.get_role_display()})"


class OTPToken(models.Model):
    PURPOSE_CHOICES = [
        ('register', 'Inscription'),
        ('password_reset', 'Réinitialisation mot de passe'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(max_length=20)
    code = models.CharField(max_length=6)
    purpose = models.CharField(max_length=30, choices=PURPOSE_CHOICES, default='register')
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['phone', 'purpose', 'is_used']),
        ]

    def __str__(self):
        return f"OTP {self.code} for {self.phone} ({self.purpose})"

    @classmethod
    def generate_code(cls, phone, purpose='register', validity_minutes=15):
        import secrets
        from datetime import timedelta
        from django.utils import timezone
        # 4-digit code (1000 - 9999) pour correspondre au champ 4 chiffres de l'application mobile
        code = str(secrets.randbelow(9000) + 1000)
        expires_at = timezone.now() + timedelta(minutes=validity_minutes)
        # Invalider les anciens codes non utilisés pour ce numéro et ce motif
        cls.objects.filter(phone=phone, purpose=purpose, is_used=False).update(is_used=True)
        return cls.objects.create(
            phone=phone,
            code=code,
            purpose=purpose,
            expires_at=expires_at,
        )

    def is_valid(self):
        from django.utils import timezone
        return not self.is_used and timezone.now() <= self.expires_at
