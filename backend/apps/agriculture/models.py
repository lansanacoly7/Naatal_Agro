import uuid
from django.db import models
from django.conf import settings

class Crop(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='crops')
    name = models.CharField(max_length=255)
    crop_type = models.CharField(max_length=255)
    planting_date = models.DateField()
    expected_harvest_date = models.DateField()
    status = models.CharField(max_length=50, default='active')
    area_size = models.FloatField(help_text="Surface en hectares")
    location = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'status']),
        ]

    def __str__(self):
        return f"{self.name} - {self.user.username}"

class Activity(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    crop = models.ForeignKey(Crop, on_delete=models.CASCADE, related_name='activities')
    activity_type = models.CharField(max_length=255)
    description = models.TextField()
    date = models.DateField()
    cost = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['date']
        indexes = [
            models.Index(fields=['crop', 'date']),
        ]

    def __str__(self):
        return f"{self.activity_type} on {self.crop.name}"

class PestReport(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='pest_reports')
    pest_name = models.CharField(max_length=255)
    location = models.CharField(max_length=255) # ex: "Thiès, Sénégal"
    date_reported = models.DateTimeField(auto_now_add=True)
    description = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ['-date_reported']
        indexes = [
            models.Index(fields=['location', 'date_reported']),
        ]

    def __str__(self):
        return f"{self.pest_name} signalé à {self.location}"

    def save(self, *args, **kwargs):
        is_new = self._state.adding
        super().save(*args, **kwargs)

        if is_new:
            # Check logic for 10 threshold
            from django.utils import timezone
            import datetime
            from apps.notifications.models import Notification
            from django.contrib.auth import get_user_model

            User = get_user_model()
            seven_days_ago = timezone.now() - datetime.timedelta(days=7)
            
            # Count recent reports for same pest and same location
            count = PestReport.objects.filter(
                pest_name__iexact=self.pest_name,
                location__iexact=self.location,
                date_reported__gte=seven_days_ago
            ).count()

            # Seuil de déclenchement d'alerte : à partir de 10 signalements
            if count >= 10:
                one_day_ago = timezone.now() - datetime.timedelta(days=1)
                already_alerted = Notification.objects.filter(
                    type="alert",
                    message__icontains=self.pest_name,
                    created_at__gte=one_day_ago
                ).exists()

                if not already_alerted:
                    target_location = self.location.split(',')[0].strip()
                    users_in_location = User.objects.filter(location__icontains=target_location)
                    for u in users_in_location:
                        Notification.objects.create(
                            user=u,
                            type="alert",
                            message=f"Alerte Maximale : Un foyer de {self.pest_name} a été confirmé près de {self.location}. Veuillez prendre vos précautions."
                        )




class AgronomicGuide(models.Model):
    """
    Fiche technique d'une culture du Sénégal, rédigée uniquement à partir de sources citées.

    Règle de contenu : un champ vide signifie « non documenté par nos sources » (jamais une valeur
    devinée). Les repères [1], [2]… renvoient à la liste ``sources`` de la fiche.
    """
    CATEGORY_CHOICES = [
        ('legume', 'Légume'),
        ('cereale', 'Céréale'),
        ('legumineuse', 'Légumineuse'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    slug = models.SlugField(max_length=80, unique=True)
    name = models.CharField(max_length=120)
    scientific_name = models.CharField(max_length=120, blank=True)
    category = models.CharField(max_length=20, choices=CATEGORY_CHOICES)
    summary = models.TextField()
    zones = models.TextField(blank=True, help_text="Zones de culture au Sénégal")
    cycle_days_min = models.PositiveSmallIntegerField(null=True, blank=True)
    cycle_days_max = models.PositiveSmallIntegerField(null=True, blank=True)
    calendar = models.TextField(blank=True, help_text="Calendrier de semis, repiquage et récolte")
    soil_and_sowing = models.TextField(blank=True, help_text="Sol, préparation, semis, densité")
    water_needs = models.TextField(blank=True)
    fertilization = models.TextField(blank=True)
    pests_diseases = models.JSONField(default=list, blank=True, help_text="Liste de {name, advice}")
    harvest = models.TextField(blank=True)
    yield_info = models.TextField(blank=True)
    limitations = models.TextField(blank=True, help_text="Limites et points à vérifier avant de s'appuyer sur la fiche")
    sources = models.JSONField(default=list, help_text="Liste de {title, publisher, year, url}")
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name
