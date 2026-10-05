from rest_framework import viewsets, permissions
from .models import Market, Price, Product
from .serializers import MarketSerializer, PriceSerializer, ProductSerializer

class ProductViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = super().get_queryset()
        category = self.request.query_params.get('category', None)
        is_trending = self.request.query_params.get('is_trending', None)
        search = self.request.query_params.get('search', None)

        if category:
            if category.lower() != 'tout':
                queryset = queryset.filter(category__iexact=category)
        if is_trending is not None:
            is_trending_bool = is_trending.lower() == 'true'
            queryset = queryset.filter(is_trending=is_trending_bool)
        if search:
            queryset = queryset.filter(name__icontains=search)
            
        return queryset

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
