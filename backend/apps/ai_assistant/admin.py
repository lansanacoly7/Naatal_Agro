from django.contrib import admin
from .models import AIConversation, AIInteraction


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

