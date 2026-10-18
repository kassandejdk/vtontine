from django.urls import path
from .views import (
    RegisterView, LoginView, LogoutView, RefreshTokenView, MeView, MePhotoView,
    ChangePasswordView, RechercherUserParTelephoneView,
    AdminStatsView, AdminTontinesView, AdminUsersView,
)

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),
    path('logout/', LogoutView.as_view(), name='logout'),
    path('refresh/', RefreshTokenView.as_view(), name='refresh-token'),
    path('me/', MeView.as_view(), name='me'),
    path('me/photo/', MePhotoView.as_view(), name='me-photo'),
    path('change-password/', ChangePasswordView.as_view(), name='change-password'),
    path('users/rechercher/', RechercherUserParTelephoneView.as_view(), name='user-rechercher'),

    path('admin/stats/', AdminStatsView.as_view(), name='admin-stats'),
    path('admin/tontines/', AdminTontinesView.as_view(), name='admin-tontines'),
    path('admin/users/', AdminUsersView.as_view(), name='admin-users'),
]