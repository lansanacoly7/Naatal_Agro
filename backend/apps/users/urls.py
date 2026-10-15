from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    UpdateFCMTokenView,
    CustomTokenObtainPairView,
    RegisterView,
    UpdateProfileView,
    MeView,
    LogoutView,
    ChangePasswordView,
    SendOTPView,
    VerifyOTPView,
    ResetPasswordView,
)

app_name = 'users'

urlpatterns = [
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/logout/', LogoutView.as_view(), name='logout'),
    path('auth/otp/send/', SendOTPView.as_view(), name='send_otp'),
    path('auth/otp/verify/', VerifyOTPView.as_view(), name='verify_otp'),
    path('auth/password/change/', ChangePasswordView.as_view(), name='change_password'),
    path('auth/password/reset/', ResetPasswordView.as_view(), name='reset_password'),
    path('me/', MeView.as_view(), name='user_me'),
    path('profile/', MeView.as_view(), name='user_profile'),
    path('profile/update/', UpdateProfileView.as_view(), name='update_profile'),
    path('update-fcm-token/', UpdateFCMTokenView.as_view(), name='update_fcm_token'),
]

