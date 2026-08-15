from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import UpdateFCMTokenView, CustomTokenObtainPairView, RegisterView, UpdateProfileView

app_name = 'users'

urlpatterns = [
    path('auth/login/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('update-fcm-token/', UpdateFCMTokenView.as_view(), name='update_fcm_token'),
    path('profile/update/', UpdateProfileView.as_view(), name='update_profile'),
]
