from rest_framework import viewsets, permissions, views
from rest_framework.response import Response
from .models import Sale, Transaction
from .serializers import SaleSerializer, TransactionSerializer
from django.db.models import Sum
from datetime import datetime, timedelta

class SaleViewSet(viewsets.ModelViewSet):
    serializer_class = SaleSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Sale.objects.filter(crop__user=self.request.user)

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
        
        # Calculate revenues from sales
        sales = Sale.objects.filter(crop__user=user)
        sales_revenue = sum(sale.total_revenue for sale in sales)

        # Calculate from Transactions
        incomes = Transaction.objects.filter(user=user, transaction_type='income').aggregate(Sum('amount'))['amount__sum'] or 0
        expenses = Transaction.objects.filter(user=user, transaction_type='expense').aggregate(Sum('amount'))['amount__sum'] or 0

        total_revenue = float(sales_revenue) + float(incomes)
        total_expenses = float(expenses)
        balance = total_revenue - total_expenses

        return Response({
            'total_revenue': total_revenue,
            'total_expenses': total_expenses,
            'balance': balance
        })
