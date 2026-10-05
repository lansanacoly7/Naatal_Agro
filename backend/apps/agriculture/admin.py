from django.contrib import admin, messages

from .knowledge_review import ProposalError, approve_proposal, is_trusted_url, reject_proposal
from .models import Activity, AgronomicGuide, Crop, KnowledgeProposal, PestReport


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


@admin.register(AgronomicGuide)
class AgronomicGuideAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'cycle_days_min', 'cycle_days_max', 'updated_at')
    list_filter = ('category',)
    search_fields = ('name', 'scientific_name', 'summary')
    prepopulated_fields = {'slug': ('name',)}
    readonly_fields = ('locally_edited', 'updated_at')

    def save_model(self, request, obj, form, change):
        # Toute modification depuis l'administration protège la fiche du rechargement du fichier du dépôt
        obj.locally_edited = True
        super().save_model(request, obj, form, change)


@admin.register(KnowledgeProposal)
class KnowledgeProposalAdmin(admin.ModelAdmin):
    """File de validation : comparer le texte proposé à l'extrait de la source avant d'approuver."""
    list_display = ('guide', 'field', 'status', 'source_publisher', 'trusted_source', 'created_at')
    list_filter = ('status', 'guide', 'field', 'submitted_via')
    search_fields = ('proposed_text', 'quote', 'source_title', 'source_url', 'pest_name')
    date_hierarchy = 'created_at'
    list_select_related = ('guide',)
    readonly_fields = ('status', 'reviewed_by', 'reviewed_at', 'created_at')
    actions = ['approve_selected', 'reject_selected']

    @admin.display(boolean=True, description='Source de confiance')
    def trusted_source(self, obj):
        return is_trusted_url(obj.source_url)

    @admin.action(description="Approuver et ajouter à la fiche")
    def approve_selected(self, request, queryset):
        approved = 0
        for proposal in queryset:
            try:
                approve_proposal(proposal, request.user)
                approved += 1
            except ProposalError as error:
                self.message_user(request, f'{proposal} : {error}', messages.ERROR)
        if approved:
            self.message_user(request, f'{approved} proposition(s) approuvée(s) et ajoutée(s) aux fiches.', messages.SUCCESS)

    @admin.action(description="Rejeter")
    def reject_selected(self, request, queryset):
        rejected = 0
        for proposal in queryset:
            try:
                reject_proposal(proposal, request.user)
                rejected += 1
            except ProposalError as error:
                self.message_user(request, f'{proposal} : {error}', messages.ERROR)
        if rejected:
            self.message_user(request, f'{rejected} proposition(s) rejetée(s).', messages.SUCCESS)
