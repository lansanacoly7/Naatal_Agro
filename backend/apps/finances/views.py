from django.db import transaction as db_transaction
from django.db.models import ExpressionWrapper, F, FloatField, Sum, Q
from rest_framework import viewsets, permissions, views
from rest_framework.response import Response
from .models import Sale, Transaction
from .serializers import SaleSerializer, TransactionSerializer

class SaleViewSet(viewsets.ModelViewSet):
    serializer_class = SaleSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Sale.objects.filter(
            Q(user=self.request.user) | Q(crop__user=self.request.user)
        ).select_related('crop').distinct()

    def perform_create(self, serializer):
        with db_transaction.atomic():
            sale = serializer.save(user=self.request.user)
            product_name = sale.product_name or (sale.crop.name if sale.crop else '')

            # 1. Décrémenter le stock du produit VENDU (journalisé) : une erreur annule toute la vente
            from apps.inventory.services import change_stock, stock_for_sale
            stock_item = stock_for_sale(self.request.user, sale.product_name, sale.crop.name if sale.crop else '')
            if stock_item:
                change_stock(
                    stock_item, stock_item.quantity - float(sale.quantity_sold),
                    reason='sale', note=f"Vente du {sale.date}", sale=sale,
                )

            # 2. Créer automatiquement la Transaction de revenu liée à la vente
            Transaction.objects.update_or_create(
                sale=sale,
                defaults={
                    'user': self.request.user,
                    'transaction_type': 'income',
                    'amount': sale.total_revenue,
                    'date': sale.date,
                    'description': f"Vente de {product_name or 'produit'} ({sale.quantity_sold})"
                }
            )

    def perform_destroy(self, instance):
        from .services import delete_sale
        delete_sale(instance, self.request.user)

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
        
        # Recettes des ventes de l'utilisateur
        sales_revenue = Sale.objects.filter(
            Q(user=user) | Q(crop__user=user)
        ).aggregate(
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
