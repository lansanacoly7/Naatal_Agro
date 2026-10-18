"""
URL configuration for core project.
"""

from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from rest_framework_simplejwt.views import TokenRefreshView
from .views import HealthCheckView

def v1_models(request):
    return JsonResponse({"object": "list", "data": []})

from apps.users.views import (
    CustomTokenObtainPairView,
    RegisterView,
    LogoutView,
    SendOTPView,
    VerifyOTPView,
    ChangePasswordView,
    ResetPasswordView,
)
from apps.markets.views import ProductViewSet, PriceViewSet

urlpatterns = [
    path("health", HealthCheckView.as_view(), name="health_check_noslash"),
    path("health/", HealthCheckView.as_view(), name="health_check"),
    path("api/health", HealthCheckView.as_view(), name="api_health_check_noslash"),
    path("api/health/", HealthCheckView.as_view(), name="api_health_check"),
    path("v1/models", v1_models, name="v1_models_noslash"),
    path("v1/models/", v1_models, name="v1_models"),
    path("admin/", admin.site.urls),

    # Aliases directs /api/auth/ et /api/products/
    path("api/auth/login/", CustomTokenObtainPairView.as_view(), name="alias_login"),
    path("api/auth/register/", RegisterView.as_view(), name="alias_register"),
    path("api/auth/refresh/", TokenRefreshView.as_view(), name="alias_refresh"),
    path("api/auth/logout/", LogoutView.as_view(), name="alias_logout"),
    path("api/auth/otp/send/", SendOTPView.as_view(), name="alias_otp_send"),
    path("api/auth/otp/verify/", VerifyOTPView.as_view(), name="alias_otp_verify"),
    path("api/auth/password/reset/", ResetPasswordView.as_view(), name="alias_password_reset"),
    path("api/products/", ProductViewSet.as_view({"get": "list"}), name="alias_products"),
    path("api/products/<int:pk>/", ProductViewSet.as_view({"get": "retrieve"}), name="alias_product_detail"),
    path("api/prices/", PriceViewSet.as_view({"get": "list"}), name="alias_prices"),
    path("api/prices/<int:pk>/", PriceViewSet.as_view({"get": "retrieve"}), name="alias_price_detail"),

    # Modules principaux
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
