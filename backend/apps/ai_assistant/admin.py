from django.contrib import admin
from .models import AIConversation, AIInteraction, LLMUsage


@admin.register(AIConversation)
class AIConversationAdmin(admin.ModelAdmin):
    """Sessions de conversation avec l'assistant IA."""

    list_display = ('title', 'user', 'created_at', 'updated_at')
    list_filter = ('created_at', 'updated_at')
    search_fields = ('user__username', 'title')
    date_hierarchy = 'updated_at'
    list_select_related = ('user',)
    readonly_fields = ('user', 'title', 'created_at', 'updated_at')

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False


@admin.register(AIInteraction)
class AIInteractionAdmin(admin.ModelAdmin):
    """Historique des échanges avec l'assistant : consultation seule (conversations privées)."""

    list_display = ('user', 'conversation', 'context_type', 'created_at')
    list_filter = ('context_type', 'created_at')
    search_fields = ('user__username', 'query')
    date_hierarchy = 'created_at'
    list_select_related = ('user', 'conversation')
    readonly_fields = ('user', 'conversation', 'query', 'response', 'context_type', 'created_at')

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False



@admin.register(LLMUsage)
class LLMUsageAdmin(admin.ModelAdmin):
    """Journal des appels aux modèles de langage (coûts, quotas, pannes) : consultation seule, sans contenu."""

    list_display = ('provider', 'model', 'feature', 'ok', 'error_kind', 'latency_ms', 'prompt_tokens', 'completion_tokens', 'user', 'created_at')
    list_filter = ('provider', 'feature', 'ok', 'error_kind', 'created_at')
    search_fields = ('model', 'user__username')
    date_hierarchy = 'created_at'
    list_select_related = ('user',)

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
