from rest_framework import viewsets, permissions
from .models import StockItem
from .serializers import StockItemSerializer
from apps.ai_assistant.services import ask_llm

class StockItemViewSet(viewsets.ModelViewSet):
    serializer_class = StockItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return StockItem.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        stock = serializer.save(user=self.request.user)
        # Generate AI advice asynchronously or synchronously (we'll do sync for simplicity here)
        query = f"Donne-moi 2 phrases courtes de conseil pour bien stocker : {stock.quantity} {stock.unit} de {stock.name}. Prends en compte la température et l'humidité au Sénégal."
        advice = ask_llm(query, context="Gestion de stock agricole.")
        if advice:
            stock.ai_storage_advice = advice
            stock.save()

    def perform_update(self, serializer):
        serializer.save()
        # Could optionally regenerate advice on update, but we keep it simple
