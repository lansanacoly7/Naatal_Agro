from django.contrib import admin

from .models import AIInteraction


@admin.register(AIInteraction)
class AIInteractionAdmin(admin.ModelAdmin):
    """Historique des échanges avec l'assistant : consultation seule (conversations privées)."""

    list_display = ('user', 'context_type', 'created_at')
    list_filter = ('context_type', 'created_at')
    search_fields = ('user__username', 'query')
    date_hierarchy = 'created_at'
    list_select_related = ('user',)
    readonly_fields = ('user', 'query', 'response', 'context_type', 'created_at')

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
