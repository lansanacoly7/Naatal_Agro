from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import CropViewSet, ActivityViewSet

router = DefaultRouter()
router.register(r'crops', CropViewSet, basename='crop')
router.register(r'activities', ActivityViewSet, basename='activity')

app_name = 'agriculture'

urlpatterns = [
    path('', include(router.urls)),
]
