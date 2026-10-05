from django.contrib import admin

from .models import Activity, Crop, PestReport


class ActivityInline(admin.TabularInline):
    model = Activity
    extra = 0
    fields = ('activity_type', 'date', 'cost', 'description')


@admin.register(Crop)
class CropAdmin(admin.ModelAdmin):
    list_display = ('name', 'crop_type', 'user', 'status', 'area_size', 'location', 'planting_date', 'expected_harvest_date')
    list_filter = ('status', 'crop_type', 'planting_date')
    search_fields = ('name', 'crop_type', 'location', 'user__username', 'user__first_name')
    date_hierarchy = 'planting_date'
    list_select_related = ('user',)
    inlines = [ActivityInline]


@admin.register(Activity)
class ActivityAdmin(admin.ModelAdmin):
    list_display = ('activity_type', 'crop', 'date', 'cost')
    list_filter = ('activity_type', 'date')
    search_fields = ('activity_type', 'description', 'crop__name', 'crop__user__username')
    date_hierarchy = 'date'
    list_select_related = ('crop',)


@admin.register(PestReport)
class PestReportAdmin(admin.ModelAdmin):
    list_display = ('pest_name', 'location', 'user', 'date_reported')
    list_filter = ('pest_name', 'location', 'date_reported')
    search_fields = ('pest_name', 'location', 'description', 'user__username')
    date_hierarchy = 'date_reported'
    list_select_related = ('user',)
