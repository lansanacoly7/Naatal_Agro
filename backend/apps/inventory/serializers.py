from rest_framework import serializers
from .models import StockItem

class StockItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = StockItem
        fields = ['id', 'name', 'quantity', 'unit', 'alert_status', 'ai_storage_advice', 'updated_at', 'created_at']
        read_only_fields = ['id', 'alert_status', 'ai_storage_advice', 'updated_at', 'created_at']
