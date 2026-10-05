from django.contrib import admin

from .models import Sale, Transaction


@admin.register(Sale)
class SaleAdmin(admin.ModelAdmin):
    list_display = ('crop', 'quantity_sold', 'price_per_unit', 'buyer', 'date')
    list_filter = ('date',)
    search_fields = ('crop__name', 'crop__user__username', 'buyer')
    date_hierarchy = 'date'
    list_select_related = ('crop',)


@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ('description', 'transaction_type', 'amount', 'user', 'date')
    list_filter = ('transaction_type', 'date')
    search_fields = ('description', 'user__username')
    date_hierarchy = 'date'
    list_select_related = ('user',)
