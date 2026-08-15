from rest_framework import serializers
from .models import Market, Price, Product, PreSaleOffer, PreSaleReservation

class ProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = Product
        fields = '__all__'

class PriceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Price
        fields = '__all__'

class MarketSerializer(serializers.ModelSerializer):
    class Meta:
        model = Market
        fields = '__all__'

class PreSaleOfferSerializer(serializers.ModelSerializer):
    farmer_name = serializers.CharField(source='farmer.username', read_only=True)
    class Meta:
        model = PreSaleOffer
        fields = '__all__'
        read_only_fields = ['id', 'farmer', 'created_at', 'status']

class PreSaleReservationSerializer(serializers.ModelSerializer):
    buyer_name = serializers.CharField(source='buyer.username', read_only=True)
    class Meta:
        model = PreSaleReservation
        fields = '__all__'
        read_only_fields = ['id', 'buyer', 'created_at']
