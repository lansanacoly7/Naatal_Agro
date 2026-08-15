from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import MarketViewSet, PriceViewSet, ProductViewSet, PreSaleOfferViewSet, PreSaleReservationViewSet

router = DefaultRouter()
router.register(r'products', ProductViewSet, basename='product')
router.register(r'prices', PriceViewSet, basename='price')
router.register(r'b2b-offers', PreSaleOfferViewSet, basename='presale-offer')
router.register(r'b2b-reservations', PreSaleReservationViewSet, basename='presale-reservation')
router.register(r'', MarketViewSet, basename='market')

app_name = 'markets'

urlpatterns = [
    path('', include(router.urls)),
]
