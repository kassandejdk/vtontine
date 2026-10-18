from django.contrib import admin
from django.utils.html import format_html

from .models import User
from .keycloak_service import KeycloakService

admin.site.site_header = "vTontine — Administration"
admin.site.site_title = "vTontine Admin"
admin.site.index_title = "Tableau de bord"


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = (
        'telephone', 'prenom', 'nom', 'genre',
        'nb_tontines_creees', 'statut_compte', 'date_creation',
    )
    list_filter = ('is_active', 'genre', 'date_creation')
    search_fields = ('telephone', 'nom', 'prenom')
    readonly_fields = ('keycloak_id', 'date_creation')
    actions = ['suspendre', 'reactiver']

    @admin.display(description='Tontines créées')
    def nb_tontines_creees(self, obj):
        return obj.tontines_creees.count()

    @admin.display(description='Compte')
    def statut_compte(self, obj):
        if obj.is_active:
            return format_html('<span style="color:green;">● Actif</span>')
        return format_html('<span style="color:red;">● Suspendu</span>')

    @admin.action(description="Suspendre les comptes sélectionnés")
    def suspendre(self, request, queryset):
        n = 0
        for user in queryset:
            user.is_active = False
            user.save(update_fields=['is_active'])
            try:
                KeycloakService.set_user_enabled(user.keycloak_id, False)
            except Exception:
                pass
            n += 1
        self.message_user(request, f"{n} compte(s) suspendu(s).")

    @admin.action(description="Réactiver les comptes sélectionnés")
    def reactiver(self, request, queryset):
        n = 0
        for user in queryset:
            user.is_active = True
            user.save(update_fields=['is_active'])
            try:
                KeycloakService.set_user_enabled(user.keycloak_id, True)
            except Exception:
                pass
            n += 1
        self.message_user(request, f"{n} compte(s) réactivé(s).")
