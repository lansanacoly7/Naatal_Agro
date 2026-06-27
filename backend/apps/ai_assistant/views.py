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

        if not query:
            return Response({"error": "La requête ('query') est requise."}, status=status.HTTP_400_BAD_REQUEST)

        # Call AI service
        answer = ask_llm(query, context)

        # Save to DB
        interaction = AIInteraction.objects.create(
            user=request.user,
            query=query,
            response=answer,
            context_type=context
        )

        serializer = AIInteractionSerializer(interaction)
        return Response(serializer.data, status=status.HTTP_201_CREATED)
