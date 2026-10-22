import datetime
from rest_framework import serializers
from .models import Sale, Transaction
from apps.agriculture.models import Crop
from .categories import category_label

class SaleSerializer(serializers.ModelSerializer):
    crop_name = serializers.CharField(source='crop.name', read_only=True)
    total_revenue = serializers.FloatField(read_only=True)
    product_name = serializers.CharField(required=False, allow_blank=True)
    quantity = serializers.FloatField(write_only=True, required=False)
    unit_price = serializers.DecimalField(max_digits=10, decimal_places=2, write_only=True, required=False)
    sale_date = serializers.DateField(write_only=True, required=False)

    class Meta:
        model = Sale
        fields = [
            'id', 'crop', 'crop_name', 'product_name', 'quantity_sold', 'price_per_unit', 'date',
            'buyer', 'total_revenue', 'created_at',
            'quantity', 'unit_price', 'sale_date'
        ]
        extra_kwargs = {
            'crop': {'required': False, 'allow_null': True},
            'quantity_sold': {'required': False},
            'price_per_unit': {'required': False},
            'date': {'required': False},
            'product_name': {'required': False},
        }

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        if not ret.get('crop_name'):
            ret['crop_name'] = instance.product_name or ''
        return ret

    def to_internal_value(self, data):
        data = data.copy() if hasattr(data, 'copy') else dict(data)
        request = self.context.get('request')

        # Normaliser les alias
        if 'quantity_sold' not in data and 'quantity' in data:
            data['quantity_sold'] = data['quantity']
        if 'price_per_unit' not in data and 'unit_price' in data:
            data['price_per_unit'] = data['unit_price']
        if 'date' not in data:
            data['date'] = data.get('sale_date') or datetime.date.today().isoformat()

        if ('crop' not in data or not data['crop']) and request and request.user.is_authenticated:
            product_name = data.get('product_name')
            if product_name:
                crop = Crop.objects.filter(user=request.user, name__iexact=product_name).first()
                if not crop:
                    crop = Crop.objects.filter(user=request.user, crop_type__iexact=product_name).first()
                if crop:
                    data['crop'] = str(crop.id)
                # Aucune création de culture fantôme : product_name est conservé directement

        return super().to_internal_value(data)

    def validate_crop(self, value):
        request = self.context.get('request')
        if value and request and request.user and request.user.is_authenticated:
            if value.user != request.user:
                raise serializers.ValidationError("Violation de sécurité : Vous ne pouvez enregistrer de vente que pour vos propres récoltes.")
        return value

    def validate(self, attrs):
        crop = attrs.get('crop')
        quantity_sold = attrs.get('quantity_sold')
        price_per_unit = attrs.get('price_per_unit')
        product_name = attrs.get('product_name')
        request = self.context.get('request')

        if quantity_sold is None or quantity_sold <= 0:
            raise serializers.ValidationError({'quantity_sold': "La quantité vendue doit être supérieure à zéro."})
        if price_per_unit is None or price_per_unit <= 0:
            raise serializers.ValidationError({'price_per_unit': "Le prix unitaire doit être supérieur à zéro."})

        effective_name = crop.name if crop else (product_name or '')
        if request and request.user and effective_name and quantity_sold is not None:
            from apps.inventory.models import StockItem
            stock_item = StockItem.objects.filter(user=request.user, name__iexact=effective_name).first()
            if stock_item and stock_item.quantity < float(quantity_sold):
                raise serializers.ValidationError({
                    'quantity_sold': f"Stock insuffisant : vous disposez actuellement de {stock_item.quantity} {stock_item.unit} pour {effective_name}."
                })
        return attrs

    def create(self, validated_data):
        validated_data.pop('quantity', None)
        validated_data.pop('unit_price', None)
        validated_data.pop('sale_date', None)

        request = self.context.get('request')
        if request and request.user and request.user.is_authenticated:
            validated_data['user'] = request.user

        crop = validated_data.get('crop')
        if crop and not validated_data.get('product_name'):
            validated_data['product_name'] = crop.name

        return super().create(validated_data)

class TransactionSerializer(serializers.ModelSerializer):
    category_label = serializers.SerializerMethodField()
    crop_name = serializers.CharField(source='crop.name', read_only=True, default=None)

    class Meta:
        model = Transaction
        fields = ['id', 'transaction_type', 'amount', 'date', 'description', 'category', 'category_label',
                  'crop', 'crop_name', 'created_at']
        extra_kwargs = {
            'category': {'required': False},
            'crop': {'required': False, 'allow_null': True},
        }

    def get_category_label(self, obj):
        return category_label(obj.category) if obj.category else ''

    def validate_crop(self, value):
        request = self.context.get('request')
        if value and request and request.user.is_authenticated and value.user != request.user:
            raise serializers.ValidationError("Cette culture ne vous appartient pas.")
        return value

    def validate(self, attrs):
        # Un revenu n'a pas de catégorie de dépense
        if attrs.get('transaction_type') == 'income':
            attrs['category'] = ''
        return attrs
