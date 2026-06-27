from rest_framework import viewsets, permissions
from .models import Market, Price
from .serializers import MarketSerializer, PriceSerializer

class MarketViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Market.objects.all()
    serializer_class = MarketSerializer
    permission_classes = [permissions.IsAuthenticated]

class PriceViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Price.objects.all()
    serializer_class = PriceSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        queryset = super().get_queryset()
        market_id = self.request.query_params.get('market', None)
        product_name = self.request.query_params.get('product', None)
        
        if market_id:
            queryset = queryset.filter(market_id=market_id)
        if product_name:
            queryset = queryset.filter(product_name__icontains=product_name)
        
        return queryset
