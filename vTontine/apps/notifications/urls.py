from django.urls import path
from . import views

urlpatterns = [
    path('', views.NotificationListView.as_view(), name='notification-list'),
    path('marquer-tout-lu/', views.NotificationMarquerToutLuView.as_view(), name='notification-marquer-tout-lu'),
    path('<int:notification_id>/lu/', views.NotificationMarquerLuView.as_view(), name='notification-marquer-lu'),
]
