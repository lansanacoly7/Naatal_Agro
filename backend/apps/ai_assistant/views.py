from rest_framework import views, permissions, status
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.response import Response
from .models import AIInteraction
from .serializers import AIInteractionSerializer
from .services import answer_question

MAX_QUERY_LENGTH = 1000
MAX_IMAGE_BASE64_LENGTH = 7_000_000  # ~5 Mo d'image

class AskAIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'ai'

    def get(self, request, *args, **kwargs):
        """Récupère l'historique récent des interactions IA de l'utilisateur."""
        interactions = AIInteraction.objects.filter(user=request.user).order_by('-created_at')[:20]
        serializer = AIInteractionSerializer(interactions, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request, *args, **kwargs):
        query = request.data.get('query')
        context = request.data.get('context', 'general')
        image_base64 = request.data.get('image_base64')

        if query is not None and (not isinstance(query, str) or len(query) > MAX_QUERY_LENGTH):
            return Response({"error": f"La question doit être un texte de {MAX_QUERY_LENGTH} caractères maximum."}, status=status.HTTP_400_BAD_REQUEST)
        if image_base64 is not None and (not isinstance(image_base64, str) or len(image_base64) > MAX_IMAGE_BASE64_LENGTH):
            return Response({"error": "Image invalide ou trop volumineuse."}, status=status.HTTP_400_BAD_REQUEST)

        if not query and not image_base64:
            return Response({"error": "La requête ou l'image est requise."}, status=status.HTTP_400_BAD_REQUEST)

        # Call AI service avec cloisonnement de sécurité
        safe_query = query.strip() if query else "Analyse cette image."
        result = answer_question(safe_query, context, image_base64=image_base64, user=request.user)

        # Save to DB : la réponse, d'où elle vient (fiches, conseil général) et les sources citées
        interaction = AIInteraction.objects.create(
            user=request.user,
            query=safe_query,
            response=result['answer'],
            context_type=context,
            origin=result['origin'],
            sources=result['sources'],
        )

        serializer = AIInteractionSerializer(interaction)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
