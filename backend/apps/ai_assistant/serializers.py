from rest_framework import serializers
from .models import AIInteraction

class AIInteractionSerializer(serializers.ModelSerializer):
    class Meta:
        model = AIInteraction
        fields = '__all__'
        read_only_fields = ['id', 'user', 'response', 'created_at']
