from rest_framework import serializers
from .models import Sale, Transaction

class SaleSerializer(serializers.ModelSerializer):
    crop_name = serializers.CharField(source='crop.name', read_only=True)
    total_revenue = serializers.FloatField(read_only=True)

    class Meta:
        model = Sale
        fields = ['id', 'crop', 'crop_name', 'quantity_sold', 'price_per_unit', 'date', 'buyer', 'total_revenue', 'created_at']

    def validate_crop(self, value):
        request = self.context.get('request')
        if request and request.user and request.user.is_authenticated:
            if value.user != request.user:
                raise serializers.ValidationError("Violation de sécurité : Vous ne pouvez enregistrer de vente que pour vos propres récoltes.")
        return value

class TransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Transaction
        fields = ['id', 'transaction_type', 'amount', 'date', 'description', 'created_at']
