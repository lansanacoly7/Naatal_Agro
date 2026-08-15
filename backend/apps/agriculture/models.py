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

    def __str__(self):
        return f"{self.activity_type} on {self.crop.name}"

class PestReport(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='pest_reports')
    pest_name = models.CharField(max_length=255)
    location = models.CharField(max_length=255) # ex: "Thiès, Sénégal"
    date_reported = models.DateTimeField(auto_now_add=True)
    description = models.TextField(blank=True, null=True)

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

            # Threshold is 10
            if count == 10:
                # Send alert to all users in this location
                users_in_location = User.objects.filter(location__iexact=self.location)
                for u in users_in_location:
                    Notification.objects.create(
                        user=u,
                        type="alert",
                        message=f"Alerte Maximale : Un foyer de {self.pest_name} a été confirmé près de {self.location}. Veuillez prendre vos précautions."
                    )

