from rest_framework import serializers
from .models import AIConversation, AIInteraction

class AIInteractionSerializer(serializers.ModelSerializer):
    conversation_id = serializers.UUIDField(source='conversation.id', read_only=True, allow_null=True)

    class Meta:
        model = AIInteraction
        fields = [
            'id', 'conversation', 'conversation_id', 'user', 'query', 'response',
            'context_type', 'origin', 'sources', 'suggestions',
            'action_data', 'created_at'
        ]
        read_only_fields = ['id', 'conversation', 'conversation_id', 'user', 'response', 'origin', 'sources', 'suggestions', 'action_data', 'created_at']


class AIConversationListSerializer(serializers.ModelSerializer):
    message_count = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()

    class Meta:
        model = AIConversation
        fields = ['id', 'title', 'created_at', 'updated_at', 'message_count', 'last_message']
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_message_count(self, obj):
        return obj.interactions.count()

    def get_last_message(self, obj):
        last = obj.interactions.order_by('-created_at').first()
        if not last:
            return None
        return {
            'id': str(last.id),
            'query': last.query[:100],
            'response': last.response[:150],
            'created_at': last.created_at.isoformat(),
        }


class AIConversationDetailSerializer(serializers.ModelSerializer):
    interactions = serializers.SerializerMethodField()

    class Meta:
        model = AIConversation
        fields = ['id', 'title', 'created_at', 'updated_at', 'interactions']
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_interactions(self, obj):
        # Ordre chronologique pour l'affichage de la discussion
        qs = obj.interactions.order_by('created_at')
        return AIInteractionSerializer(qs, many=True).data

