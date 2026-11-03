from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny
from rest_framework import status
from django.db import connection
from django.utils import timezone
import logging

logger = logging.getLogger(__name__)

class HealthCheckView(APIView):
    """
    Endpoint de santé pour les sondes d'orchestration (Docker, Kubernetes, AWS/GCP, Nginx).
    Vérifie la disponibilité du serveur HTTP et la connectivité active à la base de données.
    """
    permission_classes = [AllowAny]

    def get(self, request, *args, **kwargs):
        health_data = {
            "status": "healthy",
            "service": "Naatal Agro API",
            "version": "1.0.0",
            "timestamp": timezone.now().isoformat(),
            "database": "unknown"
        }

        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1;")
                cursor.fetchone()
            health_data["database"] = "connected"
            return Response(health_data, status=status.HTTP_200_OK)
        except Exception as e:
            health_data["status"] = "unhealthy"
            logger.exception("Sonde de santé : base de données injoignable")
            health_data["database"] = "error"
            return Response(health_data, status=status.HTTP_503_SERVICE_UNAVAILABLE)
