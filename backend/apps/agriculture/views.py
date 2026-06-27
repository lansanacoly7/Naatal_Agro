from rest_framework import viewsets, permissions
from .models import Crop, Activity
from .serializers import CropSerializer, ActivitySerializer

class CropViewSet(viewsets.ModelViewSet):
    serializer_class = CropSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Restrict to user's crops
        return Crop.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class ActivityViewSet(viewsets.ModelViewSet):
    serializer_class = ActivitySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Restrict activities to the user's crops
        return Activity.objects.filter(crop__user=self.request.user)
