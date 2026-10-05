import logging

from django.utils import timezone
from rest_framework import permissions, status, views
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle

from apps.agriculture.models import Activity, Crop, PestReport
from apps.agriculture.serializers import ActivitySerializer, CropSerializer, PestReportSerializer
from apps.ai_assistant.models import AIInteraction
from apps.ai_assistant.serializers import AIInteractionSerializer
from apps.finances.models import Sale, Transaction
from apps.finances.serializers import SaleSerializer, TransactionSerializer
from apps.inventory.models import StockItem
from apps.inventory.serializers import StockItemSerializer
from apps.notifications.models import Notification
from apps.notifications.serializers import NotificationSerializer
from apps.users.views import UserProfileSerializer

from .policy import POLICY_VERSION, load_policy_text

logger = logging.getLogger(__name__)


class PrivacyPolicyView(views.APIView):
    """Texte de la politique de confidentialité et numéro de version en vigueur (public)."""
    permission_classes = [permissions.AllowAny]
    authentication_classes = []
    throttle_classes = []

    def get(self, request, *args, **kwargs):
        return Response({'version': POLICY_VERSION, 'language': 'fr', 'content': load_policy_text()})


class ExportDataView(views.APIView):
    """Droit d'accès : toutes les données rattachées au compte connecté, au format JSON."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        user = request.user
        crops = Crop.objects.filter(user=user).prefetch_related('activities')
        payload = {
            'exported_at': timezone.now().isoformat(),
            'policy_version_accepted': user.privacy_policy_version,
            'policy_accepted_at': user.privacy_accepted_at.isoformat() if user.privacy_accepted_at else None,
            'profile': UserProfileSerializer(user).data,
            'crops': CropSerializer(crops, many=True).data,
            'activities': ActivitySerializer(Activity.objects.filter(crop__user=user), many=True).data,
            'pest_reports': PestReportSerializer(PestReport.objects.filter(user=user), many=True).data,
            'sales': SaleSerializer(Sale.objects.filter(crop__user=user), many=True).data,
            'transactions': TransactionSerializer(Transaction.objects.filter(user=user), many=True).data,
            'stock_items': StockItemSerializer(StockItem.objects.filter(user=user), many=True).data,
            'notifications': NotificationSerializer(Notification.objects.filter(user=user), many=True).data,
            'ai_interactions': AIInteractionSerializer(AIInteraction.objects.filter(user=user), many=True).data,
        }
        response = Response(payload)
        response['Content-Disposition'] = 'attachment; filename="naatal-agro-mes-donnees.json"'
        return response


class DeleteAccountView(views.APIView):
    """
    Droit à l'effacement : supprime définitivement le compte et toutes les données liées
    (cultures, finances, stocks, notifications, échanges IA). Le mot de passe est redemandé.
    """
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth'

    def post(self, request, *args, **kwargs):
        user = request.user
        password = request.data.get('password')
        if not password or not isinstance(password, str) or not user.check_password(password):
            return Response({'error': 'Mot de passe incorrect.'}, status=status.HTTP_400_BAD_REQUEST)
        if user.is_staff or user.is_superuser:
            return Response(
                {'error': "Un compte d'administration ne peut pas être supprimé depuis l'application."},
                status=status.HTTP_403_FORBIDDEN,
            )
        user_id = str(user.pk)
        user.delete()
        logger.info('Compte supprimé à la demande de son titulaire : %s', user_id)
        return Response(status=status.HTTP_204_NO_CONTENT)
