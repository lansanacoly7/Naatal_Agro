from django.contrib import admin

from .models import Notification


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('type', 'user', 'is_read', 'is_sent', 'scheduled_for', 'cancelled_at', 'created_at')
    list_filter = ('type', 'is_read', 'is_sent', 'created_at')
    search_fields = ('message', 'user__username')
    date_hierarchy = 'created_at'
    list_select_related = ('user',)
