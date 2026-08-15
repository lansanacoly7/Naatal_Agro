from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import SaleViewSet, TransactionViewSet, FinancialSummaryView

router = DefaultRouter()
router.register(r'sales', SaleViewSet, basename='sales')
router.register(r'transactions', TransactionViewSet, basename='transactions')

urlpatterns = [
    path('summary/', FinancialSummaryView.as_view(), name='financial-summary'),
    path('', include(router.urls)),
]
