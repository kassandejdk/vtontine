from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('apps.users.urls')),
    path('api/tontines/', include('apps.tontines.urls')),
    path('api/paiements/', include('apps.paiements.urls')),
    path('api/notifications/', include('apps.notifications.urls')),
]

# Service des fichiers médias en développement
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
