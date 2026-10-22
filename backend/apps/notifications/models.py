import uuid
from django.db import models
from django.conf import settings
from .firebase_service import send_push_notification

class Notification(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    type = models.CharField(max_length=50) # weather, crop, market, reminder
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    scheduled_for = models.DateTimeField(null=True, blank=True, db_index=True)
    is_sent = models.BooleanField(default=True)
    sent_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True, help_text="Renseigné quand un rappel est annulé avant son échéance")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'is_read']),
            models.Index(fields=['scheduled_for', 'is_sent']),
        ]

    def __str__(self):
        return f"{self.type} for {self.user.username} - Read: {self.is_read}"

    def save(self, *args, **kwargs):
        is_new = self._state.adding
        from django.utils import timezone
        now = timezone.now()

        # Si la notification est planifiée dans le futur, différer l'envoi
        if is_new and self.scheduled_for and self.scheduled_for > now:
            self.is_sent = False
            super().save(*args, **kwargs)
            return

        super().save(*args, **kwargs)
        
        if is_new and self.user.fcm_token:
            # Envoi automatique du push Firebase lors de la création d'une nouvelle notification immédiate
            title = f"Nouvelle alerte : {self.type.capitalize()}"
            send_push_notification(
                fcm_token=self.user.fcm_token,
                title=title,
                body=self.message,
                data={'notification_id': str(self.id), 'type': self.type}
            )
            if not self.is_sent:
                Notification.objects.filter(pk=self.pk).update(is_sent=True, sent_at=now)
