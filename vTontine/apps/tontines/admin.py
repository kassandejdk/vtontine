from django.contrib import admin
from django.db.models import Sum

from .models import (
    Tontine, Participation, RegleTontine, DemandeAdhesion,
    InvitationTontine, MessageTontine, MethodePaiement, Cycle,
)


@admin.register(Tontine)
class TontineAdmin(admin.ModelAdmin):
    list_display = (
        'nom', 'createur', 'statut', 'membres_confirmes',
        'montant', 'total_collecte', 'paiements_en_attente',
        'visibilite', 'date_creation',
    )
    list_filter = ('statut', 'visibilite', 'type_prise', 'date_creation')
    search_fields = ('nom', 'createur__telephone', 'createur__nom', 'createur__prenom')
    readonly_fields = ('date_creation',)
    date_hierarchy = 'date_creation'

    @admin.display(description='Membres')
    def membres_confirmes(self, obj):
        return obj.participations.filter(statut='CONFIRME').count()

    @admin.display(description='Total collecté')
    def total_collecte(self, obj):
        # Somme uniquement des paiements confirmés de la tontine
        from apps.paiements.models import Paiement
        total = Paiement.objects.filter(
            participation__tontine=obj, statut='CONFIRME'
        ).aggregate(s=Sum('montant'))['s'] or 0
        return f"{total} FCFA"

    @admin.display(description='Paiements en attente')
    def paiements_en_attente(self, obj):
        from apps.paiements.models import Paiement
        return Paiement.objects.filter(
            participation__tontine=obj, statut='EN_ATTENTE'
        ).count()


@admin.register(Participation)
class ParticipationAdmin(admin.ModelAdmin):
    list_display = ('participant', 'tontine', 'statut', 'est_createur', 'ordre_prise')
    list_filter = ('statut', 'est_createur')
    search_fields = (
        'participant__telephone', 'participant__nom', 'participant__prenom',
        'tontine__nom',
    )


@admin.register(DemandeAdhesion)
class DemandeAdhesionAdmin(admin.ModelAdmin):
    list_display = ('demandeur', 'tontine', 'statut', 'date_demande', 'traite_par')
    list_filter = ('statut', 'date_demande')
    search_fields = ('demandeur__telephone', 'tontine__nom')


@admin.register(InvitationTontine)
class InvitationTontineAdmin(admin.ModelAdmin):
    list_display = ('invite', 'tontine', 'invite_par', 'type', 'statut', 'date_envoi')
    list_filter = ('statut', 'type', 'date_envoi')
    search_fields = ('invite__telephone', 'tontine__nom')


@admin.register(MethodePaiement)
class MethodePaiementAdmin(admin.ModelAdmin):
    list_display = ('libelle', 'code_ussd', 'tontine', 'ordre')
    search_fields = ('libelle', 'tontine__nom')


@admin.register(MessageTontine)
class MessageTontineAdmin(admin.ModelAdmin):
    list_display = ('tontine', 'auteur', 'type', 'apercu', 'date_envoi')
    list_filter = ('type', 'date_envoi')
    search_fields = ('tontine__nom', 'auteur__telephone', 'contenu')

    @admin.display(description='Aperçu')
    def apercu(self, obj):
        return (obj.contenu[:40] + '…') if len(obj.contenu) > 40 else obj.contenu


@admin.register(Cycle)
class CycleAdmin(admin.ModelAdmin):
    list_display = (
        'tontine', 'numero', 'date_debut', 'date_fin',
        'beneficiaire', 'statut', 'prise_versee', 'date_versement',
    )
    list_filter = ('statut', 'prise_versee')
    search_fields = ('tontine__nom',)


admin.site.register(RegleTontine)
