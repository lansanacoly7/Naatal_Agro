from rest_framework import viewsets, permissions
from .models import Crop, Activity, PestReport
from .serializers import CropSerializer, ActivitySerializer, PestReportSerializer
from apps.users.permissions import IsOwnerOrReadOnly

class CropViewSet(viewsets.ModelViewSet):
    serializer_class = CropSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Restreint strictement aux cultures de l'utilisateur authentifié
        return Crop.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class ActivityViewSet(viewsets.ModelViewSet):
    serializer_class = ActivitySerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Restreint strictement aux activités sur les cultures de l'utilisateur
        return Activity.objects.filter(crop__user=self.request.user)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

class PestReportViewSet(viewsets.ModelViewSet):
    serializer_class = PestReportSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrReadOnly]
    queryset = PestReport.objects.all()

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
