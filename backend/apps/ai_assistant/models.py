import uuid
from django.db import models
from django.conf import settings

class AIInteraction(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='ai_interactions')
    query = models.TextField()
    response = models.TextField()
    context_type = models.CharField(max_length=50, default='general') # market, crop, general
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.context_type} - {self.created_at}"
