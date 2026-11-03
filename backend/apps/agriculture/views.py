from django.db.models import Q
from rest_framework import permissions, status, views, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from . import crop_calendar_sources as calendar_sources
from .models import AgronomicGuide, Crop, CropCalendarEntry, Activity, PestReport, Harvest
from .serializers import (
    AgronomicGuideSerializer, CropSerializer, ActivitySerializer,
    PestReportSerializer, HarvestSerializer, HarvestCreateSerializer
)
from apps.users.permissions import IsOwnerOrReadOnly

class CropViewSet(viewsets.ModelViewSet):
    serializer_class = CropSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # Restreint strictement aux cultures de l'utilisateur authentifié ; les activités et récoltes imbriquées
        # sont chargées en une seule requête
        return Crop.objects.filter(user=self.request.user).prefetch_related('activities', 'harvests').select_related('guide')

    def perform_create(self, serializer):
        crop = serializer.save(user=self.request.user)
        try:
            from apps.notifications.models import Notification
            Notification.objects.create(
                user=self.request.user,
                type='crop',
                message=f"La culture « {crop.name} » a bien été enregistrée. Retrouvez vos conseils et calendrier de récolte.",
                is_sent=True
            )
        except Exception:
            pass

    @action(detail=True, methods=['post'], url_path='harvest')
    def record_harvest(self, request, pk=None):
        crop = self.get_object()
        serializer = HarvestCreateSerializer(
            data=request.data,
            context={'request': request, 'crop': crop}
        )
        serializer.is_valid(raise_exception=True)
        harvest = serializer.save()
        try:
            from apps.notifications.models import Notification
            Notification.objects.create(
                user=self.request.user,
                type='stock',
                message=f"Récolte réussie pour « {crop.name} » : {harvest.quantity} {harvest.unit} ajoutés au stock de votre exploitation.",
                is_sent=True
            )
        except Exception:
            pass
        return Response(HarvestSerializer(harvest).data, status=status.HTTP_201_CREATED)

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

    def get_queryset(self):
        # Un signalement contient un lieu et une description : chaque exploitant ne voit que les siens
        return PestReport.objects.filter(user=self.request.user)

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


class CropCalendarView(views.APIView):
    """
    Calendrier agricole du Sénégal : pour chaque culture, les périodes de semis et de récolte par zone, avec la source
    de chaque ligne. Aucune date n'est inventée : les cultures sans source sont listées à part (``undocumented``).
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        crops = {}
        for entry in CropCalendarEntry.objects.all():
            crop = crops.setdefault(entry.crop_key, {
                'key': entry.crop_key, 'name': entry.crop_name, 'category': entry.category, 'windows': [],
            })
            sow = None
            if entry.sow_start_month and entry.sow_end_month:
                sow = [entry.sow_start_month, entry.sow_start_day, entry.sow_end_month, entry.sow_end_day]
            harvest = None
            if entry.harvest_start_month and entry.harvest_end_month:
                harvest = [entry.harvest_start_month, entry.harvest_start_day, entry.harvest_end_month, entry.harvest_end_day]
            crop['windows'].append({
                'zone': entry.zone, 'label': entry.label, 'all_year': entry.all_year, 'sow': sow, 'harvest': harvest,
                'cycle_days_min': entry.cycle_days_min, 'cycle_days_max': entry.cycle_days_max,
                'period_text': entry.period_text, 'notes': entry.notes,
                'source': entry.source_key, 'source_note': entry.source_note,
            })
        used = {w['source'] for crop in crops.values() for w in crop['windows']}
        return Response({
            'zones': [{**zone, 'regions': [r for r, codes in calendar_sources.REGION_ZONES.items() if zone['code'] in codes]}
                      for zone in calendar_sources.ZONES],
            'region_zones': calendar_sources.REGION_ZONES,
            'crops': sorted(crops.values(), key=lambda c: c['name']),
            'sources': {key: value for key, value in calendar_sources.SOURCES.items() if key in used},
            'undocumented': calendar_sources.UNDOCUMENTED,
        })
