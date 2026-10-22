import datetime
from rest_framework import serializers
from .models import AgronomicGuide, Crop, Activity, PestReport, Harvest

class HarvestSerializer(serializers.ModelSerializer):
    class Meta:
        model = Harvest
        fields = ['id', 'crop', 'date', 'quantity', 'unit', 'notes', 'created_at']
        read_only_fields = ['id', 'created_at']

class HarvestCreateSerializer(serializers.Serializer):
    quantity = serializers.FloatField(min_value=0.01)
    unit = serializers.CharField(max_length=50, default='kg')
    date = serializers.DateField(required=False)
    notes = serializers.CharField(required=False, allow_blank=True, default='')

    def validate_quantity(self, value):
        if value <= 0:
            raise serializers.ValidationError("La quantité récoltée doit être supérieure à zéro.")
        return value

    def save(self):
        crop = self.context['crop']
        user = self.context['request'].user
        quantity = self.validated_data['quantity']
        unit = self.validated_data.get('unit', 'kg')
        harvest_date = self.validated_data.get('date') or datetime.date.today()
        notes = self.validated_data.get('notes', '')

        # 1. Enregistrer la récolte
        harvest = Harvest.objects.create(
            crop=crop,
            user=user,
            date=harvest_date,
            quantity=quantity,
            unit=unit,
            notes=notes,
        )

        # 2. Mettre à jour le statut de la culture
        crop.status = 'harvested'
        crop.save(update_fields=['status'])

        # 3. Synchroniser ou incrémenter le stock (journalisé : motif « récolte »)
        from apps.inventory.models import StockItem
        from apps.inventory.services import change_stock, create_stock_item
        note = f"Récolte du {harvest_date}"
        stock_item = StockItem.objects.filter(user=user, name__iexact=crop.name).first()
        if stock_item:
            change_stock(stock_item, stock_item.quantity + quantity, reason='harvest', note=note)
        else:
            create_stock_item(user, crop.name, quantity, unit, reason='harvest', note=note)

        # 4. Créer une notification
        try:
            from apps.notifications.models import Notification
            Notification.objects.create(
                user=user,
                type='info',
                message=f"Récolte enregistrée : {quantity} {unit} de {crop.name} ajoutés à vos stocks."
            )
        except Exception:
            pass

        return harvest

class ActivitySerializer(serializers.ModelSerializer):
    description = serializers.CharField(required=False, allow_blank=True, default='')

    class Meta:
        model = Activity
        fields = '__all__'
        read_only_fields = ['id', 'created_at']

    def validate_crop(self, value):
        request = self.context.get('request')
        if request and request.user and request.user.is_authenticated:
            if value.user != request.user:
                raise serializers.ValidationError("Violation de sécurité : Vous ne pouvez modifier ou lier une activité qu'à vos propres cultures.")
        return value

class CropSerializer(serializers.ModelSerializer):
    activities = ActivitySerializer(many=True, read_only=True)
    harvests = HarvestSerializer(many=True, read_only=True)
    guide_slug = serializers.CharField(source='guide.slug', read_only=True)
    guide_name = serializers.CharField(source='guide.name', read_only=True)
    expected_harvest_date = serializers.DateField(required=False)

    class Meta:
        model = Crop
        fields = '__all__'
        read_only_fields = ['id', 'user', 'created_at']

    def validate(self, attrs):
        planting_date = attrs.get('planting_date')
        if planting_date and not attrs.get('expected_harvest_date'):
            guide = attrs.get('guide')
            if guide and (guide.cycle_days_max or guide.cycle_days_min):
                days = guide.cycle_days_max or guide.cycle_days_min
                attrs['expected_harvest_date'] = planting_date + datetime.timedelta(days=days)
            elif not self.instance:
                raise serializers.ValidationError({
                    'expected_harvest_date': 'La date prévisionnelle de récolte est obligatoire.'
                })
        return attrs

class PestReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = PestReport
        fields = '__all__'
        read_only_fields = ['id', 'user', 'date_reported']


class AgronomicGuideSerializer(serializers.ModelSerializer):
    class Meta:
        model = AgronomicGuide
        fields = [
            'id', 'slug', 'name', 'scientific_name', 'category', 'summary', 'zones',
            'cycle_days_min', 'cycle_days_max', 'calendar', 'soil_and_sowing', 'water_needs',
            'fertilization', 'pests_diseases', 'harvest', 'yield_info', 'limitations', 'sources',
            'updated_at',
        ]
        read_only_fields = fields
