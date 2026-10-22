from django.db import transaction
from rest_framework import viewsets, permissions

from apps.ai_assistant.services import call_llm
from .models import StockItem, StockMovement
from .serializers import StockItemSerializer, StockMovementSerializer
from .services import create_stock_item, record_quantity_change, remove_stock_item


class StockItemViewSet(viewsets.ModelViewSet):
    serializer_class = StockItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return StockItem.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        data = serializer.validated_data
        stock = create_stock_item(
            self.request.user, data['name'], data['quantity'], data['unit'],
            reason='manual', note="Saisie dans l'application",
        )
        serializer.instance = stock
        # Generate AI advice asynchronously or synchronously (we'll do sync for simplicity here)
        query = f"Donne-moi 2 phrases courtes de conseil pour bien stocker : {stock.quantity} {stock.unit} de {stock.name}. Prends en compte la température et l'humidité au Sénégal."
        # call_llm renvoie None si l'IA est indisponible : aucun conseil n'est alors stocké
        advice = call_llm(query)
        if advice:
            stock.ai_storage_advice = advice
            stock.save(update_fields=['ai_storage_advice', 'updated_at'])

    def perform_update(self, serializer):
        with transaction.atomic():
            old_quantity = serializer.instance.quantity
            item = serializer.save()
            record_quantity_change(item, old_quantity, reason='correction', note="Modification dans l'application")

    def perform_destroy(self, instance):
        remove_stock_item(instance)


class StockMovementViewSet(viewsets.ReadOnlyModelViewSet):
    """Journal des mouvements de stock de l'utilisateur (plus récents d'abord). Filtre : ``?product=<nom>``."""
    serializer_class = StockMovementSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        queryset = StockMovement.objects.filter(user=self.request.user)
        product = self.request.query_params.get('product')
        if product:
            queryset = queryset.filter(product_name__icontains=product)
        return queryset
