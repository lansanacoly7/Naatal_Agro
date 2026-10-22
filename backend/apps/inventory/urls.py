from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import StockItemViewSet, StockMovementViewSet

router = DefaultRouter()
router.register(r'', StockItemViewSet, basename='inventory')

urlpatterns = [
    # Avant le routeur : celui-ci enregistre ``''`` et prendrait « movements » pour un identifiant d'article
    path('movements/', StockMovementViewSet.as_view({'get': 'list'}), name='stock-movements'),
    path('movements/<uuid:pk>/', StockMovementViewSet.as_view({'get': 'retrieve'}), name='stock-movement-detail'),
    path('', include(router.urls)),
]
