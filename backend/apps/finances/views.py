from rest_framework import viewsets, permissions, views
from rest_framework.response import Response
from .models import Sale, Transaction
from .serializers import SaleSerializer, TransactionSerializer
from django.db.models import ExpressionWrapper, F, FloatField, Sum
from datetime import datetime, timedelta

class SaleViewSet(viewsets.ModelViewSet):
    serializer_class = SaleSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        # select_related : le serializer affiche le nom de la culture (sinon une requête par vente)
        return Sale.objects.filter(crop__user=self.request.user).select_related('crop')

    def perform_create(self, serializer):
        sale = serializer.save()
        # Décrémenter automatiquement le stock dans apps.inventory si l'article existe
        try:
            from apps.inventory.models import StockItem
            stock_item = StockItem.objects.filter(user=self.request.user, name__iexact=sale.crop.name).first()
            if stock_item:
                stock_item.quantity = max(0.0, round(stock_item.quantity - float(sale.quantity_sold), 2))
                if stock_item.quantity <= 5:
                    stock_item.alert_status = True
                stock_item.save(update_fields=['quantity', 'alert_status', 'updated_at'])
        except Exception:
            pass

class TransactionViewSet(viewsets.ModelViewSet):
    serializer_class = TransactionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Transaction.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

class FinancialSummaryView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, *args, **kwargs):
        user = request.user
        
        # Recettes des ventes : calculées par la base (une requête), sans charger chaque vente en mémoire
        sales_revenue = Sale.objects.filter(crop__user=user).aggregate(
            total=Sum(ExpressionWrapper(F('quantity_sold') * F('price_per_unit'), output_field=FloatField()))
        )['total'] or 0

        # Calculate from Transactions (on exclut les transactions automatiques issues de Sale pour éviter le double comptage)
        incomes = Transaction.objects.filter(user=user, transaction_type='income', sale__isnull=True).aggregate(Sum('amount'))['amount__sum'] or 0
        expenses = Transaction.objects.filter(user=user, transaction_type='expense').aggregate(Sum('amount'))['amount__sum'] or 0

        total_revenue = float(sales_revenue) + float(incomes)
        total_expenses = float(expenses)
        balance = total_revenue - total_expenses

        return Response({
            'total_revenue': total_revenue,
            'total_expenses': total_expenses,
            'balance': balance
        })
