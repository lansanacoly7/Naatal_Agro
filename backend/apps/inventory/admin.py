from django.contrib import admin

from .models import StockItem


@admin.register(StockItem)
class StockItemAdmin(admin.ModelAdmin):
    list_display = ('name', 'quantity', 'unit', 'alert_status', 'user', 'updated_at')
    list_filter = ('alert_status', 'unit')
    search_fields = ('name', 'user__username')
    list_select_related = ('user',)
