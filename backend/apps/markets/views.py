from rest_framework import viewsets, permissions, status
from rest_framework.response import Response
from rest_framework.decorators import action
from .models import Market, Price, Product, PreSaleOffer, PreSaleReservation
from .serializers import MarketSerializer, PriceSerializer, ProductSerializer, PreSaleOfferSerializer, PreSaleReservationSerializer

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

class PreSaleOfferViewSet(viewsets.ModelViewSet):
    queryset = PreSaleOffer.objects.all().order_by('-created_at')
    serializer_class = PreSaleOfferSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = super().get_queryset()
        # Optionally filter by location or status
        status_param = self.request.query_params.get('status', None)
        if status_param:
            queryset = queryset.filter(status=status_param)
        return queryset

    def perform_create(self, serializer):
        serializer.save(farmer=self.request.user)

    @action(detail=True, methods=['post'])
    def reserve(self, request, pk=None):
        offer = self.get_object()
        if offer.status != 'open':
            return Response({'detail': 'This offer is no longer open.'}, status=status.HTTP_400_BAD_REQUEST)
        
        quantity = request.data.get('quantity_reserved')
        if not quantity:
            return Response({'detail': 'Quantity is required.'}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            quantity = float(quantity)
        except ValueError:
            return Response({'detail': 'Invalid quantity.'}, status=status.HTTP_400_BAD_REQUEST)

        if quantity > offer.quantity_kg:
            return Response({'detail': 'Requested quantity exceeds available offer.'}, status=status.HTTP_400_BAD_REQUEST)

        # Create reservation
        reservation = PreSaleReservation.objects.create(
            offer=offer,
            buyer=request.user,
            quantity_reserved=quantity
        )
        
        # Update offer status if fully reserved
        offer.quantity_kg -= quantity
        if offer.quantity_kg <= 0:
            offer.status = 'reserved'
            offer.quantity_kg = 0
        offer.save()
        
        return Response(PreSaleReservationSerializer(reservation).data, status=status.HTTP_201_CREATED)

class PreSaleReservationViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = PreSaleReservationSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        # Buyer sees their reservations, farmer sees reservations for their offers
        user = self.request.user
        if user.role == 'buyer':
            return PreSaleReservation.objects.filter(buyer=user).order_by('-created_at')
        else:
            return PreSaleReservation.objects.filter(offer__farmer=user).order_by('-created_at')
