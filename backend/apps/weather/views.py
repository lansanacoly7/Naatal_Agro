from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import WeatherData
from .serializers import WeatherDataSerializer
from .services import (
    AmbiguousPlace,
    OutsideSenegal,
    UnknownPlace,
    WeatherUnavailable,
    weather_at,
    weather_for_place,
)


def _failure(message, http_status, **extra):
    return Response({'available': False, 'error': message, **extra}, status=http_status)


class WeatherViewSet(viewsets.ReadOnlyModelViewSet):
    """Mesures météo réelles déjà relevées (aucune n'est fabriquée) et météo du moment du lieu de l'utilisateur."""

    queryset = WeatherData.objects.all()
    serializer_class = WeatherDataSerializer
    permission_classes = [permissions.IsAuthenticated]

    def list(self, request, *args, **kwargs):
        location = request.query_params.get('location')
        queryset = self.get_queryset()
        if location:
            queryset = queryset.filter(location__icontains=location)
        return Response(self.get_serializer(queryset, many=True).data)

    @action(detail=False, methods=['get'], url_path='here')
    def here(self, request):
        """
        Météo réelle (maintenant et 7 prochains jours) à une position ``?lat=…&lon=…``, à défaut au lieu
        ``?location=…`` ou au lieu du profil. Jamais de valeur de remplacement : en cas de problème, une erreur claire.
        """
        lat, lon = request.query_params.get('lat'), request.query_params.get('lon')
        try:
            if lat is not None and lon is not None:
                try:
                    return Response(weather_at(float(lat), float(lon)))
                except ValueError:
                    return _failure('Coordonnées invalides.', status.HTTP_400_BAD_REQUEST)
            place = request.query_params.get('location') or getattr(request.user, 'location', '') or ''
            if not place.strip():
                return _failure('Indiquez votre localisation pour voir la météo de votre zone.', status.HTTP_400_BAD_REQUEST)
            return Response(weather_for_place(place))
        except AmbiguousPlace as exc:
            return _failure('Plusieurs lieux portent ce nom : choisissez le vôtre.', status.HTTP_409_CONFLICT,
                            ambiguous=True, candidates=exc.candidates)
        except UnknownPlace as exc:
            return _failure(str(exc), status.HTTP_404_NOT_FOUND)
        except OutsideSenegal as exc:
            return _failure(str(exc), status.HTTP_422_UNPROCESSABLE_ENTITY)
        except WeatherUnavailable:
            return _failure('La météo est momentanément indisponible. Réessayez dans quelques minutes.',
                            status.HTTP_503_SERVICE_UNAVAILABLE)

    # Ancienne adresse conservée : elle renvoie désormais la même météo réelle
    @action(detail=False, methods=['get'], url_path='forecast')
    def forecast(self, request):
        return self.here(request)
