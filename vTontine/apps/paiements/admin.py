from django.contrib import admin

from .models import Paiement

admin.site.site_header = "vTontine Admin"


@admin.register(Paiement)
class PaiementAdmin(admin.ModelAdmin):
    list_display = ('transaction_id', 'participation', 'montant', 'statut', 'date_paiement')
    list_filter = ('statut', 'date_paiement')
    search_fields = ('transaction_id', 'participation__participant__telephone')
    autocomplete_fields = ('participation',)
    actions = ['confirmer_paiements', 'refuser_paiements']

    @admin.action(description="Confirmer les paiements sélectionnés")
    def confirmer_paiements(self, request, queryset):
        maj = queryset.exclude(statut='CONFIRME').update(statut='CONFIRME', est_confirmer=True)
        self.message_user(request, f"{maj} paiement(s) confirmé(s).")

    @admin.action(description="Refuser les paiements sélectionnés")
    def refuser_paiements(self, request, queryset):
        maj = queryset.exclude(statut='REFUSE').update(statut='REFUSE', est_confirmer=False)
        self.message_user(request, f"{maj} paiement(s) refusé(s).")
