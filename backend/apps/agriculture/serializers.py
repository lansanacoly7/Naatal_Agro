from rest_framework import serializers
from .models import Crop, Activity, PestReport

class ActivitySerializer(serializers.ModelSerializer):
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

    class Meta:
        model = Crop
        fields = '__all__'
        read_only_fields = ['id', 'user', 'created_at']

class PestReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = PestReport
        fields = '__all__'
        read_only_fields = ['id', 'user', 'date_reported']
