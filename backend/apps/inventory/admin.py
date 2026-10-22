from django.contrib import admin

from .models import StockItem, StockMovement


@admin.register(StockItem)
class StockItemAdmin(admin.ModelAdmin):
    list_display = ('name', 'quantity', 'unit', 'alert_status', 'user', 'updated_at')
    list_filter = ('alert_status', 'unit')
    search_fields = ('name', 'user__username')
    list_select_related = ('user',)


@admin.register(StockMovement)
class StockMovementAdmin(admin.ModelAdmin):
    """Journal en lecture seule : un mouvement n'est jamais créé ni modifié à la main."""
    list_display = ('product_name', 'movement_type', 'quantity', 'unit', 'balance_after', 'reason', 'user', 'created_at')
    list_filter = ('movement_type', 'reason', 'created_at')
    search_fields = ('product_name', 'user__username', 'note')
    date_hierarchy = 'created_at'
    list_select_related = ('user',)

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False
