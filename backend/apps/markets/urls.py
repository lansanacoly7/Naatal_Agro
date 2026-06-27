from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import MarketViewSet, PriceViewSet

router = DefaultRouter()
router.register(r'prices', PriceViewSet, basename='price')
router.register(r'', MarketViewSet, basename='market')

app_name = 'markets'

urlpatterns = [
    path('', include(router.urls)),
]
