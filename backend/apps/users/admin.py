from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import User


@admin.register(User)
class NaatalUserAdmin(UserAdmin):
    """Administration des comptes : le jeton FCM est en lecture seule (donnée technique sensible)."""

    list_display = ('username', 'first_name', 'phone', 'role', 'location', 'is_active', 'date_joined')
    list_filter = ('role', 'language', 'is_active', 'is_staff', 'date_joined')
    search_fields = ('username', 'first_name', 'last_name', 'phone', 'email', 'location')
    ordering = ('-date_joined',)
    readonly_fields = ('fcm_token', 'last_login', 'date_joined', 'privacy_accepted_at', 'privacy_policy_version')

    fieldsets = UserAdmin.fieldsets + (
        ('Profil Naatal Agro', {
            'fields': ('phone', 'role', 'location', 'language', 'date_of_birth', 'main_crops', 'fcm_token', 'privacy_accepted_at', 'privacy_policy_version'),
        }),
    )
    add_fieldsets = UserAdmin.add_fieldsets + (
        ('Profil Naatal Agro', {'fields': ('phone', 'role', 'location', 'language')}),
    )
