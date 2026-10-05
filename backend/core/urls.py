"""
URL configuration for core project.
"""

from django.contrib import admin
from django.urls import path, include
from .views import HealthCheckView

urlpatterns = [
    path("health/", HealthCheckView.as_view(), name="health_check"),
    path("api/health/", HealthCheckView.as_view(), name="api_health_check"),
    path("admin/", admin.site.urls),
    path("api/users/", include("apps.users.urls")),
    path("api/agriculture/", include("apps.agriculture.urls")),
    path("api/markets/", include("apps.markets.urls")),
    path("api/weather/", include("apps.weather.urls")),
    path("api/ai/", include("apps.ai_assistant.urls")),
    path("api/notifications/", include("apps.notifications.urls")),
    path("api/dashboard/", include("apps.analytics.urls")),
    path("api/inventory/", include("apps.inventory.urls")),
    path("api/finances/", include("apps.finances.urls")),
    path("api/privacy/", include("apps.privacy.urls")),
]
