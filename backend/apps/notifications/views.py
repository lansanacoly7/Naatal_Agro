from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Notification
from .serializers import NotificationSerializer
from .services import deliver_due_reminders

class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = Notification.objects.filter(user=self.request.user).order_by('-created_at')
        if self.action != 'list':
            return queryset
        # Les rappels arrivés à échéance sont délivrés à la consultation, même sans planificateur serveur
        deliver_due_reminders(user=self.request.user)
        if self.request.query_params.get('scope') == 'scheduled':
            # Rappels à venir (utilisés par l'application pour programmer ses alarmes locales)
            return queryset.filter(is_sent=False, cancelled_at__isnull=True, scheduled_for__isnull=False).order_by('scheduled_for')
        # Par défaut : seulement ce qui a été délivré et n'est pas annulé
        return queryset.filter(is_sent=True, cancelled_at__isnull=True)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=True, methods=['post'])
    def read(self, request, pk=None):
        notification = self.get_object()
        notification.is_read = True
        notification.save()
        return Response({'status': 'notification marked as read'})

    @action(detail=False, methods=['post'], url_path='mark-all-read')
    def mark_all_read(self, request):
        updated_count = Notification.objects.filter(user=request.user, is_sent=True, is_read=False).update(is_read=True)
        return Response({'status': 'all notifications marked as read', 'updated_count': updated_count})
