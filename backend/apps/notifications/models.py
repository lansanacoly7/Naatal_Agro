import uuid
from django.db import models
from django.conf import settings
from .firebase_service import send_push_notification

class Notification(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    type = models.CharField(max_length=50) # weather, crop, market
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.type} for {self.user.username} - Read: {self.is_read}"

    def save(self, *args, **kwargs):
        is_new = self._state.adding
        super().save(*args, **kwargs)
        
        if is_new and self.user.fcm_token:
            # Envoi automatique du push Firebase lors de la création d'une nouvelle notification
            title = f"Nouvelle alerte : {self.type.capitalize()}"
            send_push_notification(
                fcm_token=self.user.fcm_token,
                title=title,
                body=self.message,
                data={'notification_id': str(self.id), 'type': self.type}
            )
