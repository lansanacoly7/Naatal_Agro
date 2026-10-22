from rest_framework import serializers
from .models import StockItem, StockMovement

class StockItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = StockItem
        fields = ['id', 'name', 'quantity', 'unit', 'alert_status', 'ai_storage_advice', 'updated_at', 'created_at']
        read_only_fields = ['id', 'alert_status', 'ai_storage_advice', 'updated_at', 'created_at']


class StockMovementSerializer(serializers.ModelSerializer):
    reason_label = serializers.CharField(source='get_reason_display', read_only=True)
    movement_label = serializers.CharField(source='get_movement_type_display', read_only=True)

    class Meta:
        model = StockMovement
        fields = [
            'id', 'stock_item', 'product_name', 'movement_type', 'movement_label', 'quantity', 'unit',
            'balance_after', 'reason', 'reason_label', 'note', 'sale', 'created_at',
        ]
        read_only_fields = fields
