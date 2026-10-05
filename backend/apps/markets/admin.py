from django.contrib import admin

from .models import Market, Price, Product


@admin.register(Market)
class MarketAdmin(admin.ModelAdmin):
    list_display = ('name', 'region', 'rating', 'opening_time', 'closing_time')
    list_filter = ('region',)
    search_fields = ('name', 'region')


@admin.register(Price)
class PriceAdmin(admin.ModelAdmin):
    list_display = ('product_name', 'market', 'price', 'trend', 'date')
    list_filter = ('trend', 'market', 'date')
    search_fields = ('product_name', 'market__name')
    date_hierarchy = 'date'
    list_select_related = ('market',)


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'current_price', 'trend_percentage', 'is_trending')
    list_filter = ('category', 'is_trending')
    search_fields = ('name',)
