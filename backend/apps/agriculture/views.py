from django.db.models import Q
from rest_framework import viewsets, permissions
from .models import AgronomicGuide, Crop, Activity, PestReport
from .serializers import AgronomicGuideSerializer, CropSerializer, ActivitySerializer, PestReportSerializer
from apps.users.permissions import IsOwnerOrReadOnly

class CropViewSet(viewsets.ModelViewSet):
    serializer_class = CropSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Restreint strictement aux cultures de l'utilisateur authentifié ; les activités imbriquées
        # sont chargées en une seule requête (sinon une requête supplémentaire par culture)
        return Crop.objects.filter(user=self.request.user).prefetch_related('activities')

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


class AgronomicGuideViewSet(viewsets.ReadOnlyModelViewSet):
    """
    Fiches techniques des cultures du Sénégal (lecture seule), identifiées par leur ``slug``.
    Filtres : ``?category=legume|cereale|legumineuse`` et ``?search=<texte>`` (nom ou nom scientifique).
    """
    serializer_class = AgronomicGuideSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'slug'

    def get_queryset(self):
        queryset = AgronomicGuide.objects.all()
        category = self.request.query_params.get('category')
        search = self.request.query_params.get('search')
        if category:
            queryset = queryset.filter(category=category)
        if search:
            queryset = queryset.filter(Q(name__icontains=search) | Q(scientific_name__icontains=search))
        return queryset
