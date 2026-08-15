from rest_framework import views, permissions, status
from rest_framework.response import Response
from .models import AIInteraction
from .serializers import AIInteractionSerializer
from .services import ask_llm

class AskAIView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, *args, **kwargs):
        query = request.data.get('query')
        context = request.data.get('context', 'general')
        image_base64 = request.data.get('image_base64')

        if not query and not image_base64:
            return Response({"error": "La requête ou l'image est requise."}, status=status.HTTP_400_BAD_REQUEST)

        # Call AI service
        answer = ask_llm(query or "Analyse cette image.", context, image_base64=image_base64)

        # Save to DB
        interaction = AIInteraction.objects.create(
            user=request.user,
            query=query,
            response=answer,
            context_type=context
        )

        serializer = AIInteractionSerializer(interaction)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
