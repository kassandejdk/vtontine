from django.contrib import admin

from .models import Notification


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('titre', 'user', 'est_lu', 'tontine', 'date_envoie')
    list_filter = ('est_lu', 'date_envoie')
    search_fields = ('titre', 'user__telephone', 'message')
