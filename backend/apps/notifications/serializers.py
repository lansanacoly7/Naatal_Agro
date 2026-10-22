from rest_framework import serializers
from .models import Notification

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = '__all__'
        # Le cycle de vie d'un rappel (livraison, annulation) est géré par le serveur, jamais par le client
        read_only_fields = ['id', 'user', 'created_at', 'is_sent', 'sent_at', 'cancelled_at']
