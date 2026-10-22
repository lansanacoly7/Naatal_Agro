import uuid
from django.db import models
from django.conf import settings

class AIConversation(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='ai_conversations')
    title = models.CharField(max_length=255, default="Nouvelle conversation")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']
        indexes = [
            models.Index(fields=['user', '-updated_at']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.title}"


class AIInteraction(models.Model):
    ORIGIN_CHOICES = [
        ('database', 'Fiches Naatal Agro'),
        ('database+web', 'Fiches Naatal Agro et web vérifié'),
        ('web', 'Web vérifié'),
        ('general', 'Conseil général sans source'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    conversation = models.ForeignKey(AIConversation, on_delete=models.CASCADE, null=True, blank=True, related_name='interactions')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='ai_interactions')
    query = models.TextField()
    response = models.TextField()
    context_type = models.CharField(max_length=50, default='general') # market, crop, general
    # D'où vient la réponse : fiches Naatal (database), fiches + web, web seul, ou conseil général sans source
    origin = models.CharField(max_length=20, choices=ORIGIN_CHOICES, default='general')
    sources = models.JSONField(default=list, blank=True, help_text='Sources citées : [{number, title, publisher, url, type}]')
    suggestions = models.JSONField(default=list, blank=True, help_text="Questions de relance proposées à l'utilisateur")
    action_data = models.JSONField(default=dict, blank=True, help_text="Proposition ou résultat d'action métier (vente, dépense, stock, alerte)")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'created_at']),
            models.Index(fields=['conversation', 'created_at']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.context_type} - {self.created_at}"
