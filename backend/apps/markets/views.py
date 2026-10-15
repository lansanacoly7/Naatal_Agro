from datetime import timedelta

from django.db.models import Avg, Count, F, Max, Window
from django.db.models.functions import RowNumber
from rest_framework import viewsets, permissions
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response
from .models import Market, Price, Product
from .serializers import MarketSerializer, PriceSerializer, ProductSerializer

class ProductViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Product.objects.all()
    serializer_class = ProductSerializer
    permission_classes = [permissions.AllowAny]

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
    permission_classes = [permissions.AllowAny]

from rest_framework.pagination import PageNumberPagination

class StandardPricePagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100

class PriceViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Price.objects.all().select_related('market')
    serializer_class = PriceSerializer
    pagination_class = StandardPricePagination
    permission_classes = [permissions.AllowAny]
    
    def get_queryset(self):
        queryset = super().get_queryset()
        market_id = self.request.query_params.get('market', None)
        product_name = self.request.query_params.get('product', None)
        
        if market_id:
            queryset = queryset.filter(market_id=market_id)
        if product_name:
            queryset = queryset.filter(product_name__icontains=product_name)
        
        return queryset

    @action(detail=False, methods=['get'], url_path='latest')
    def latest(self, request):
        """
        Dernier relevé de prix de chaque marché pour un produit (``?product=Oignon``).
        Une ligne par marché, sans pagination : sert à la carte et au classement des marchés.
        """
        product = (request.query_params.get('product') or '').strip()
        if not product:
            raise ValidationError({'product': "Le paramètre 'product' est requis."})
        rows = (
            Price.objects.filter(product_name__icontains=product)
            .annotate(rn=Window(RowNumber(), partition_by=[F('market_id')], order_by=[F('date').desc(), F('created_at').desc()]))
            .filter(rn=1)
            .select_related('market')
            .order_by('market__name')
        )
        return Response([
            {
                'market': str(r.market_id),
                'market_name': r.market.name,
                'region': r.market.region,
                'location_gps': r.market.location_gps,
                'product_name': r.product_name,
                'price': float(r.price),
                'trend': r.trend,
                'date': r.date.isoformat(),
            }
            for r in rows
        ])

    @action(detail=False, methods=['get'], url_path='history')
    def history(self, request):
        """
        Historique journalier d'un produit (``?product=Oignon``), au plus 120 jours.
        Avec ``?market=<id>`` : prix de ce marché. Sans : moyenne de tous les marchés ce jour-là.
        """
        product = (request.query_params.get('product') or '').strip()
        if not product:
            raise ValidationError({'product': "Le paramètre 'product' est requis."})
        try:
            days = min(max(int(request.query_params.get('days', 30)), 1), 120)
        except ValueError:
            raise ValidationError({'days': 'Nombre de jours invalide.'})
        qs = Price.objects.filter(product_name__icontains=product)
        market = request.query_params.get('market')
        if market:
            qs = qs.filter(market_id=market)
        newest = qs.aggregate(d=Max('date'))['d']
        if newest is None:
            return Response([])
        series = (
            qs.filter(date__gte=newest - timedelta(days=days - 1))
            .values('date')
            .annotate(price=Avg('price'), markets=Count('market', distinct=True))
            .order_by('date')
        )
        return Response([
            {'date': row['date'].isoformat(), 'price': round(float(row['price']), 2), 'markets': row['markets']}
            for row in series
        ])

